const std = @import("std");
const c = @import("c.zig");
const model = @import("model.zig");
const math = @import("math.zig");
const shaders = @import("shaders.zig");
const PngImage = @import("textures.zig").PngImage;
const Mat4f = math.Mat4(f32);
const Vec3f = math.Vec3(f32);

pub const SceneParams = struct {
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

pub const Scene = struct {
    scene_params: SceneParams,

    vao: c.GLuint,
    vbo: c.GLuint,
    ebo: c.GLuint,

    scene_uniform_buffer: c.GLuint,
    node_uniform_buffer: c.GLuint,

    uber_shader: c.GLuint,
    albedo_sampler: c.GLuint, 

    meshes: []model.Mesh,
    textures: []c.GLuint,
    materials: []Material,
    nodes: []Node,

    allocator: *std.mem.Allocator,

    // TODO: Pass the path to a scene file
    pub fn init(scene: *Scene, allocator: *std.mem.Allocator, screen_width: u32, screen_height: u32) !void {
        scene.allocator = allocator;

        // Scene data container
        // --------------------
        const mesh_count = 2; // TODO: This will be read for the scene file
        scene.meshes = try allocator.alloc(model.Mesh, mesh_count);
        // Load all meshes
        // ---------------
        var geometry: model.Geometry = undefined;
        geometry.init(allocator);
        // TODO: We will iterate over all the meses in the scene file
        {
            scene.meshes[0] = try geometry.loadObj("data/models/default_cube.obj");
            scene.meshes[1] = try geometry.loadObj("data/models/suzanne.obj");
        }

        // Load Textures
        // -------------
        const texture_count = 1; // TODO: This will be read from the scene file
        scene.textures = try allocator.alloc(c.GLuint, texture_count);
        c.glCreateTextures(c.GL_TEXTURE_2D, texture_count, @ptrCast([*c]c_uint, scene.textures.ptr));

        // TODO: We will iterate over all the textures in the scene file
        {
            const file = try std.fs.cwd().openFile("data/textures/uvgrid.png", .{});
            var data: []u8 = try file.readToEndAlloc(allocator, 1024 * 1024);
            file.close();
            var pi = try PngImage.create(data);

            c.glTextureStorage2D(scene.textures[0], 1, c.GL_RGBA8, @intCast(c_int, pi.width), @intCast(c_int, pi.height));
            c.glTextureSubImage2D(scene.textures[0], 0, 0, 0, @intCast(c_int, pi.width), @intCast(c_int, pi.height), c.GL_RGBA, c.GL_UNSIGNED_BYTE, @ptrCast(*c_void, &pi.raw[0]));

            allocator.free(data);
            PngImage.destroy(&pi);
        }

        // Load Materials
        // --------------
        const material_count = 2; // TODO: This will be read for a scene file
        scene.materials = try allocator.alloc(Material, material_count);
        // TODO: We will iterate over all the materials in the scene file
        {
            scene.materials[0] = Material{
                .albedo_texture_idx = 0,
            };
            scene.materials[1] = Material{
                .albedo_texture_idx = 0,
            };
        }

        // Load Nodes
        // ----------
        const node_count = 2; // TODO: This will be read for a scene file
        scene.nodes = try allocator.alloc(Node, node_count);
        // TODO: We will iterate over all the nodesl in the scene file
        {
            scene.nodes[0] = Node{
                .mesh_idx = 0,
                .material_idx = 0,
                .position = Vec3f.init(1.5, 0, -4),
                .rotation = Vec3f.init(0, 0, 0),
                .scale = Vec3f.init(1, 1, 1),
                .transform = undefined,
            };
            scene.nodes[0].transform = ModelTransform{
                .model_matrix = Mat4f.TRS(scene.nodes[0].position, scene.nodes[0].rotation, scene.nodes[0].scale),
            };

            scene.nodes[1] = Node{
                .mesh_idx = 1,
                .material_idx = 1,
                .position = Vec3f.init(-1.5, 0, -4),
                .rotation = Vec3f.init(0, 0, 0),
                .scale = Vec3f.init(1, 1, 1),
                .transform = undefined,
            };
            scene.nodes[1].transform = ModelTransform{
                .model_matrix = Mat4f.TRS(scene.nodes[1].position, scene.nodes[1].rotation, scene.nodes[1].scale),
            };
        }

        // Load scene settings
        scene.scene_params = SceneParams{
            .view_matrix = Mat4f.lookAt(Vec3f.init(0, 0, 0), Vec3f.init(0, 0, -1), Vec3f.init(0, 1, 0)),
            .proj_matrix = Mat4f.perspective(60.0, @intToFloat(f32, screen_width) / @intToFloat(f32, screen_height), 0.001, 1000.0),
        };

        // Create the Vertex Array Object
        c.glGenVertexArrays(1, &scene.vao);
        c.glBindVertexArray(scene.vao);

        // Upload all geometry to a vertex and index buffer on the GPU
        {
            // Allocate and initialize a vertex buffer object
            c.glCreateBuffers(1, &scene.vbo);
            c.glNamedBufferStorage(scene.vbo, @intCast(c_longlong, @sizeOf(model.Vertex) * geometry.vertices.items.len), geometry.vertices.items.ptr, 0);

            // Allocate and initialize an index buffer object
            c.glCreateBuffers(1, &scene.ebo);
            c.glNamedBufferStorage(scene.ebo, @intCast(c_longlong, @sizeOf(u32) * geometry.indices.items.len), geometry.indices.items.ptr, 0);

            // We no longer need a copy of the data on the CPU
            geometry.deinit();
        }

        // Bind the buffer to the vertex array object
        c.glVertexArrayVertexBuffer(scene.vao, 0, scene.vbo, 0, @sizeOf(model.Vertex));

        // Set up two vertex attributes.
        // Position
        c.glVertexArrayAttribBinding(scene.vao, 0, 0);
        c.glVertexArrayAttribFormat(scene.vao, 0, 3, c.GL_FLOAT, c.GL_FALSE, @byteOffsetOf(model.Vertex, "position"));
        c.glEnableVertexAttribArray(0);
        // Normal
        c.glVertexArrayAttribBinding(scene.vao, 1, 0);
        c.glVertexArrayAttribFormat(scene.vao, 1, 3, c.GL_FLOAT, c.GL_FALSE, @byteOffsetOf(model.Vertex, "normal"));
        c.glEnableVertexAttribArray(1);
        // UV
        c.glVertexArrayAttribBinding(scene.vao, 2, 0);
        c.glVertexArrayAttribFormat(scene.vao, 2, 2, c.GL_FLOAT, c.GL_FALSE, @byteOffsetOf(model.Vertex, "uv0"));
        c.glEnableVertexAttribArray(2);

        c.glBindVertexArray(0);

        scene.uber_shader = try shaders.createProgram(allocator, "data/shaders/uber_vertex.glsl", "data/shaders/uber_fragment.glsl");

        // Create samplers for the program
        c.glCreateSamplers(1, &scene.albedo_sampler);
        c.glSamplerParameteri(scene.albedo_sampler, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
        c.glSamplerParameteri(scene.albedo_sampler, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
        c.glSamplerParameteri(scene.albedo_sampler, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR_MIPMAP_LINEAR);
        c.glSamplerParameteri(scene.albedo_sampler, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);

        c.glCreateBuffers(1, &scene.scene_uniform_buffer);
        c.glNamedBufferStorage(scene.scene_uniform_buffer, @intCast(c_longlong, @sizeOf(SceneParams)), &scene.scene_params, c.GL_DYNAMIC_STORAGE_BIT);

        c.glCreateBuffers(1, &scene.node_uniform_buffer);
        c.glNamedBufferStorage(scene.node_uniform_buffer, @intCast(c_longlong, @sizeOf(ModelTransform)), null, c.GL_DYNAMIC_STORAGE_BIT);
    }

    pub fn deinit(self: *Scene) void {
        self.allocator.free(self.meshes);
        self.allocator.free(self.textures);
        self.allocator.free(self.materials);
        self.allocator.free(self.nodes);
    }

    pub fn update(self: *Scene, delta_time: f32) void {

    }

    pub fn render(self: *Scene) void {
        c.glBindVertexArray(self.vao);

        c.glUseProgram(self.uber_shader);
        c.glFrontFace(c.GL_CCW);
        c.glEnable(c.GL_CULL_FACE);
        c.glEnable(c.GL_DEPTH_TEST);
        c.glDepthFunc(c.GL_LEQUAL);

        // Binding program samplers
        c.glBindSampler(0, self.albedo_sampler);

        c.glBindBufferBase(c.GL_UNIFORM_BUFFER, 0, self.scene_uniform_buffer);

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