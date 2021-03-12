const std = @import("std");
const math = @import("math.zig");
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;

const VertexMap = std.HashMap([]const u8, u32, std.hash_map.hashString, std.hash_map.eqlString, 80);

pub const Vertex = struct {
    position: Vec3(f32),
    normal: Vec3(f32),
    uv0: Vec2(f32),
};

pub const Mesh = struct {
    vertex_base: u32,
    index_offset: u32,
    vertex_count: u32,
    index_count: u32,
};

pub const Geometry = struct {
    vertices: std.ArrayList(Vertex),
    indices: std.ArrayList(u32),
    allocator: *std.mem.Allocator,

    pub fn init(self: *Geometry, allocator: *std.mem.Allocator) void {
        self.allocator = allocator;
        self.vertices = std.ArrayList(Vertex).init(self.allocator);
        self.indices = std.ArrayList(u32).init(self.allocator);
    }

    pub fn deinit(self: *Geometry) void {
        self.vertices.deinit();
        self.indices.deinit();
    }

    // TODO: We should load OBJ files and convert them to an internal format
    // that we can upload directly to the GPU.
    pub fn loadObj(self: *Geometry, obj_path: []const u8) !Mesh {
        var result: Mesh = undefined;
        result.vertex_base = @intCast(u32, self.vertices.items.len);
        result.index_offset = @intCast(u32, self.indices.items.len);

        const cwd = std.fs.cwd();
        const obj_file = try cwd.openFile(obj_path, .{});
        defer obj_file.close();

        const data: []u8 = try obj_file.readToEndAlloc(self.allocator, 1024 * 1024);
        defer self.allocator.free(data);

        var vertex_map = VertexMap.init(self.allocator);
        defer vertex_map.deinit();

        var positions = std.ArrayList(Vec3(f32)).init(self.allocator);
        defer positions.deinit();
        var uvs = std.ArrayList(Vec2(f32)).init(self.allocator);
        defer uvs.deinit();
        var normals = std.ArrayList(Vec3(f32)).init(self.allocator);
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
                        try self.indices.append(index.?);
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

                    const new_index: u32 = @intCast(u32, self.vertices.items.len) - result.vertex_base;
                    try vertex_map.putNoClobber(face, new_index);
                    try self.indices.append(new_index);
                    try self.vertices.append(vertex);
                }
            }
        }

        result.index_count = @intCast(u32, self.indices.items.len) - result.index_offset;
        result.vertex_count = @intCast(u32, self.vertices.items.len) - result.vertex_base;

        return result;
    }
};
