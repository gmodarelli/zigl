const std = @import("std");
const c = @import("c.zig");
const model = @import("model.zig");
const shaders = @import("shaders.zig");
const PngImage = @import("textures.zig").PngImage;
const za = @import("zalgebra");
const Mat4f = za.mat4;
const Vec2f = za.vec2;
const Vec3f = za.vec3;

const camera = @import("camera.zig");
const Camera = camera.Camera;
const CameraMovement = camera.CameraMovement;

const im = @import("input.zig");
const KeyCode = im.KeyCode;
const MouseCode = im.MouseCode;

pub const GlobalParams = struct {
    view_matrix: Mat4f,
    proj_matrix: Mat4f,
};

pub const ModelTransform = struct {
    model_matrix: Mat4f,
};

pub const Material = struct {
    albedo_texture_idx: usize,
};

pub const Node = struct {
    mesh_idx: usize,
    material_idx: usize,
    position: Vec3f,
    rotation: Vec3f,
    scale: Vec3f,
    transform: ModelTransform,
};

pub const SceneRenderer = struct {
    const Self = @This();
    global_params: GlobalParams,

    vao: c.GLuint,
    vbo: c.GLuint,
    ebo: c.GLuint,

    global_uniform_buffer: c.GLuint,
    node_uniform_buffer: c.GLuint,

    uber_shader: c.GLuint,
    albedo_sampler: c.GLuint,

    camera: Camera,

    meshes: []model.Mesh,
    textures: []c.GLuint,
    materials: []Material,
    nodes: []Node,

    allocator: *std.mem.Allocator,

    input: *im.Input,
    last_mouse_position: Vec2f = Vec2f.init(0.0, 0.0),

    // TODO: Pass the path to a scene file
    pub fn init(self: *Self, allocator: *std.mem.Allocator, screen_width: u32, screen_height: u32, input: *im.Input) !void {
        self.input = input;
        self.allocator = allocator;
        // Scene data container
        // --------------------
        self.camera.init(Vec3f.new(0.0, 0.0, 0.0), Vec3f.new(0.0, 1.0, 0.0), -90.0, 0.0);

        // Load all meshes
        // ---------------
        const mesh_count = 2; // TODO: This will be read for the scene file
        self.meshes = try allocator.alloc(model.Mesh, mesh_count);
        var geometry: model.Geometry = undefined;
        geometry.init(allocator);
        // TODO: We will iterate over all the meses in the scene file
        {
            self.meshes[0] = try geometry.loadObj("data/models/default_cube.obj");
            self.meshes[1] = try geometry.loadObj("data/models/suzanne.obj");
        }

        // Load Textures
        // -------------
        const texture_count = 1; // TODO: This will be read from the scene file
        self.textures = try allocator.alloc(c.GLuint, texture_count);
        c.glCreateTextures(c.GL_TEXTURE_2D, texture_count, @ptrCast([*c]c_uint, self.textures.ptr));

        // TODO: We will iterate over all the textures in the scene file
        {
            const file = try std.fs.cwd().openFile("data/textures/uvgrid.png", .{});
            var data: []u8 = try file.readToEndAlloc(allocator, 1024 * 1024);
            file.close();
            var pi = try PngImage.create(data);

            c.glTextureStorage2D(self.textures[0], 1, c.GL_RGBA8, @intCast(c_int, pi.width), @intCast(c_int, pi.height));
            c.glTextureSubImage2D(self.textures[0], 0, 0, 0, @intCast(c_int, pi.width), @intCast(c_int, pi.height), c.GL_RGBA, c.GL_UNSIGNED_BYTE, @ptrCast(*c_void, &pi.raw[0]));

            allocator.free(data);
            PngImage.destroy(&pi);
        }

        // Load Materials
        // --------------
        const material_count = 2; // TODO: This will be read for a scene file
        self.materials = try allocator.alloc(Material, material_count);
        // TODO: We will iterate over all the materials in the scene file
        {
            self.materials[0] = Material{
                .albedo_texture_idx = 0,
            };
            self.materials[1] = Material{
                .albedo_texture_idx = 0,
            };
        }

        // Load Nodes
        // ----------
        const node_count = 2; // TODO: This will be read for a scene file
        self.nodes = try allocator.alloc(Node, node_count);
        // TODO: We will iterate over all the nodesl in the scene file
        {
            self.nodes[0] = Node{
                .mesh_idx = 0,
                .material_idx = 0,
                .position = Vec3f.new(1.5, 0.0, -4.0),
                .rotation = Vec3f.new(0.0, 0.0, 0.0),
                .scale = Vec3f.new(1.0, 1.0, 1.0),
                .transform = undefined,
            };

            var translation_matrix = Mat4f.from_translate(self.nodes[0].position);
            var rotation_matrix = Mat4f.from_euler_angle(self.nodes[0].rotation);
            var scale_matrix = Mat4f.from_scale(self.nodes[0].scale);

            self.nodes[0].transform = ModelTransform{
                .model_matrix = (translation_matrix).mult((rotation_matrix).mult(scale_matrix)),
            };

            self.nodes[1] = Node{
                .mesh_idx = 1,
                .material_idx = 1,
                .position = Vec3f.new(-1.5, 0.0, -4.0),
                .rotation = Vec3f.new(0.0, 0.0, 0.0),
                .scale = Vec3f.new(1.0, 1.0, 1.0),
                .transform = undefined,
            };

            translation_matrix = Mat4f.from_translate(self.nodes[1].position);
            rotation_matrix = Mat4f.from_euler_angle(self.nodes[1].rotation);
            scale_matrix = Mat4f.from_scale(self.nodes[1].scale);

            self.nodes[1].transform = ModelTransform{
                .model_matrix = (translation_matrix).mult((rotation_matrix).mult(scale_matrix)),
            };
        }

        // Load scene settings
        self.global_params = GlobalParams{
            .view_matrix = self.camera.getViewMatrix(),
            .proj_matrix = Mat4f.perspective(60.0, @intToFloat(f32, screen_width) / @intToFloat(f32, screen_height), 0.001, 1000.0),
        };

        // Create the Vertex Array Object
        c.glGenVertexArrays(1, &self.vao);
        c.glBindVertexArray(self.vao);

        // Upload all geometry to a vertex and index buffer on the GPU
        {
            // Allocate and initialize a vertex buffer object
            c.glCreateBuffers(1, &self.vbo);
            c.glNamedBufferStorage(self.vbo, @intCast(c_longlong, @sizeOf(model.Vertex) * geometry.vertices.items.len), geometry.vertices.items.ptr, 0);

            // Allocate and initialize an index buffer object
            c.glCreateBuffers(1, &self.ebo);
            c.glNamedBufferStorage(self.ebo, @intCast(c_longlong, @sizeOf(u32) * geometry.indices.items.len), geometry.indices.items.ptr, 0);

            // We no longer need a copy of the data on the CPU
            geometry.deinit();
        }

        // Bind the buffer to the vertex array object
        c.glVertexArrayVertexBuffer(self.vao, 0, self.vbo, 0, @sizeOf(model.Vertex));

        // Set up two vertex attributes.
        // Position
        c.glVertexArrayAttribBinding(self.vao, 0, 0);
        c.glVertexArrayAttribFormat(self.vao, 0, 3, c.GL_FLOAT, c.GL_FALSE, @byteOffsetOf(model.Vertex, "position"));
        c.glEnableVertexAttribArray(0);
        // Normal
        c.glVertexArrayAttribBinding(self.vao, 1, 0);
        c.glVertexArrayAttribFormat(self.vao, 1, 3, c.GL_FLOAT, c.GL_FALSE, @byteOffsetOf(model.Vertex, "normal"));
        c.glEnableVertexAttribArray(1);
        // UV
        c.glVertexArrayAttribBinding(self.vao, 2, 0);
        c.glVertexArrayAttribFormat(self.vao, 2, 2, c.GL_FLOAT, c.GL_FALSE, @byteOffsetOf(model.Vertex, "uv0"));
        c.glEnableVertexAttribArray(2);

        c.glBindVertexArray(0);

        self.uber_shader = try shaders.createProgram(allocator, "data/shaders/uber_vertex.glsl", "data/shaders/uber_fragment.glsl");

        // Create samplers for the program
        c.glCreateSamplers(1, &self.albedo_sampler);
        c.glSamplerParameteri(self.albedo_sampler, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
        c.glSamplerParameteri(self.albedo_sampler, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
        c.glSamplerParameteri(self.albedo_sampler, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR_MIPMAP_LINEAR);
        c.glSamplerParameteri(self.albedo_sampler, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);

        c.glCreateBuffers(1, &self.global_uniform_buffer);
        c.glNamedBufferStorage(self.global_uniform_buffer, @intCast(c_longlong, @sizeOf(GlobalParams)), &self.global_params, c.GL_DYNAMIC_STORAGE_BIT);

        c.glCreateBuffers(1, &self.node_uniform_buffer);
        c.glNamedBufferStorage(self.node_uniform_buffer, @intCast(c_longlong, @sizeOf(ModelTransform)), null, c.GL_DYNAMIC_STORAGE_BIT);
    }

    pub fn deinit(self: *Self) void {
        std.log.debug("Deinitializing scene renderer", .{});
        self.allocator.free(self.meshes);
        self.allocator.free(self.textures);
        self.allocator.free(self.materials);
        self.allocator.free(self.nodes);
    }

    pub fn update(self: *Self, delta_time: f32) void {
        const mouse_position = self.input.getMousePosition();
        const delta = (mouse_position.sub(self.last_mouse_position)).scale(0.003);
        self.last_mouse_position.x = mouse_position.x;
        self.last_mouse_position.y = mouse_position.y;

        if (self.input.isKeyPressed(KeyCode.W)) {
            self.camera.processMovement(CameraMovement.forward, delta_time);
        }

        if (self.input.isKeyPressed(KeyCode.S)) {
            self.camera.processMovement(CameraMovement.backward, delta_time);
        }

        if (self.input.isKeyPressed(KeyCode.A)) {
            self.camera.processMovement(CameraMovement.left, delta_time);
        }

        if (self.input.isKeyPressed(KeyCode.D)) {
            self.camera.processMovement(CameraMovement.right, delta_time);
        }

        if (self.input.isKeyPressed(KeyCode.Q)) {
            self.camera.processMovement(CameraMovement.up, delta_time);
        }

        if (self.input.isKeyPressed(KeyCode.E)) {
            self.camera.processMovement(CameraMovement.down, delta_time);
        }
    }

    pub fn render(self: *Self) void {
        // Clear color and depth
        const color = [_]c.GLfloat{ 0.1, 0.1, 0.1, 1.0 };
        const depth = [_]c.GLfloat{0.0};
        c.glClearBufferfv(c.GL_COLOR, 0, @ptrCast([*c]const c.GLfloat, &color));
        c.glClearBufferfi(c.GL_DEPTH_STENCIL, 0, 1.0, 0);

        c.glBindVertexArray(self.vao);

        c.glUseProgram(self.uber_shader);
        c.glFrontFace(c.GL_CCW);
        c.glEnable(c.GL_CULL_FACE);
        c.glEnable(c.GL_DEPTH_TEST);
        c.glDepthFunc(c.GL_LEQUAL);

        // Binding program samplers
        c.glBindSampler(0, self.albedo_sampler);

        self.global_params.view_matrix = self.camera.getViewMatrix();
        c.glNamedBufferSubData(self.global_uniform_buffer, 0, @intCast(c_longlong, @sizeOf(GlobalParams)), &self.global_params);
        c.glBindBufferBase(c.GL_UNIFORM_BUFFER, 0, self.global_uniform_buffer);

        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, self.ebo);

        for (self.nodes) |node| {
            c.glNamedBufferSubData(self.node_uniform_buffer, 0, @intCast(c_longlong, @sizeOf(ModelTransform)), &node.transform);
            c.glBindBufferBase(c.GL_UNIFORM_BUFFER, 1, self.node_uniform_buffer);
            c.glBindTextureUnit(0, self.textures[self.materials[node.material_idx].albedo_texture_idx]);
            // NOTE: Index offset has to be passed in bytes! Our Mesh.index_offset stores the number of indices to offset by.
            // Our indices are stored as 32-bit unsigned integerer so to get the right byte offset we need to multiply
            // Mesh.index_offset by @sizeOf(u32)
            // Vertex Base is instead the number of vertices to offset into the vertex buffer.
            c.glDrawElementsBaseVertex(c.GL_TRIANGLES, @intCast(c_int, self.meshes[node.mesh_idx].index_count), c.GL_UNSIGNED_INT, @intToPtr(?*const c_void, self.meshes[node.mesh_idx].index_offset * @sizeOf(u32)), @intCast(c.GLint, self.meshes[node.mesh_idx].vertex_base));
        }

        // NOTE: Do we need to unbind this?
        c.glBindVertexArray(0);
    }
};
