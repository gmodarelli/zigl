const c = @import("c.zig");
const std = @import("std");

pub const PngImage = struct {
    width: u32,
    height: u32,
    pitch: u32,
    raw: []u8,

    pub fn destroy(png: *PngImage) void {
        c.stbi_image_free(png.raw.ptr);
    }

    pub fn create(compressed_bytes: []const u8) !PngImage {
        var png: PngImage = undefined;

        var width: c_int = undefined;
        var height: c_int = undefined;
        var components: c_int = undefined;

        if (c.stbi_info_from_memory(compressed_bytes.ptr, @intCast(c_int, compressed_bytes.len), &width, &height, &components) == 0) {
            return error.NoPngFile;
        }

        if (width <= 0 or height <= 0) return error.NoPixels;
        png.width = @intCast(u32, width);
        png.height = @intCast(u32, height);

        if (c.stbi_is_16_bit_from_memory(compressed_bytes.ptr, @intCast(c_int, compressed_bytes.len)) != 0) {
            return error.InvalidFormat;
        }

        const bits_per_channel = 8;
        const desired_channels = 4;
        var channels_in_file: c_int = undefined;

        c.stbi_set_flip_vertically_on_load(1);
        const image_data = c.stbi_load_from_memory(compressed_bytes.ptr, @intCast(c_int, compressed_bytes.len), &width, &height, &channels_in_file, desired_channels);

        if (image_data == null) return error.NoMem;

        png.pitch = png.width * desired_channels / bits_per_channel;
        png.raw = image_data[0 .. png.height * png.pitch];

        return png;
    }
};
