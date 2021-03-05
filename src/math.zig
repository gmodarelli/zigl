const std = @import("std");
const testing = std.testing;

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

        // column-first
        data: [16]T,

        pub fn identity() Self {
            const self = Self{
                .data = .{
                    1, 0, 0, 0,
                    0, 1, 0, 0,
                    0, 0, 1, 0,
                    0, 0, 0, 1,
                },
            };
            return self;
        }

        pub fn m00(self: *const Self) T { return self.data[0]; }
        pub fn m01(self: *const Self) T { return self.data[1]; }
        pub fn m02(self: *const Self) T { return self.data[2]; }
        pub fn m03(self: *const Self) T { return self.data[3]; }
        pub fn m10(self: *const Self) T { return self.data[4]; }
        pub fn m11(self: *const Self) T { return self.data[5]; }
        pub fn m12(self: *const Self) T { return self.data[6]; }
        pub fn m13(self: *const Self) T { return self.data[7]; }
        pub fn m20(self: *const Self) T { return self.data[8]; }
        pub fn m21(self: *const Self) T { return self.data[9]; }
        pub fn m22(self: *const Self) T { return self.data[10]; }
        pub fn m23(self: *const Self) T { return self.data[11]; }
        pub fn m30(self: *const Self) T { return self.data[12]; }
        pub fn m31(self: *const Self) T { return self.data[13]; }
        pub fn m32(self: *const Self) T { return self.data[14]; }
        pub fn m33(self: *const Self) T { return self.data[15]; }

        pub fn mul_vec4(self: *const Self, vec: Vec4(T)) Vec4(T) {
            const result = Vec4(T).init(
                self.m00() * vec.x + self.m10() * vec.y + self.m20() * vec.z + self.m30() * vec.w,
                self.m01() * vec.x + self.m11() * vec.y + self.m21() * vec.z + self.m31() * vec.w,
                self.m02() * vec.x + self.m12() * vec.y + self.m22() * vec.z + self.m32() * vec.w,
                self.m03() * vec.x + self.m13() * vec.y + self.m23() * vec.z + self.m33() * vec.w,
            );

            return result;
        }

        //pub fn mul_mat4(a: *const Self, b: *const Self) Self {
        //
        //}

        pub fn translate(vec: Vec3(T)) Self {
            var translation_matrix = Self.identity();
            translation_matrix.data[12] = vec.x;
            translation_matrix.data[13] = vec.y;
            translation_matrix.data[14] = vec.z;

            return translation_matrix;
        }
    };
}

test "vectors initialization" {
    const vec3 = Vec3(f32).init(1.0, 2.0, 3.0);
    testing.expect(vec3.x == 1.0 and vec3.y == 2.0 and vec3.z == 3.0);

    const vec4 = Vec4(f32).init(1.0, 2.0, 3.0, 4.0);
    testing.expect(vec4.x == 1.0 and vec4.y == 2.0 and vec4.z == 3.0 and vec4.w == 4.0);
}

test "vectors addition and subtraction" {
    const a = Vec3(f32).init(1.0, 2.0, 3.0);
    const b = Vec3(f32).init(1.0, 2.0, 3.0);
    const c = a.add(b);
    testing.expect(c.x == 2.0 and c.y == 4.0 and c.z == 6.0);

    const d = Vec4(f32).init(1.0, 2.0, 3.0, 4.0);
    const e = Vec4(f32).init(1.0, 2.0, 3.0, 4.0);
    const f = d.add(e);
    testing.expect(f.x == 2.0 and f.y == 4.0 and f.z == 6.0 and f.w == 8.0);
}

test "vectors negation" {
    const a = Vec3(f32).init(1.0, 2.0, 3.0);
    const b = a.negate();
    testing.expect(b.x == -1.0 and b.y == -2.0 and b.z == -3.0);

    const c = Vec4(f32).init(1.0, 2.0, 3.0, 4.0);
    const d = c.negate();
    testing.expect(d.x == -1.0 and d.y == -2.0 and d.z == -3.0 and d.w == -4.0);
}

test "vectors scaling" {
    const a = Vec3(f32).init(1.0, 2.0, 3.0);
    const b = a.scale(2.0);
    testing.expect(b.x == 2.0 and b.y == 4.0 and b.z == 6.0);

    const c = Vec4(f32).init(1.0, 2.0, 3.0, 4.0);
    const d = c.scale(2.0);
    testing.expect(d.x == 2.0 and d.y == 4.0 and d.z == 6.0 and d.w == 8.0);
}

