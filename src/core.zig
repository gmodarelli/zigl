const c = @import("c.zig");
const std = @import("std");
const panic = std.debug.panic;

const SceneRenderer = @import("scene_renderer.zig").SceneRenderer;
const CameraMovement = @import("camera.zig").CameraMovement;
const input_module = @import("input.zig");
const Input = input_module.Input;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var global_allocator = &gpa.allocator;

pub const App = struct {
    const Self = @This();

    window: ?*c.GLFWwindow = null,
    current_time: f64,
    last_time: f64,
    delta_time: f32,

    input: Input,
    scene: SceneRenderer,

    pub fn init(self: *Self, width: u32, height: u32) !void {
        if (c.glfwInit() == 0) {
            panic("Failed to initialize GLFW\n", .{});
        }

        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 4);
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 5);
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
        c.glfwWindowHint(c.GLFW_OPENGL_DEBUG_CONTEXT, c.GL_TRUE);

        self.window = c.glfwCreateWindow(@intCast(c_int, width), @intCast(c_int, height), "Zigl", null, null);
        if (self.window == null) {
            panic("Failed to create GLFW window\n", .{});
        }

        self.input.init(self.window);

        c.glfwMakeContextCurrent(self.window);

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

        try self.scene.init(global_allocator, width, height, &self.input);

        self.current_time = c.glfwGetTime();
        self.last_time = self.current_time;
        self.delta_time = 0.0;
    }

    pub fn run(self: *Self) void {
        while (c.glfwWindowShouldClose(self.window) == 0) {
            self.scene.update(self.delta_time);
            self.scene.render();

            c.glfwSwapBuffers(self.window);
            c.glfwPollEvents();

            self.tick();
        }
    }

    pub fn deinit(self: *Self) void {
        self.scene.deinit();

        std.log.debug("Deinitializing app", .{});
        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();

        const memory_leaked = gpa.deinit();

        if (memory_leaked) {
            std.log.debug("Memory leaked", .{});
        }
    }

    fn tick(self: *Self) void {
        self.current_time = c.glfwGetTime();
        self.delta_time = @floatCast(f32, self.current_time - self.last_time);
        self.last_time = self.current_time;
    }
};

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

fn opengl_debug_callback(source: c.GLenum, message_type: c.GLenum, id: c.GLuint, severity: c.GLenum, length: c.GLsizei, message: [*c]const c.GLchar, userParam: ?*const c.GLvoid) callconv(.C) void {
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
