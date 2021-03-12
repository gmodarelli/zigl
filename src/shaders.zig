const c = @import("c.zig");
const std = @import("std");
const panic = std.debug.panic;

pub fn createProgram(allocator: *std.mem.Allocator, vertex_shader_path: []const u8, fragment_shader_path: []const u8) !c.GLuint {
    const cwd = std.fs.cwd();

    const vertex_shader_file = try cwd.openFile(vertex_shader_path, std.fs.File.OpenFlags{ .read = true, .write = false });
    defer vertex_shader_file.close();

    const fragment_shader_file = try cwd.openFile(fragment_shader_path, std.fs.File.OpenFlags{ .read = true, .write = false });
    defer fragment_shader_file.close();

    var vertex_source = try allocator.alloc(u8, try vertex_shader_file.getEndPos());
    defer allocator.free(vertex_source);

    var fragment_source = try allocator.alloc(u8, try fragment_shader_file.getEndPos());
    defer allocator.free(fragment_source);

    var _bytes_read = try vertex_shader_file.read(vertex_source);
    _bytes_read = try fragment_shader_file.read(fragment_source);

    const vertex_shader = c.glCreateShader(c.GL_VERTEX_SHADER);
    const vertex_source_ptr: ?[*]const u8 = vertex_source.ptr;
    const vertex_source_len = @intCast(c.GLint, vertex_source.len);
    c.glShaderSource(vertex_shader, 1, &vertex_source_ptr, &vertex_source_len);
    c.glCompileShader(vertex_shader);
    checkForErrors(vertex_shader, "VERTEX");

    const fragment_shader = c.glCreateShader(c.GL_FRAGMENT_SHADER);
    const fragment_source_ptr: ?[*]const u8 = fragment_source.ptr;
    const fragment_source_len = @intCast(c.GLint, fragment_source.len);
    c.glShaderSource(fragment_shader, 1, &fragment_source_ptr, &fragment_source_len);
    c.glCompileShader(fragment_shader);
    checkForErrors(fragment_shader, "FRAGMENT");

    const shader_program = c.glCreateProgram();
    c.glAttachShader(shader_program, vertex_shader);
    c.glAttachShader(shader_program, fragment_shader);
    c.glLinkProgram(shader_program);
    checkForErrors(shader_program, "PROGRAM");

    c.glDeleteShader(vertex_shader);
    c.glDeleteShader(fragment_shader);

    return shader_program;
}

fn checkForErrors(resource: c_uint, error_type: []const u8) void {
    var success: c_int = undefined;
    var infoLog: [512]u8 = undefined;

    if (std.mem.eql(u8, error_type, "PROGRAM")) {
        c.glGetProgramiv(resource, c.GL_LINK_STATUS, &success);
        if (success == 0) {
            c.glGetProgramInfoLog(resource, 512, null, &infoLog);
            panic("Program linking failed:\n{}\n", .{infoLog});
        }
    } else {
        c.glGetShaderiv(resource, c.GL_COMPILE_STATUS, &success);
        if (success == 0) {
            c.glGetShaderInfoLog(resource, 512, null, &infoLog);
            panic("Shader compilation failed:\n{}\n", .{infoLog});
        }
    }
}
