const std = @import("std");
const Builder = std.build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    var exe = b.addExecutable("zigopengl", "src/main.zig");
    exe.setBuildMode(b.standardReleaseOptions());

    // Includes
    exe.addIncludeDir("third_party/include");

    // Sources
    exe.addCSourceFile("third_party/src/glad.c", &[_][]const u8{"-std=c99"});

    // Libraries
    exe.linkLibC();
    exe.addLibPath("third_party/lib");
    exe.linkSystemLibrary("glfw3");

    switch (builtin.os.tag) {
        .windows => {
            exe.linkSystemLibrary("kernel32");
            exe.linkSystemLibrary("user32");
            exe.linkSystemLibrary("shell32");
            exe.linkSystemLibrary("gdi32");
            exe.linkSystemLibrary("opengl32");
        },
        else => {
            @compileError("Platform not supported");
        },
    }

    exe.install();

    b.default_step.dependOn(&exe.step);
    b.step("learnzig", "Learning Zig").dependOn(&exe.run().step);
}