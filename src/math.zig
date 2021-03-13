const std = @import("std");
const testing = std.testing;

const toRadiansFactor: f32 = std.math.pi / 180.0;
const toDegreesFactor: f32 = 1.0 / (std.math.pi / 180.0);

pub fn toRadians(degrees: f32) f32 {
    return degrees * toRadiansFactor;
}

pub fn toDegrees(radians: f32) f32 {
    return radians * toDegreesFactor;
}

pub fn Vec2(comptime T: type) type {
    return packed struct {
        const Self = @This();

        x: T,
        y: T,

        pub fn init(x: T, y: T) Self {
            const self = Self{
                .x = x,
                .y = y,
            };
            return self;
        }

        pub fn add(a: Self, b: Self) Self {
            return Self.init(a.x + b.x, a.y + b.y);
        }

        pub fn subtract(a: Self, b: Self) Self {
            return Self.init(a.x - b.x, a.y - b.y);
        }

        pub fn negate(self: Self) Self {
            return Self.init(-self.x, -self.y);
        }

        pub fn scale(self: Self, factor: T) Self {
            return Self.init(self.x * factor, self.y * factor);
        }
    };
}

pub fn Vec3(comptime T: type) type {
    return packed struct {
        const Self = @This();

        x: T,
        y: T,
        z: T,

        pub fn init(x: T, y: T, z: T) Self {
            const self = Self{
                .x = x,
                .y = y,
                .z = z,
            };
            return self;
        }

        pub fn add(a: Self, b: Self) Self {
            return Self.init(a.x + b.x, a.y + b.y, a.z + b.z);
        }

        pub fn subtract(a: Self, b: Self) Self {
            return Self.init(a.x - b.x, a.y - b.y, a.z - b.z);
        }

        pub fn negate(self: Self) Self {
            return Self.init(-self.x, -self.y, -self.z);
        }

        pub fn scale(self: Self, factor: T) Self {
            return Self.init(self.x * factor, self.y * factor, self.z * factor);
        }

        pub fn dot(a: Self, b: Self) T {
            return a.x * b.x + a.y * b.y + a.z * b.z;
        }

        pub fn cross(a: Self, b: Self) Self {
            return Self.init(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x);
        }

        pub fn length(self: Self) T {
            return std.math.sqrt(self.lengthSqr());
        }

        pub fn lengthSqr(self: Self) T {
            return (self.x * self.x + self.y * self.y + self.z * self.z);
        }

        pub fn normalize(self: Self) Self {
            return self.scale(1.0 / self.length());
        }
    };
}

pub fn Vec4(comptime T: type) type {
    return packed struct {
        const Self = @This();

        x: T,
        y: T,
        z: T,
        w: T,

        pub fn init(x: T, y: T, z: T, w: T) Self {
            const self = Self{
                .x = x,
                .y = y,
                .z = z,
                .w = w,
            };
            return self;
        }

        pub fn add(a: Self, b: Self) Self {
            return Self.init(a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w);
        }

        pub fn subtract(a: Self, b: Self) Self {
            return Self.init(a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w);
        }

        pub fn negate(self: Self) Self {
            return Self.init(-self.x, -self.y, -self.z, -self.w);
        }

        pub fn scale(self: Self, factor: T) Self {
            return Self.init(self.x * factor, self.y * factor, self.z * factor, self.w * factor);
        }

        pub fn length(self: Self) T {
            return std.math.sqrt(self.lengthSqr());
        }

        pub fn lengthSqr(self: Self) T {
            return (self.x * self.x + self.y * self.y + self.z * self.z + self.w * self.w);
        }

        pub fn normalize(self: Self) Self {
            return self.scale(1.0 / self.length());
        }
    };
}

