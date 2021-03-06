const std = @import("std");
const builtin = @import("builtin");
const panic = std.debug.panic;

usingnamespace @import("c.zig");

const math = @import("math.zig");
const Vec3 = math.Vec3;

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
    \\void main() {
    \\  gl_Position = vec4(position.xyz, 1.0);
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
    \\  vec3 c = mix(normal * 0.5 - 0.5, vec3(uv.xy, 0), 0.5);
    \\  color = vec4(c, 1.0f);
    \\};
;

pub fn main() !void {

    const ok = glfwInit();
    if (ok == 0) {
        panic("Failed to initialize GLFW\n", .{});
    }
    defer glfwTerminate();

    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 5);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);
    glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT, GL_TRUE);

    var window = glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "Learn Zig", null, null);
    if (window == null) {
        panic("Failed to create GLFW window\n", .{});
    }

    glfwMakeContextCurrent(window);

    if (gladLoadGLLoader(@ptrCast(GLADloadproc, glfwGetProcAddress)) == 0) {
        panic("Failed to initialize GLAD\n", .{});
    }

    std.log.debug("GL_VENDOR: {s}", .{glGetString(GL_VENDOR)});
    std.log.debug("GL_VERSION: {s}", .{glGetString(GL_VERSION)});
    std.log.debug("GL_RENDERER: {s}", .{glGetString(GL_RENDERER)});

    // Check for debug context
    var flags: i32 = 0;
    glGetIntegerv(GL_CONTEXT_FLAGS, &flags);
    if (flags & GL_CONTEXT_FLAG_DEBUG_BIT != 0) {
        std.log.debug("Debug context available", .{});
    }

    glDebugMessageCallback(opengl_debug_callback, null);
    glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);

    const vertexShaderPtr: ?[*]const u8 = vertexShaderSource.ptr;
    const fragmentShaderPtr: ?[*]const u8 = fragmentShaderSource.ptr;
    const shaderProgram = compileShaders(vertexShaderPtr, fragmentShaderPtr);

    var vertices = try model.loadModel(global_allocator, "data/models/cube.obj");

    var vao: GLuint = undefined;
    var buffer: GLuint = undefined;

    // Create the Vertex Array Object
    glGenVertexArrays(1, &vao);
    glBindVertexArray(vao);

    // Allocate and initialize a buffer object
    glCreateBuffers(1, &buffer);
    glNamedBufferStorage(buffer, @intCast(c_longlong, @sizeOf(Vertex) * vertices.len), vertices.ptr, 0);

    // Bind the buffer to the vertex array object
    glVertexArrayVertexBuffer(vao, 0, buffer, 0, @sizeOf(Vertex));

    // Set up two vertex attributes.
    // Position
    glVertexArrayAttribBinding(vao, 0, 0);
    glVertexArrayAttribFormat(vao, 0, 3, GL_FLOAT, GL_FALSE, @byteOffsetOf(Vertex, "position"));
    glEnableVertexAttribArray(0);
    // Normal
    glVertexArrayAttribBinding(vao, 1, 0);
    glVertexArrayAttribFormat(vao, 1, 3, GL_FLOAT, GL_FALSE, @byteOffsetOf(Vertex, "normal"));
    glEnableVertexAttribArray(1);
    // UV
    glVertexArrayAttribBinding(vao, 2, 0);
    glVertexArrayAttribFormat(vao, 2, 2, GL_FLOAT, GL_FALSE, @byteOffsetOf(Vertex, "uv0"));
    glEnableVertexAttribArray(2);

    glBindVertexArray(0);

    while (glfwWindowShouldClose(window) == 0) {
        const color = [_]GLfloat{ 0.0, 0.2, 0.0, 1.0 };
        glClearBufferfv(GL_COLOR, 0, @ptrCast([*c]const GLfloat, &color));

        glUseProgram(shaderProgram);
        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLES, 0, @intCast(c_int, vertices.len));
        glBindVertexArray(0);

        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    global_allocator.free(vertices);
    const leaked = gpa.deinit();
    if (leaked) {
        std.log.debug("Memory leaked", .{});
    }
}

// TODO: Return the default error shader instead of panicing
fn compileShaders(vertexShaderPtr: ?[*]const u8, fragmentShaderPtr: ?[*]const u8) GLuint {
    var success: c_int = undefined;
    var infoLog: [512]u8 = undefined;

    const vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vertexShaderPtr, null);
    glCompileShader(vertexShader);
    glGetShaderiv(vertexShader, GL_COMPILE_STATUS, &success);
    if (success == 0) {
        glGetShaderInfoLog(vertexShader, 512, null, &infoLog);
        panic("ERROR::SHADER::VERTEX::COMPILATION_FAILED\n{}\n", .{infoLog});
    }

    const fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderPtr, null);
    glCompileShader(fragmentShader);
    glGetShaderiv(fragmentShader, GL_COMPILE_STATUS, &success);
    if (success == 0) {
        glGetShaderInfoLog(fragmentShader, 512, null, &infoLog);
        panic("ERROR::SHADER::FRAGMENT::COMPILATION_FAILED\n{}\n", .{infoLog});
    }

    const shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);
    glGetProgramiv(shaderProgram, GL_LINK_STATUS, &success);
    if (success == 0) {
        glGetProgramInfoLog(shaderProgram, 512, null, &infoLog);
        panic("ERROR::SHADER::PROGRAM::LINKING_FAILED\n{}\n", .{infoLog});
    }

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    return shaderProgram;
}

pub fn opengl_debug_callback(source: GLenum, messageType: GLenum, id: GLuint, severity: GLenum, length: GLsizei, message: [*c]const GLchar, userParam: ?*const GLvoid) callconv(.C) void {
    std.log.debug("{s}", .{message});
}