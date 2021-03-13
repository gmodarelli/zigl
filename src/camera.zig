const std = @import("std");
const za = @import("zalgebra");
const Vec3f = za.vec3;
const Mat4f = za.mat4;

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
        self.front = Vec3f.new(0, 0, -1);
        self.world_up = world_up;
        self.yaw = za.to_radians(yaw_degrees);
        self.pitch = za.to_radians(pitch_degrees);
        self.movement_speed = 2.5;
        self.mouse_sensitivity = 0.1;
        self.zoom = za.to_radians(@as(f32, 45.0));

        self.updateVectors();
    }

    pub fn getViewMatrix(self: *Camera) Mat4f {
        return Mat4f.look_at(self.position, self.position.add(self.front), self.up);
    }

    pub fn processMovement(self: *Camera, direction: CameraMovement, delta_time: f32) void {
        const velocity = self.movement_speed * delta_time;
        switch (direction) {
            CameraMovement.forward => self.position = self.position.add(self.front.scale(velocity)),
            CameraMovement.backward => self.position = self.position.sub(self.front.scale(velocity)),
            CameraMovement.left => self.position = self.position.sub(self.right.scale(velocity)),
            CameraMovement.right => self.position = self.position.add(self.right.scale(velocity)),
            CameraMovement.up => self.position = self.position.add(self.up.scale(velocity)),
            CameraMovement.down => self.position = self.position.sub(self.up.scale(velocity)),
        }
    }

    fn updateVectors(self: *Camera) void {
        var front: Vec3f = undefined;
        front.x = std.math.cos(self.yaw) * std.math.cos(self.pitch);
        front.y = std.math.sin(self.pitch);
        front.z = std.math.sin(self.yaw) * std.math.cos(self.pitch);
        self.front = front.norm();
        self.right = front.cross(self.world_up).norm();
        self.up = self.right.cross(self.front).norm();
    }
};
