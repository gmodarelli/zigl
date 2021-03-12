const std = @import("std");
const builtin = @import("builtin");
const panic = std.debug.panic;

const c = @import("c.zig");
const shaders = @import("shaders.zig");

const math = @import("math.zig");
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

const model = @import("model.zig");
const PngImage = @import("textures.zig").PngImage;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var global_allocator = &gpa.allocator;

const SCR_WIDTH: u32 = 1920;
const SCR_HEIGHT: u32 = 1080;

const SceneParams = struct {
    view_matrix: Mat4(f32),
    proj_matrix: Mat4(f32),
};

const ModelTransform = struct {
    model_matrix: Mat4(f32),
};

const Material = struct {
    albedo_texture_idx: usize,
};

const Node = struct {
    mesh_idx: usize,
    material_idx: usize,
    position: Vec3(f32),
    rotation: Vec3(f32),
    scale: Vec3(f32),
    transform: ModelTransform,
};

const Scene = struct {
    meshes: []model.Mesh,
    textures: []c.GLuint,
    materials: []Material,
    nodes: []Node,
};

pub fn main() !void {
    const ok = c.glfwInit();
    if (ok == 0) {
        panic("Failed to initialize GLFW\n", .{});
    }
    defer c.glfwTerminate();

    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
    c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 5);
    c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
    c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
    c.glfwWindowHint(c.GLFW_OPENGL_DEBUG_CONTEXT, c.GL_TRUE);

    var window = c.glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "Learn Zig", null, null);
    if (window == null) {
        panic("Failed to create GLFW window\n", .{});
    }

    c.glfwMakeContextCurrent(window);

    if (c.gladLoadGLLoader(@ptrCast(c.GLADloadproc, c.glfwGetProcAddress)) == 0) {
        panic("Failed to initialize GLAD\n", .{});
    }

    std.log.debug("GL_VENDOR: {s}", .{c.glGetString(c.GL_VENDOR)});
    std.log.debug("GL_VERSION: {s}", .{c.glGetString(c.GL_VERSION)});
    std.log.debug("GL_RENDERER: {s}", .{c.glGetString(c.GL_RENDERER)});

    // Check for debug context
    var flags: i32 = 0;
    c.glGetIntegerv(c.GL_CONTEXT_FLAGS, &flags);
    if (flags & c.GL_CONTEXT_FLAG_DEBUG_BIT != 0) {
        std.log.debug("Debug context available", .{});
    }

    c.glDebugMessageCallback(opengl_debug_callback, null);
    c.glEnable(c.GL_DEBUG_OUTPUT_SYNCHRONOUS);

    // Load "level/scene" simulation
    // The idea here is to have a simple (flat) scene file format
    // which enumerates the elements (meshes, textures, materials, lights, etc...)
    // present in the scene in a way that we can load them in memory without
    // the need for dynamic allocations (like ArrayList)
    //
    // Scene data container
    // --------------------
    var scene: Scene = undefined;
    const mesh_count = 2; // TODO: This will be read for a scene file
    scene.meshes = try global_allocator.alloc(model.Mesh, mesh_count);
    // Load all meshes
    // ---------------
    var geometry: model.Geometry = undefined;
    geometry.init(global_allocator);
    // TODO: We will iterate over all the meses in the scene file
    {
        scene.meshes[0] = try geometry.loadObj("data/models/default_cube.obj");
        scene.meshes[1] = try geometry.loadObj("data/models/suzanne.obj");
    }
    // Load Textures
    // -------------
    const texture_count = 1; // TODO: This will be read for a scene file
    scene.textures = try global_allocator.alloc(c.GLuint, texture_count);
    // TODO: We will iterate over all the textures in the scene file
    {
        const file = try std.fs.cwd().openFile("data/textures/uvgrid.png", .{});
        var data: []u8 = try file.readToEndAlloc(global_allocator, 1024 * 1024);
        file.close();
        var pi = try PngImage.create(data);

        c.glCreateTextures(c.GL_TEXTURE_2D, 1, &scene.textures[0]);
        c.glTextureStorage2D(scene.textures[0], 1, c.GL_RGBA8, @intCast(c_int, pi.width), @intCast(c_int, pi.height));
        c.glTextureSubImage2D(scene.textures[0], 0, 0, 0, @intCast(c_int, pi.width), @intCast(c_int, pi.height), c.GL_RGBA, c.GL_UNSIGNED_BYTE, @ptrCast(*c_void, &pi.raw[0]));

        global_allocator.free(data);
        PngImage.destroy(&pi);
    }
    // Load Materials
    // --------------
    const material_count = 2; // TODO: This will be read for a scene file
    scene.materials = try global_allocator.alloc(Material, material_count);
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
    scene.nodes = try global_allocator.alloc(Node, node_count);
    // TODO: We will iterate over all the nodesl in the scene file
    {
        scene.nodes[0] = Node{
            .mesh_idx = 0,
            .material_idx = 0,
            .position = Vec3(f32).init(1.5, 0, -4),
            .rotation = Vec3(f32).init(0, 0, 0),
            .scale = Vec3(f32).init(1, 1, 1),
            .transform = undefined,
        };
        scene.nodes[0].transform = ModelTransform{
            .model_matrix = Mat4(f32).TRS(scene.nodes[0].position, scene.nodes[0].rotation, scene.nodes[0].scale),
        };

        scene.nodes[1] = Node{
            .mesh_idx = 1,
            .material_idx = 1,
            .position = Vec3(f32).init(-1.5, 0, -4),
            .rotation = Vec3(f32).init(0, 0, 0),
            .scale = Vec3(f32).init(1, 1, 1),
            .transform = undefined,
        };
        scene.nodes[1].transform = ModelTransform{
            .model_matrix = Mat4(f32).TRS(scene.nodes[1].position, scene.nodes[1].rotation, scene.nodes[1].scale),
        };
    }

    // Load scene settings
    var scene_params = SceneParams{
        .view_matrix = Mat4(f32).lookAt(Vec3(f32).init(0, 0, 0), Vec3(f32).init(0, 0, -1), Vec3(f32).init(0, 1, 0)),
        .proj_matrix = Mat4(f32).perspective(60.0, @intToFloat(f32, SCR_WIDTH) / @intToFloat(f32, SCR_HEIGHT), 0.001, 1000.0),
    };

    var scene_uniform_buffer: c.GLuint = undefined;
    c.glCreateBuffers(1, &scene_uniform_buffer);
    c.glNamedBufferStorage(scene_uniform_buffer, @intCast(c_longlong, @sizeOf(SceneParams)), &scene_params, c.GL_DYNAMIC_STORAGE_BIT);

    var node_uniform_buffer: c.GLuint = undefined;
    c.glCreateBuffers(1, &node_uniform_buffer);
    c.glNamedBufferStorage(node_uniform_buffer, @intCast(c_longlong, @sizeOf(ModelTransform)), null, c.GL_DYNAMIC_STORAGE_BIT);

    var vao: c.GLuint = undefined;
    var vbo: c.GLuint = undefined;
    var ebo: c.GLuint = undefined;

    // Create the Vertex Array Object
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    // Upload all geometry to a vertex and index buffer on the GPU
    {
        // Allocate and initialize a vertex buffer object
        c.glCreateBuffers(1, &vbo);
        c.glNamedBufferStorage(vbo, @intCast(c_longlong, @sizeOf(model.Vertex) * geometry.vertices.items.len), geometry.vertices.items.ptr, 0);

        // Allocate and initialize an index buffer object
        c.glCreateBuffers(1, &ebo);
        c.glNamedBufferStorage(ebo, @intCast(c_longlong, @sizeOf(u32) * geometry.indices.items.len), geometry.indices.items.ptr, 0);

        // We no longer need a copy of the data on the CPU
        geometry.deinit();
    }

    // Bind the buffer to the vertex array object
    c.glVertexArrayVertexBuffer(vao, 0, vbo, 0, @sizeOf(model.Vertex));

    // Set up two vertex attributes.
    // Position
    c.glVertexArrayAttribBinding(vao, 0, 0);
    c.glVertexArrayAttribFormat(vao, 0, 3, c.GL_FLOAT, c.GL_FALSE, @byteOffsetOf(model.Vertex, "position"));
    c.glEnableVertexAttribArray(0);
    // Normal
    c.glVertexArrayAttribBinding(vao, 1, 0);
    c.glVertexArrayAttribFormat(vao, 1, 3, c.GL_FLOAT, c.GL_FALSE, @byteOffsetOf(model.Vertex, "normal"));
    c.glEnableVertexAttribArray(1);
    // UV
    c.glVertexArrayAttribBinding(vao, 2, 0);
    c.glVertexArrayAttribFormat(vao, 2, 2, c.GL_FLOAT, c.GL_FALSE, @byteOffsetOf(model.Vertex, "uv0"));
    c.glEnableVertexAttribArray(2);

    c.glBindVertexArray(0);

    const shader_program = try shaders.createProgram(global_allocator, "data/shaders/uber_vertex.glsl", "data/shaders/uber_fragment.glsl");

    // Create samplers for the program
    var albedo_sampler: c.GLuint = undefined;
    c.glCreateSamplers(1, &albedo_sampler);
    c.glSamplerParameteri(albedo_sampler, c.GL_TEXTURE_WRAP_S, c.GL_CLAMP_TO_EDGE);
    c.glSamplerParameteri(albedo_sampler, c.GL_TEXTURE_WRAP_T, c.GL_CLAMP_TO_EDGE);
    c.glSamplerParameteri(albedo_sampler, c.GL_TEXTURE_MIN_FILTER, c.GL_LINEAR_MIPMAP_LINEAR);
    c.glSamplerParameteri(albedo_sampler, c.GL_TEXTURE_MAG_FILTER, c.GL_LINEAR);

    var current_time = c.glfwGetTime();
    var last_time = current_time;
    var delta_time: f32 = 0.0;

    while (c.glfwWindowShouldClose(window) == 0) {
        // Clear color and depth
        const color = [_]c.GLfloat{ 0.1, 0.1, 0.1, 1.0 };
        const depth = [_]c.GLfloat{0.0};
        c.glClearBufferfv(c.GL_COLOR, 0, @ptrCast([*c]const c.GLfloat, &color));
        c.glClearBufferfi(c.GL_DEPTH_STENCIL, 0, 1.0, 0);

        // Bind vertex buffer
        c.glBindVertexArray(vao);

        c.glUseProgram(shader_program);
        c.glFrontFace(c.GL_CCW);
        c.glEnable(c.GL_CULL_FACE);
        c.glEnable(c.GL_DEPTH_TEST);
        c.glDepthFunc(c.GL_LEQUAL);

        // Binding program samplers
        c.glBindSampler(0, albedo_sampler);

        c.glBindBufferBase(c.GL_UNIFORM_BUFFER, 0, scene_uniform_buffer);

        c.glBindBuffer(c.GL_ELEMENT_ARRAY_BUFFER, ebo);

        for (scene.nodes) |node| {
            c.glNamedBufferSubData(node_uniform_buffer, 0, @intCast(c_longlong, @sizeOf(ModelTransform)), &node.transform);
            c.glBindBufferBase(c.GL_UNIFORM_BUFFER, 1, node_uniform_buffer);
            c.glBindTextureUnit(0, scene.textures[scene.materials[node.material_idx].albedo_texture_idx]);
            c.glDrawElementsBaseVertex(c.GL_TRIANGLES, @intCast(c_int, scene.meshes[node.mesh_idx].index_count), c.GL_UNSIGNED_INT, @intToPtr(?*const c_void, scene.meshes[node.mesh_idx].index_offset), @intCast(c.GLint, scene.meshes[node.mesh_idx].vertex_base));
        }

        c.glBindVertexArray(0);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();

        current_time = c.glfwGetTime();
        delta_time = @floatCast(f32, current_time - last_time);
        last_time = current_time;
    }

    global_allocator.free(scene.meshes);
    global_allocator.free(scene.textures);
    global_allocator.free(scene.materials);
    global_allocator.free(scene.nodes);

    const leaked = gpa.deinit();
    if (leaked) {
        std.log.debug("Memory leaked", .{});
    }
}

