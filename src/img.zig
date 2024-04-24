const zstbi = @import("zstbi");
const ZstbImage = zstbi.Image;
const std = @import("std");
const clamp = std.math.clamp;
const Vec3 = @import("vec3.zig").Vec3;

const Self = @This();
const BYTES_PER_PIXEL = 3;

pub fn pixelData(img: *const ZstbImage, x: usize, y: usize) Vec3 {
    const new_x = clamp(x, 0, img.width - 1);
    const new_y = clamp(y, 0, img.height - 1);
    const start = (new_y * img.bytes_per_row) + (new_x * BYTES_PER_PIXEL);
    return @as(Vec3, @floatFromInt(@Vector(3, u8){img.data[start], img.data[start+1], img.data[start+2]}));
}