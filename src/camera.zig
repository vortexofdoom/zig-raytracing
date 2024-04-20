const std = @import("std");
const Ray = @import("ray.zig");
const Hittable = @import("hit.zig").Hittable;
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const normalize = vec3.normalize;
const vec3s = vec3.vec3s;
const white = vec3s(1.0);
const Interval = @import("interval.zig");
const inf = std.math.inf(f64);

aspect_ratio: f64 = 1.0,
img_width: usize = 100,
img_height: usize = undefined,
center: Vec3 = undefined,
pixel00_loc: Vec3 = undefined,
pixel_delta_u: Vec3 = undefined,
pixel_delta_v: Vec3 = undefined,

const Self = @This();

fn writeColor(color: Vec3, writer: anytype) !void {
    const byte_colors = @trunc(color * vec3s(255.999));
    try writer.print("{d} {d} {d}\n", .{ byte_colors[0], byte_colors[1], byte_colors[2] });
}

pub fn render(self: *Self, obj: *const Hittable, writer: anytype) !void {
    try writer.print("P3\n{d} {d}\n255\n", .{ self.img_width, self.img_height });

    for (0..self.img_height) |j| {
        std.log.info("\rScanlines remaining: {d} ", .{self.img_height - j});
        for (0..self.img_width) |i| {
            const jvec: Vec3 = vec3s(@floatFromInt(j));
            const ivec: Vec3 = vec3s(@floatFromInt(i));
            const pixel_center = self.pixel00_loc + (ivec * self.pixel_delta_u) + (jvec * self.pixel_delta_v);
            const ray = Ray.new(self.center, pixel_center - self.center);

            const color = rayColor(&ray, obj);
            try writeColor(color, writer);
        }
    }
    std.log.info("\rDone.            \n", .{});
}

pub fn rayColor(ray: *const Ray, obj: *const Hittable) Vec3 {
    if (obj.hit(ray, Interval.new(0, inf))) |rec| {
        return vec3s(0.5) * (rec.normal + white);
    }

    const a = 0.5 * (normalize(ray.dir)[1] + 1.0);
    return vec3s(1.0 - a) + vec3s(a) * Vec3{ 0.5, 0.7, 1.0 };
}

pub fn init() Self {
    var self = Self{};
    const img_width_f: f64 = @floatFromInt(self.img_width);
    // Calculate height and ensure that it's at least 1
    self.img_height = @intFromFloat(img_width_f / self.aspect_ratio);
    self.img_height = if (self.img_height == 0) 1 else self.img_height;
    const img_height_f: f64 = @floatFromInt(self.img_height);

    const focal_length = 1.0;
    const viewport_height = 2.0;
    const viewport_width = viewport_height * (img_width_f / img_height_f);

    self.center = vec3s(0.0);
    // Calculate horizontal and vertical viewport edges
    const viewport_u = Vec3{ viewport_width, 0.0, 0.0 };
    const viewport_v = Vec3{ 0.0, -viewport_height, 0.0 };

    // Calculate delta vectors from pixel to pixel
    self.pixel_delta_u = viewport_u / vec3s(img_width_f);
    self.pixel_delta_v = viewport_v / vec3s(img_height_f);

    // Calculate position of upper left pixel
    const viewport_upper_left = self.center - Vec3{ 0.0, 0.0, focal_length } - viewport_u * vec3s(0.5) - viewport_v * vec3s(0.5);
    self.pixel00_loc = viewport_upper_left + vec3s(0.5) * (self.pixel_delta_u + self.pixel_delta_v);
    return self;
}