const GLDebugSource = enum(u32) {
    api = 0x8246,
    window_system = 0x8247,
    shader_compiler = 0x8248,
    third_party = 0x8249,
    application = 0x824a,
    other = 0x824b,
};

const GLDebugType = enum(u32) {
    @"error" = 0x824c,
    deprecated_behavior = 0x824d,
    undefined_behavior = 0x824e,
    portability = 0x824f,
    performance = 0x8250,
    other = 0x8251,
    // Not sure about these 3
    marker = 0x8268,
    push_group = 0x8269,
    pop_group = 0x826a,
};

const GLDebugSeverity = enum(u32) {
    high = 0x9146,
    medium = 0x9147,
    low = 0x9148,
    notification = 0x826b,
};

pub fn opengl_debug_callback(source: c.GLenum, message_type: c.GLenum, id: c.GLuint, severity: c.GLenum, length: c.GLsizei, message: [*c]const c.GLchar, userParam: ?*const c.GLvoid) callconv(.C) void {
    const debug_source = @intToEnum(GLDebugSource, source);
    const debug_type = @intToEnum(GLDebugType, message_type);
    const debug_severity = @intToEnum(GLDebugSeverity, severity);

    std.log.debug("[{}][{}][{}] - {s}", .{debug_severity, debug_type, debug_source, message});

    if (debug_severity == GLDebugSeverity.high) {
        panic("An High severity message was received.", .{});
    }

    if (debug_type == GLDebugType.@"error") {
        panic("An OpenGL error occurred.", .{});
    }
}
