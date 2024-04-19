const std = @import("std");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const SimdV3 = vec3.SimdV3;
const Ray = @import("ray.zig").Ray;

fn writeColor(color: Vec3, writer: anytype) !void {
    const byte_colors = @trunc(color.toSimd() * @as(SimdV3, @splat(255.999)));
    try writer.print("{d} {d} {d}\n", .{byte_colors[0], byte_colors[1], byte_colors[2]});
}

fn rayColor(ray: *const Ray) Vec3 {
    const unit_dir = ray.dir.normalize();
    const a = 0.5 * (unit_dir.y + 1.0);
    return Vec3.fromSimd(@as(SimdV3, @splat(1.0 - a)) + @as(SimdV3, @splat(a)) * SimdV3{0.5, 0.7, 1.0});
}

pub fn main() !void {
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // Image
    const aspect_ratio = 16.0 / 9.0;
    const img_width = 400;

    // Calculate height and ensure that it's at least 1
    const img_height_raw: usize = @intFromFloat(@as(f64, img_width) / aspect_ratio);
    const img_height = if (img_height_raw == 0) 1 else img_height_raw;

    // Camera

    const focal_length = 1.0;
    const viewport_height = 2.0;
    const viewport_width = viewport_height * (@as(f64, img_width) / img_height);
    const camera_center = Vec3{};

    // Calculate horizontal and vertical viewport edges
    const viewport_u = Vec3.new(viewport_width, 0.0, 0.0);
    const viewport_v = Vec3.new(0.0, -viewport_height, 0.0);

    // Calculate delta vectors from pixel to pixel
    const pixel_delta_u = Vec3.fromSimd(viewport_u.toSimd() / @as(SimdV3, (@splat(img_width))));
    const pixel_delta_v = Vec3.fromSimd(viewport_v.toSimd() / @as(SimdV3, @splat(img_height)));

    // Calculate position of upper left pixel
    const viewport_upper_left = Vec3.fromSimd(camera_center.toSimd() - SimdV3{0.0, 0.0, focal_length} - viewport_u.scale(0.5).toSimd() - viewport_v.scale(0.5).toSimd());
    const pixel00_loc = Vec3.fromSimd(viewport_upper_left.toSimd() + @as(SimdV3, @splat(0.5)) * pixel_delta_u.toSimd() * pixel_delta_v.toSimd());

    // Render

    try stdout.print("P3\n{d} {d}\n255\n", .{img_width, img_height});

    for (0..img_height) |j| {
        std.log.info("\rScanlines remaining: {d} ", .{img_height - j});
        for (0..img_width) |i| {
            const pixel_center = pixel00_loc.toSimd() + (@as(SimdV3, @splat(@floatFromInt(i))) * pixel_delta_u.toSimd()) + (@as(SimdV3, @splat(@floatFromInt(j))) * pixel_delta_v.toSimd());
            const ray = Ray.new(camera_center, Vec3.fromSimd(pixel_center - camera_center.toSimd()));

            const color = rayColor(&ray);
            try writeColor(color, stdout);
        }
    }
    std.log.info("\rDone.            \n", .{});
    try bw.flush(); // don't forget to flush!
}
