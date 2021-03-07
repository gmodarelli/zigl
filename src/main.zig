const std = @import("std");
const builtin = @import("builtin");
const panic = std.debug.panic;

const c = @import("c.zig");

const math = @import("math.zig");
const Vec3 = math.Vec3;
const Mat4 = math.Mat4;

const model = @import("model.zig");
const Vertex = model.Vertex;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var global_allocator = &gpa.allocator;

const SCR_WIDTH: u32 = 1920;
const SCR_HEIGHT: u32 = 1080;

// [:0]const u8 means null-terminated array of chars
const vertexShaderSource: [:0]const u8 =
    \\#version 450 core
    \\layout (location = 0) in vec3 position;
    \\layout (location = 1) in vec3 normal;
    \\layout (location = 2) in vec2 uv;
    \\layout (location = 0) out vec2 outUV;
    \\layout (location = 1) out vec3 outNormal;
    \\layout (std140, binding = 0) uniform SceneTransformBlock {
    \\  mat4 view_matrix;
    \\  mat4 proj_matrix;
    \\} scene;
    \\layout (std140, binding = 1) uniform ObjectTransformBlock {
    \\  mat4 model_matrix;
    \\} object;
    \\void main() {
    \\  gl_Position = scene.proj_matrix * scene.view_matrix * object.model_matrix * vec4(position.xyz, 1.0);
    \\  outUV = uv;
    \\  outNormal = normal;
    \\};
;

const fragmentShaderSource: [:0]const u8 =
    \\#version 450 core
    \\layout (location = 0) in vec2 uv;
    \\layout (location = 1) in vec3 normal;
    \\out vec4 color;
    \\void main() {
    \\  color = vec4(normal * 0.5f + 0.5f, 1.0f);
    \\};
;

const SceneParams = struct {
    view_matrix: Mat4(f32),
    proj_matrix: Mat4(f32),
};

const ModelTransform = struct {
    model_matrix: Mat4(f32),
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

    const vertexShaderPtr: ?[*]const u8 = vertexShaderSource.ptr;
    const fragmentShaderPtr: ?[*]const u8 = fragmentShaderSource.ptr;
    const shaderProgram = compileShaders(vertexShaderPtr, fragmentShaderPtr);

    var scene_params = SceneParams {
        .view_matrix = Mat4(f32).lookAt(Vec3(f32).init(0, 0, 0), Vec3(f32).init(0, 0, -1), Vec3(f32).init(0, 1, 0)),
        .proj_matrix = Mat4(f32).perspective(60.0, @intToFloat(f32, SCR_WIDTH) / @intToFloat(f32, SCR_HEIGHT), 0.001, 1000.0),
    };

    var suzanne_mesh = try model.loadModel(global_allocator, "data/models/suzanne.obj");
    var suzanne_position = Vec3(f32).init(0, 0, -5);
    var suzanne_scale = Vec3(f32).init(1, 1, 1);
    var suzanne_rotation = Vec3(f32).init(0, 0, 0);
    var suzanne_transform = ModelTransform {
        .model_matrix = Mat4(f32).TRS(suzanne_position, suzanne_rotation, suzanne_scale),
    };

    var scene_uniform_buffer: c.GLuint = undefined;
    c.glCreateBuffers(1, &scene_uniform_buffer);
    c.glNamedBufferStorage(scene_uniform_buffer, @intCast(c_longlong, @sizeOf(SceneParams)), &scene_params, 0);

    var suzanne_uniform_buffer: c.GLuint = undefined;
    c.glCreateBuffers(1, &suzanne_uniform_buffer);
    c.glNamedBufferStorage(suzanne_uniform_buffer, @intCast(c_longlong, @sizeOf(ModelTransform)), &suzanne_transform, c.GL_DYNAMIC_STORAGE_BIT);

    var vao: c.GLuint = undefined;
    var vbo: c.GLuint = undefined;

    // Create the Vertex Array Object
    c.glGenVertexArrays(1, &vao);
    c.glBindVertexArray(vao);

    // Allocate and initialize a buffer object
    c.glCreateBuffers(1, &vbo);
    c.glNamedBufferStorage(vbo, @intCast(c_longlong, @sizeOf(Vertex) * suzanne_mesh.len), suzanne_mesh.ptr, c.GL_DYNAMIC_STORAGE_BIT);

    // Bind the buffer to the vertex array object
    c.glVertexArrayVertexBuffer(vao, 0, vbo, 0, @sizeOf(Vertex));

    // Set up two vertex attributes.
    // Position
    c.glVertexArrayAttribBinding(vao, 0, 0);
    c.glVertexArrayAttribFormat(vao, 0, 3, c.GL_FLOAT, c.GL_FALSE, @byteOffsetOf(Vertex, "position"));
    c.glEnableVertexAttribArray(0);
    // Normal
    c.glVertexArrayAttribBinding(vao, 1, 0);
    c.glVertexArrayAttribFormat(vao, 1, 3, c.GL_FLOAT, c.GL_FALSE, @byteOffsetOf(Vertex, "normal"));
    c.glEnableVertexAttribArray(1);
    // UV
    c.glVertexArrayAttribBinding(vao, 2, 0);
    c.glVertexArrayAttribFormat(vao, 2, 2, c.GL_FLOAT, c.GL_FALSE, @byteOffsetOf(Vertex, "uv0"));
    c.glEnableVertexAttribArray(2);

    c.glBindVertexArray(0);

    var current_time = c.glfwGetTime();
    var last_time = current_time;
    var delta_time: f32 = 0.0;
    var suzanne_rotation_duration_seconds: f32 = 4.0;
    var suzanne_rotation_progress: f32 = 0.0;
    var suzanne_rotation_time_elapsed: f32 = 0.0;

    while (c.glfwWindowShouldClose(window) == 0) {
        // Clear color and depth
        const color = [_]c.GLfloat{ 0.1, 0.1, 0.1, 1.0 };
        const depth = [_]c.GLfloat{ 0.0 };
        c.glClearBufferfv(c.GL_COLOR, 0, @ptrCast([*c]const c.GLfloat, &color));
        c.glClearBufferfi(c.GL_DEPTH_STENCIL, 0, 1.0, 0);

        // Bind vertex buffer (this should be for all geometry)
        c.glBindVertexArray(vao);

        c.glUseProgram(shaderProgram);
        c.glFrontFace(c.GL_CCW);
        c.glEnable(c.GL_DEPTH_TEST);

        c.glBindBufferBase(c.GL_UNIFORM_BUFFER, 0, scene_uniform_buffer);

        {
            suzanne_rotation_time_elapsed += delta_time;
            suzanne_rotation_progress = suzanne_rotation_time_elapsed / suzanne_rotation_duration_seconds;
            if (suzanne_rotation_time_elapsed >= suzanne_rotation_duration_seconds) {
                suzanne_rotation_time_elapsed = 0.0;
                suzanne_rotation_progress = 0.0;
            }

            suzanne_rotation.y = suzanne_rotation_progress * 360.0;
            suzanne_transform = ModelTransform {
                .model_matrix = Mat4(f32).TRS(suzanne_position, suzanne_rotation, suzanne_scale),
            };
            c.glNamedBufferSubData(suzanne_uniform_buffer, 0, @intCast(c_longlong, @sizeOf(ModelTransform)), &suzanne_transform);
        }
        c.glBindBufferBase(c.GL_UNIFORM_BUFFER, 1, suzanne_uniform_buffer);
        c.glDrawArrays(c.GL_TRIANGLES, 0, @intCast(c_int, suzanne_mesh.len));

        c.glBindVertexArray(0);

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();

        // std.log.debug("dt {}", .{delta_time});
        current_time = c.glfwGetTime();
        delta_time = @floatCast(f32, current_time - last_time);
        last_time = current_time;
    }

    global_allocator.free(suzanne_mesh);
    const leaked = gpa.deinit();
    if (leaked) {
        std.log.debug("Memory leaked", .{});
    }
}

