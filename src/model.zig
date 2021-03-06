const std = @import("std");
const math = @import("math.zig");
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;

const Vertex = struct {
    position: Vec3(f32),
    normal: Vec3(f32),
    uv0: Vec2(f32),
};

pub fn loadModel(allocator: *std.mem.Allocator, obj_path: []const u8) !void {
    const cwd = std.fs.cwd();
    const obj_file = try cwd.openFile(obj_path, .{});
    defer obj_file.close();

    const data: []u8 = try obj_file.readToEndAlloc(allocator, 1024 * 1024);
    defer allocator.free(data);

    var vertices = std.ArrayList(Vertex).init(allocator);
    defer vertices.deinit();

    var positions = std.ArrayList(Vec3(f32)).init(allocator);
    defer positions.deinit();
    var uvs = std.ArrayList(Vec2(f32)).init(allocator);
    defer uvs.deinit();
    var normals = std.ArrayList(Vec3(f32)).init(allocator);
    defer normals.deinit();

    var iterator = std.mem.tokenize(data, "\n");
    while (iterator.next()) |line| {
        // Skip comments
        if (std.mem.eql(u8, line[0..2], "# ")) continue;
        // Skip mesh name
        if (std.mem.eql(u8, line[0..2], "o ")) {
            std.log.debug("Parsing mesh: {}", .{line[2..]});
            continue;
        }
        // TODO: check what 's' stands for
        if (std.mem.eql(u8, line[0..2], "s ")) continue;

        
        if (std.mem.eql(u8, line[0..2], "v ")) { // Collect vertex positions
            var position: math.Vec3(f32) = undefined;
            var tonkeized_position = std.mem.tokenize(line[2..], " ");

            var i: u8 = 0;
            while (tonkeized_position.next()) |value| {
                switch (i) {
                    0 => position.x = try std.fmt.parseFloat(f32, value),
                    1 => position.y = try std.fmt.parseFloat(f32, value),
                    2 => position.z = try std.fmt.parseFloat(f32, value),
                    else => {},
                }

                i += 1;
            }
            try positions.append(position);
        } else if (std.mem.eql(u8, line[0..3], "vt ")) { // Collect vertex texture coordinates
            var uv: math.Vec2(f32) = undefined;
            var tonkeized_uv = std.mem.tokenize(line[3..], " ");

            var i: u8 = 0;
            while (tonkeized_uv.next()) |value| {
                switch (i) {
                    0 => uv.x = try std.fmt.parseFloat(f32, value),
                    1 => uv.y = try std.fmt.parseFloat(f32, value),
                    else => {},
                }

                i += 1;
            }
            try uvs.append(uv);
        } else if (std.mem.eql(u8, line[0..3], "vn ")) { // Collect vertex texture normals
            var normal: math.Vec3(f32) = undefined;
            var tonkeized_normal = std.mem.tokenize(line[3..], " ");

            var i: u8 = 0;
            while (tonkeized_normal.next()) |value| {
                switch (i) {
                    0 => normal.x = try std.fmt.parseFloat(f32, value),
                    1 => normal.y = try std.fmt.parseFloat(f32, value),
                    2 => normal.z = try std.fmt.parseFloat(f32, value),
                    else => {},
                }

                i += 1;
            }
            try normals.append(normal);
        } else if (std.mem.eql(u8, line[0..2], "f ")) { // Collect vertex texture normals
            var faces = std.mem.tokenize(line[2..], " ");
            while (faces.next()) |face| {
                var vertex: Vertex = undefined;
                var components_indices = std.mem.tokenize(face, "/");

                var i: u8 = 0;
                while (components_indices.next()) |index_string| {
                    const index = (try std.fmt.parseUnsigned(usize, index_string, 10)) - 1;

                    switch (i) {
                        0 => vertex.position = positions.items[index],
                        1 => vertex.uv0 = uvs.items[index],
                        2 => vertex.normal = normals.items[index],
                        else => {},
                    }

                    i += 1;
                }

                try vertices.append(vertex);
            }
        }
    }

    std.log.debug("positions: {}", .{positions.items.len});
    std.log.debug("uvs: {}", .{uvs.items.len});
    std.log.debug("normals: {}", .{normals.items.len});
    std.log.debug("vertices: {}", .{vertices.items.len});
}