test "vector dot product" {
    const eps_value = comptime std.math.epsilon(f32);

    const a = Vec3(f32).init(0.5, 0.5, 0.0);
    const b = Vec3(f32).init(0.0, 0.5, 0.5);
    testing.expect(std.math.approxEqAbs(f32, a.dot(b), 0.25, eps_value));
    testing.expect(std.math.approxEqAbs(f32, b.dot(a), 0.25, eps_value));
}

test "vector cross product" {
    const up = Vec3(f32).init(0.0, 1.0, 0.0);
    const forward = Vec3(f32).init(0.0, 0.0, 1.0);

    var right = up.cross(forward);
    testing.expect(right.x == 1.0 and right.y == 0.0 and right.z == 0.0);

    right = forward.cross(up);
    testing.expect(right.x == -1.0 and right.y == 0.0 and right.z == 0.0);
}

test "vector length" {
    const eps_value = comptime std.math.epsilon(f32);

    const a = Vec3(f32).init(1.0, 2.0, 3.0);
    testing.expect(std.math.approxEqAbs(f32, a.length(), std.math.sqrt(14.0), eps_value));
    testing.expect(std.math.approxEqAbs(f32, a.lengthSqr(), 14.0, eps_value));

    const b = Vec4(f32).init(1.0, 2.0, 3.0, 4.0);
    testing.expect(std.math.approxEqAbs(f32, b.length(), std.math.sqrt(30.0), eps_value));
    testing.expect(std.math.approxEqAbs(f32, b.lengthSqr(), 30.0, eps_value));
}

test "vector normalization" {
    const eps_value = comptime std.math.epsilon(f32);

    const a = Vec3(f32).init(1.0, 2.0, 3.0);
    const b = a.normalize();
    testing.expect(std.math.approxEqAbs(f32, b.length(), 1.0, eps_value));

    const c = Vec4(f32).init(1.0, 2.0, 3.0, 4.0);
    const d = c.normalize();
    testing.expect(std.math.approxEqAbs(f32, d.length(), 1.0, eps_value));
}

test "matrix: identity" {
    const identity = Mat4(f32).identity();
    testing.expect(identity.m00() == 1.0);
    testing.expect(identity.m01() == 0.0);
    testing.expect(identity.m02() == 0.0);
    testing.expect(identity.m03() == 0.0);
    testing.expect(identity.m10() == 0.0);
    testing.expect(identity.m11() == 1.0);
    testing.expect(identity.m12() == 0.0);
    testing.expect(identity.m13() == 0.0);
    testing.expect(identity.m20() == 0.0);
    testing.expect(identity.m21() == 0.0);
    testing.expect(identity.m22() == 1.0);
    testing.expect(identity.m23() == 0.0);
    testing.expect(identity.m30() == 0.0);
    testing.expect(identity.m31() == 0.0);
    testing.expect(identity.m32() == 0.0);
    testing.expect(identity.m33() == 1.0);

    const a = Vec4(f32).init(1.0, 2.0, 3.0, 4.0);
    const b = identity.mul_vec4(a);
    testing.expect(a.x == b.x);
    testing.expect(a.y == b.y);
    testing.expect(a.z == b.z);
    testing.expect(a.w == b.w);
}

test "translation matrix" {
    const position = Vec3(f32).init(1.0, 2.0, 3.0);
    const translation_matrix = Mat4(f32).translate(position);

    testing.expect(translation_matrix.m00() == 1.0);
    testing.expect(translation_matrix.m01() == 0.0);
    testing.expect(translation_matrix.m02() == 0.0);
    testing.expect(translation_matrix.m03() == 0.0);
    testing.expect(translation_matrix.m10() == 0.0);
    testing.expect(translation_matrix.m11() == 1.0);
    testing.expect(translation_matrix.m12() == 0.0);
    testing.expect(translation_matrix.m13() == 0.0);
    testing.expect(translation_matrix.m20() == 0.0);
    testing.expect(translation_matrix.m21() == 0.0);
    testing.expect(translation_matrix.m22() == 1.0);
    testing.expect(translation_matrix.m23() == 0.0);
    testing.expect(translation_matrix.m30() == 1.0);
    testing.expect(translation_matrix.m31() == 2.0);
    testing.expect(translation_matrix.m32() == 3.0);
    testing.expect(translation_matrix.m33() == 1.0);
}