// TODO: Return the default error shader instead of panicing
fn compileShaders(vertexShaderPtr: ?[*]const u8, fragmentShaderPtr: ?[*]const u8) c.GLuint {
    var success: c_int = undefined;
    var infoLog: [512]u8 = undefined;

    const vertexShader = c.glCreateShader(c.GL_VERTEX_SHADER);
    c.glShaderSource(vertexShader, 1, &vertexShaderPtr, null);
    c.glCompileShader(vertexShader);
    c.glGetShaderiv(vertexShader, c.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        c.glGetShaderInfoLog(vertexShader, 512, null, &infoLog);
        panic("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n{}\n", .{infoLog});
    }

    const fragmentShader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    c.glShaderSource(fragmentShader, 1, &fragmentShaderPtr, null);
    c.glCompileShader(fragmentShader);
    c.glGetShaderiv(fragmentShader, c.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        c.glGetShaderInfoLog(fragmentShader, 512, null, &infoLog);
        panic("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n{}\n", .{infoLog});
    }

    const shaderProgram = c.glCreateProgram();
    c.glAttachShader(shaderProgram, vertexShader);
    c.glAttachShader(shaderProgram, fragmentShader);
    c.glLinkProgram(shaderProgram);
    c.glGetProgramiv(shaderProgram, c.GL_LINK_STATUS, &success);
    if (success == 0) {
        c.glGetProgramInfoLog(shaderProgram, 512, null, &infoLog);
        panic("ERROR::SHADER::PROGRAM::LINKING_FAILED\n{}\n", .{infoLog});
    }

    c.glDeleteShader(vertexShader);
    c.glDeleteShader(fragmentShader);

    return shaderProgram;
}

pub fn opengl_debug_callback(source: c.GLenum, messageType: c.GLenum, id: c.GLuint, severity: c.GLenum, length: c.GLsizei, message: [*c]const c.GLchar, userParam: ?*const c.GLvoid) callconv(.C) void {
    std.log.debug("{s}", .{message});
}