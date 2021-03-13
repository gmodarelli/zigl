const std = @import("std");
const Builder = std.build.Builder;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    // Main application
    // ================
    mainApp(b);

    // Tools:
    // Obj -> Bin
    objToBin(b);
}

fn mainApp(b: *Builder) void {
    var app = b.addExecutable("zigl", "src/main.zig");
    app.setBuildMode(b.standardReleaseOptions());

    // Includes
    app.addIncludeDir("third_party/include");

    // Sources
    app.addCSourceFile("third_party/src/glad.c", &[_][]const u8{"-std=c99"});
    app.addCSourceFile("third_party/src/stb_image_implementation.c", &[_][]const u8{"-std=c99"});

    // Libraries
    app.linkLibC();
    app.addLibPath("third_party/lib");
    app.linkSystemLibrary("glfw3");

    // Zig libs
    app.addPackagePath("zalgebra", "../zalgebra/src/main.zig");

    switch (builtin.os.tag) {
        .windows => {
            app.linkSystemLibrary("kernel32");
            app.linkSystemLibrary("user32");
            app.linkSystemLibrary("shell32");
            app.linkSystemLibrary("gdi32");
            app.linkSystemLibrary("opengl32");
        },
        else => {
            @compileError("Platform not supported");
        },
    }

    app.install();

    b.default_step.dependOn(&app.step);
    b.step("mainapp", "Main Application").dependOn(&app.run().step);
}

fn objToBin(b: *Builder) void {
    var app = b.addExecutable("obj_to_bin", "src/obj_to_bin.zig");
    app.setBuildMode(b.standardReleaseOptions());

    switch (builtin.os.tag) {
        .windows => {
            app.linkSystemLibrary("kernel32");
            app.linkSystemLibrary("user32");
            app.linkSystemLibrary("shell32");
        },
        else => {
            @compileError("Platform not supported");
        },
    }

    // Zig libs
    app.addPackagePath("zalgebra", "../zalgebra/src/main.zig");

    app.install();

    b.default_step.dependOn(&app.step);
    b.step("obj_to_bin", "Obj 2 Bin Conversion").dependOn(&app.run().step);
}