pub fn Mat4(comptime T: type) type {
    return packed struct {
        const Self = @This();

        // column-major
        data: [4][4]T,

        pub fn identity() Self {
            const self = Self{
                .data = .{
                    .{ 1, 0, 0, 0 },
                    .{ 0, 1, 0, 0 },
                    .{ 0, 0, 1, 0 },
                    .{ 0, 0, 0, 1 },
                },
            };
            return self;
        }

        pub fn mulVec4(self: *const Self, vec: Vec4(T)) Vec4(T) {
            var result: Vec4(T) = undefined;

            result.x = (self.data[0][0] * vec.x) + (self.data[1][0] * vec.y) + (self.data[2][0] * vec.z) + (self.data[3][0] * vec.w);
            result.x = (self.data[0][1] * vec.x) + (self.data[1][1] * vec.y) + (self.data[2][1] * vec.z) + (self.data[3][1] * vec.w);
            result.x = (self.data[0][2] * vec.x) + (self.data[1][2] * vec.y) + (self.data[2][2] * vec.z) + (self.data[3][2] * vec.w);
            result.x = (self.data[0][3] * vec.x) + (self.data[1][3] * vec.y) + (self.data[2][3] * vec.z) + (self.data[3][3] * vec.w);

            return result;
        }

        pub fn TRS(position: Vec3(T), rotation: Vec3(T), scale_vector: Vec3(T)) Self {
            var translation_matrix = Self.translate(position);

            var rotation_matrix = Self.rotate(rotation.x, Vec3(T).init(1, 0, 0));
            rotation_matrix = rotation_matrix.mul(Mat4(T).rotate(rotation.y, Vec3(T).init(0, 1, 0)));
            rotation_matrix = rotation_matrix.mul(Mat4(T).rotate(rotation.z, Vec3(T).init(0, 0, 1)));

            var scale_matrix = Self.scale(scale_vector);

            return (translation_matrix).mul((rotation_matrix).mul(scale_matrix));
        }

        pub fn scale(vec: Vec3(T)) Self {
            var scale_matrix = Self.identity();

            scale_matrix.data[0][0] = vec.x;
            scale_matrix.data[1][1] = vec.y;
            scale_matrix.data[2][2] = vec.z;

            return scale_matrix;
        }

        pub fn translate(vec: Vec3(T)) Self {
            var translation_matrix = Self.identity();

            translation_matrix.data[3][0] = vec.x;
            translation_matrix.data[3][1] = vec.y;
            translation_matrix.data[3][2] = vec.z;

            return translation_matrix;
        }

        pub fn rotate(angle_degrees: f32, axis: Vec3(T)) Self {
            const angle_radians: f32 = toRadians(angle_degrees);

            var rotation_matrix = Self.identity();
            const axis_normalized = axis.normalize();

            const sin_tetha: f32 = std.math.sin(angle_radians);
            const cos_tetha: f32 = std.math.cos(angle_radians);
            const cos_value: f32 = 1.0 - cos_tetha;

            rotation_matrix.data[0][0] = (axis_normalized.x * axis_normalized.x * cos_value) + cos_tetha;
            rotation_matrix.data[0][1] = (axis_normalized.x * axis_normalized.y * cos_value) + (axis_normalized.z * sin_tetha);
            rotation_matrix.data[0][2] = (axis_normalized.x * axis_normalized.z * cos_value) - (axis_normalized.y * sin_tetha);

            rotation_matrix.data[1][0] = (axis_normalized.y * axis_normalized.x * cos_value) - (axis_normalized.z * sin_tetha);
            rotation_matrix.data[1][1] = (axis_normalized.y * axis_normalized.y * cos_value) + cos_tetha;
            rotation_matrix.data[1][2] = (axis_normalized.y * axis_normalized.z * cos_value) + (axis_normalized.x * sin_tetha);

            rotation_matrix.data[2][0] = (axis_normalized.z * axis_normalized.x * cos_value) + (axis_normalized.y * sin_tetha);
            rotation_matrix.data[2][1] = (axis_normalized.z * axis_normalized.y * cos_value) - (axis_normalized.x * sin_tetha);
            rotation_matrix.data[2][2] = (axis_normalized.z * axis_normalized.z * cos_value) + cos_tetha;

            return rotation_matrix;
        }

        pub fn mul(self: Self, other: Self) Self {
            var result = Self.identity();
            var columns: usize = 0;

            while (columns < 4) : (columns += 1) {
                var rows: usize = 0;
                while (rows < 4) : (rows += 1) {
                    var sum: T = 0.0;
                    var current_mat: usize = 0;

                    while (current_mat < 4) : (current_mat += 1) {
                        sum += self.data[current_mat][rows] * other.data[columns][current_mat];
                    }

                    result.data[columns][rows] = sum;
                }
            }

            return result;
        }

        pub fn lookAt(eye: Vec3(T), target: Vec3(T), world_up: Vec3(T)) Self {
            const f: Vec3(T) = (target.subtract(eye)).normalize();
            const s: Vec3(T) = (f.cross(world_up)).normalize();
            const u: Vec3(T) = s.cross(f);

            var result: Self = undefined;

            result.data[0][0] = s.x;
            result.data[0][1] = u.x;
            result.data[0][2] = -f.x;
            result.data[0][3] = 0.0;

            result.data[1][0] = s.y;
            result.data[1][1] = u.y;
            result.data[1][2] = -f.y;
            result.data[1][3] = 0.0;

            result.data[2][0] = s.z;
            result.data[2][1] = u.z;
            result.data[2][2] = -f.z;
            result.data[2][3] = 0.0;

            result.data[3][0] = -(s.dot(eye));
            result.data[3][1] = -(u.dot(eye));
            result.data[3][2] = (f.dot(eye));
            result.data[3][3] = 1.0;

            return result;
        }

        pub fn perspective(fov_degrees: f32, aspect: f32, near: f32, far: f32) Self {
            const fov_radians: f32 = toRadians(fov_degrees);

            const f = 1.0 / std.math.tan(0.5 * fov_radians);

            var result = Self.identity();

            result.data[0][0] = f / aspect;
            result.data[1][1] = f;
            result.data[2][2] = (near + far) / (near - far);
            result.data[2][3] = -1.0;
            result.data[3][2] = 2.0 * far * near / (near - far);

            return result;
        }
    };
}
