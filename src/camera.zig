const std = @import("std");
const math = @import("math.zig");
const Mat4f = math.Mat4(f32);
const Vec3f = math.Vec3(f32);

pub const CameraMovement = enum(u8) {
    forward, backward, left, right, up, down
};

pub const Camera = struct {
    position: Vec3f,
    front: Vec3f,
    up: Vec3f,
    right: Vec3f,
    world_up: Vec3f,

    // Stored in radians
    yaw: f32,
    pitch: f32,

    movement_speed: f32,
    mouse_sensitivity: f32,
    zoom: f32,

    pub fn init(self: *Camera, position: Vec3f, world_up: Vec3f, yaw_degrees: f32, pitch_degrees: f32) void {
        self.front = Vec3f.init(0, 0, -1);
        self.world_up = world_up;
        self.yaw = math.toRadians(yaw_degrees);
        self.pitch = math.toRadians(pitch_degrees);
        self.movement_speed = 2.5;
        self.mouse_sensitivity = 0.1;
        self.zoom = math.toRadians(45.0);

        self.updateVectors();
    }

    pub fn getViewMatrix(self: *Camera) Mat4f {
        return Mat4f.lookAt(self.position, self.position.add(self.front), self.up);
    }

    pub fn processMovement(self: *Camera, direction: CameraMovement, delta_time: f32) void {
        const velocity = self.movement_speed * delta_time;
        switch (direction) {
            CameraMovement.forward => self.position = self.position.add(self.front.scale(velocity)),
            CameraMovement.backward => self.position = self.position.subtract(self.front.scale(velocity)),
            CameraMovement.left => self.position = self.position.subtract(self.right.scale(velocity)),
            CameraMovement.right => self.position = self.position.add(self.right.scale(velocity)),
            CameraMovement.up => self.position = self.position.add(self.up.scale(velocity)),
            CameraMovement.down => self.position = self.position.subtract(self.up.scale(velocity)),
        }
    }

    fn updateVectors(self: *Camera) void {
        var front: Vec3f = undefined;
        front.x = std.math.cos(self.yaw) * std.math.cos(self.pitch);
        front.y = std.math.sin(self.pitch);
        front.z = std.math.sin(self.yaw) * std.math.cos(self.pitch);
        self.front = front.normalize();
        self.right = front.cross(self.world_up).normalize();
        self.up = self.right.cross(self.front).normalize();
    }
};
