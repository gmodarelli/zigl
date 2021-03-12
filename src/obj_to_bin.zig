const std = @import("std");
const math = @import("math.zig");
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const model = @import("model.zig");
const Vertex = model.Vertex;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var global_allocator = &gpa.allocator;

const VertexMap = std.HashMap([]const u8, u32, std.hash_map.hashString, std.hash_map.eqlString, 80);

pub const mesh_file_magic = [4]u8{ 'M', 'E', 'S', 'H' };

pub const mesh_vertex_header_magic = [4]u8{ 'H', 'V', 'T', 'X' };
pub const VertexHeader = packed struct {
    vertex_stride: u32,
    vertex_count: u32,
};

pub const mesh_index_header_magic = [4]u8{ 'H', 'I', 'D', 'X' };
pub const IndexHeader = packed struct {
    index_stride: u32,
    index_count: u32,
};

pub fn main() !void {
    try convertObj("data/models/default_cube.obj", "data/models/default_cube.pjm");
}

fn convertObj(obj_path: []const u8, mesh_path: []const u8) !void {
    const cwd = std.fs.cwd();
    const obj_file = try cwd.openFile(obj_path, std.fs.File.OpenFlags{ .read = true, .write = false });
    defer obj_file.close();

    const mesh_file = try cwd.createFile(mesh_path, .{});
    defer mesh_file.close();

    // mesh_file.write(mesh_file_magic);

    var data = try global_allocator.alloc(u8, try obj_file.getEndPos());
    defer global_allocator.free(data);

    const readBytes = try obj_file.read(data);

    var vertex_map = VertexMap.init(global_allocator);
    defer vertex_map.deinit();

    var positions = std.ArrayList(Vec3(f32)).init(global_allocator);
    defer positions.deinit();
    var uvs = std.ArrayList(Vec2(f32)).init(global_allocator);
    defer uvs.deinit();
    var normals = std.ArrayList(Vec3(f32)).init(global_allocator);
    defer normals.deinit();

    var vertices = std.ArrayList(Vertex).init(global_allocator);
    defer vertices.deinit();
    var indices = std.ArrayList(u32).init(global_allocator);
    defer indices.deinit();

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
                    0 => uv.y = try std.fmt.parseFloat(f32, value),
                    1 => uv.x = try std.fmt.parseFloat(f32, value),
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
            try normals.append(normal.normalize());
        } else if (std.mem.eql(u8, line[0..2], "f ")) { // Collect vertices and create indices
            var faces = std.mem.tokenize(line[2..], " ");
            while (faces.next()) |face| {
                var index = vertex_map.get(face);
                if (index != null) {
                    try indices.append(index.?);
                    continue;
                }

                var vertex: Vertex = undefined;
                var components_indices = std.mem.tokenize(face, "/");

                var i: u8 = 0;
                while (components_indices.next()) |index_string| {
                    const element_index = (try std.fmt.parseUnsigned(usize, index_string, 10)) - 1;

                    switch (i) {
                        0 => vertex.position = positions.items[element_index],
                        1 => vertex.uv0 = uvs.items[element_index],
                        2 => vertex.normal = normals.items[element_index],
                        else => {},
                    }

                    i += 1;
                }

                const new_index: u32 = @intCast(u32, vertices.items.len);
                try vertex_map.putNoClobber(face, new_index);
                try indices.append(new_index);
                try vertices.append(vertex);
            }
        }
    }

    std.log.debug("Vertex count: {}", .{vertices.items.len});
    std.log.debug("Index count: {}", .{indices.items.len});

    // mesh_file.write(mesh_vertex_header_magic);
    // mesh_file.write(vertices.items.len);
    // mesh_file.write(vertices.items)
 
    // mesh_file.write(mesh_index_header_magic);
    // mesh_file.write(indices.items.len);
    // mesh_file.write(indices.items)
}
