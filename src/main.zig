const std = @import("std");
const panic = std.debug.panic;
const c = @import("c.zig");
const scene_renderer = @import("scene_renderer.zig");
const Scene = scene_renderer.Scene;
const CameraMovement = @import("camera.zig").CameraMovement;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var global_allocator = &gpa.allocator;

const SCR_WIDTH: u32 = 1920;
const SCR_HEIGHT: u32 = 1080;

fn keyCallback(window: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
    const scene = @ptrCast(*Scene, @alignCast(@alignOf(Scene), c.glfwGetWindowUserPointer(window).?));

    if (action == c.GLFW_PRESS or action == c.GLFW_REPEAT)
    {
        switch (key) {
            c.GLFW_KEY_W => scene.updateCamera(CameraMovement.forward),
            c.GLFW_KEY_S => scene.updateCamera(CameraMovement.backward),
            c.GLFW_KEY_A => scene.updateCamera(CameraMovement.left),
            c.GLFW_KEY_D => scene.updateCamera(CameraMovement.right),
            c.GLFW_KEY_Q => scene.updateCamera(CameraMovement.up),
            c.GLFW_KEY_E => scene.updateCamera(CameraMovement.down),
            else => {}
        }
    }
}

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

    var window = c.glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "Zigl", null, null);
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

    var scene: Scene = undefined;
    try scene.init(global_allocator, SCR_WIDTH, SCR_HEIGHT);

    c.glfwSetWindowUserPointer(window, @ptrCast(*c_void, &scene));
    _ = c.glfwSetKeyCallback(window, keyCallback);

    var current_time = c.glfwGetTime();
    var last_time = current_time;
    var delta_time: f32 = 0.0;

    while (c.glfwWindowShouldClose(window) == 0) {
        scene.update(delta_time);

        // Clear color and depth
        const color = [_]c.GLfloat{ 0.1, 0.1, 0.1, 1.0 };
        const depth = [_]c.GLfloat{0.0};
        c.glClearBufferfv(c.GL_COLOR, 0, @ptrCast([*c]const c.GLfloat, &color));
        c.glClearBufferfi(c.GL_DEPTH_STENCIL, 0, 1.0, 0);

        scene.render();

        c.glfwSwapBuffers(window);
        c.glfwPollEvents();

        current_time = c.glfwGetTime();
        delta_time = @floatCast(f32, current_time - last_time);
        last_time = current_time;
    }

    scene.deinit();

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

    std.log.debug("[{}][{}][{}] - {s}", .{ debug_severity, debug_type, debug_source, message });

    if (debug_severity == GLDebugSeverity.high) {
        panic("An High severity message was received.", .{});
    }

    if (debug_type == GLDebugType.@"error") {
        panic("An OpenGL error occurred.", .{});
    }
}
