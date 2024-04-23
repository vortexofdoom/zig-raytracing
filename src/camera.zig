const std = @import("std");
const Ray = @import("ray.zig");
const Hittable = @import("hit.zig").Hittable;
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const normalize = vec3.normalize;
const vec3s = vec3.vec3s;
const white = vec3s(1.0);
const Interval = @import("interval.zig");
const util = @import("util.zig");
const inf = util.inf;
const rand = util.random;
const Rc = @import("rc.zig").RefCounted;

/// Ratio of image width to height
aspect_ratio: f64 = 1.0,
/// Rendered image width in pixels
img_width: usize = 100,
/// Count of random samples for each pixel
samples_per_pixel: usize = 10,
/// Color scale factor for sum of pixel samples
pixel_samples_scale: f64 = undefined,
/// Rendered image height in pixels
img_height: usize = undefined,
/// Camera center
center: Vec3 = undefined,
/// Location of pixel 0, 0 (top-left)
pixel00_loc: Vec3 = undefined,
/// Offset of each pixel to its right neighbor
pixel_delta_u: Vec3 = undefined,
/// Offset of each pixel to its neighbor below
pixel_delta_v: Vec3 = undefined,
/// Maximum number of bounces per ray
max_depth: usize = 10,
/// Vertical view angle
vfov: f64 = 90.0,
look_from: Vec3,
look_at: Vec3,
/// Camera-relative up
vup: Vec3,
/// Variation angle of rays through each pixel
defocus_angle: f64 = 0.0,
/// Distance from `look_from` to plane of perfect focus
focus_dist: f64 = 10.0,
/// Defocus disc horizontal radius
defocus_disc_u: Vec3 = undefined,
/// Defocus disc vertical radius
defocus_disc_v: Vec3 = undefined,

const Self = @This();

fn writeColor(color: Vec3, writer: anytype) !void {
    const gamma = @sqrt(@max(vec3s(0.0), color));
    const clamp = @min(vec3s(0.999), gamma);
    const byte_colors = @trunc(clamp * vec3s(256.0));
    try writer.print("{d} {d} {d}\n", .{ byte_colors[0], byte_colors[1], byte_colors[2] });
}

pub fn render(self: *Self, obj: Hittable, writer: anytype) !void {
    self.init();

    try writer.print("P3\n{d} {d}\n255\n", .{ self.img_width, self.img_height });

    for (0..self.img_height) |j| {
        std.log.info("\rScanlines remaining: {d} ", .{self.img_height - j});
        for (0..self.img_width) |i| {
            var pixel_color = vec3s(0.0);
            for (0..self.samples_per_pixel) |_| {
                const ray = self.getRay(i, j);
                pixel_color += rayColor(ray, self.max_depth, obj);
            }
            try writeColor(pixel_color * vec3s(self.pixel_samples_scale), writer);
        }
    }
    std.log.info("\rDone.            \n", .{});
}

fn sampleSquare() Vec3 {
    return Vec3{ rand() - 0.5, rand() - 0.5, 0.0 };
}

inline fn linearToGamma(linear: f64) f64 {
    return if (linear > 0.0) @sqrt(linear) else 0.0;
}

fn getRay(self: *const Self, i: usize, j: usize) Ray {
    const offset = Vec3{ @floatFromInt(i), @floatFromInt(j), 0.0 } + sampleSquare();
    const pixel_sample = self.pixel00_loc 
        + vec3.swizzle(offset, .x, .x, .x) * self.pixel_delta_u
        + vec3.swizzle(offset, .y, .y, .y) * self.pixel_delta_v;
    const origin = if (self.defocus_angle <= 0) self.center else self.defocusDiscSample();
    return Ray{
        .origin = origin,
        .dir = pixel_sample - origin,
        .time = rand(),
    };
}

fn defocusDiscSample(self: *const Self) Vec3 {
    const p = vec3.randomInUnitDisc();
    return self.center 
    + (vec3.swizzle(p, .x, .x, .x) * self.defocus_disc_u) 
    + (vec3.swizzle(p, .y, .y, .y) * self.defocus_disc_v);
}

pub fn rayColor(ray: Ray, depth: usize, obj: Hittable) Vec3 {
    if (depth == 0) return vec3s(0.0);
    if (obj.hit(ray, Interval.new(0.001, inf))) |rec| {
        if (rec.mat.scatter(ray, rec)) |s| {
            return s.attenuation * rayColor(s.ray, depth - 1, obj);
        }
        return vec3s(0.0);
    }

    const a = 0.5 * (normalize(ray.dir)[1] + 1.0);
    return vec3s(1.0 - a) + vec3s(a) * Vec3{ 0.5, 0.7, 1.0 };
}

pub fn init(self: *Self) void {
    const img_width_f: f64 = @floatFromInt(self.img_width);
    // Calculate height and ensure that it's at least 1
    self.img_height = @intFromFloat(img_width_f / self.aspect_ratio);
    self.img_height = if (self.img_height == 0) 1 else self.img_height;
    const img_height_f: f64 = @floatFromInt(self.img_height);
    self.pixel_samples_scale = 1.0 / @as(f64, @floatFromInt(self.samples_per_pixel));

    self.center = self.look_from;

    const theta = std.math.degreesToRadians(self.vfov);
    const h = @tan(theta / 2);
    const viewport_height = 2.0 * h * self.focus_dist;
    const viewport_width = viewport_height * (img_width_f / img_height_f);

    const w = normalize(self.look_from - self.look_at);
    const u = normalize(vec3.cross(self.vup, w));
    const v = vec3.cross(w, u);

    // Calculate horizontal and vertical viewport edges
    const viewport_u = vec3s(viewport_width) * u;
    const viewport_v = vec3s(viewport_height) * -v;

    // Calculate delta vectors from pixel to pixel
    self.pixel_delta_u = viewport_u / vec3s(img_width_f);
    self.pixel_delta_v = viewport_v / vec3s(img_height_f);

    // Calculate position of upper left pixel
    const viewport_upper_left = self.center - (vec3s(self.focus_dist) * w) - (viewport_u / vec3s(2.0)) - (viewport_v / vec3s(2.0));
    self.pixel00_loc = viewport_upper_left + vec3s(0.5) * (self.pixel_delta_u + self.pixel_delta_v);

    const defocus_radius = self.focus_dist * @tan(std.math.degreesToRadians(self.defocus_angle / 2.0));
    self.defocus_disc_u = u * vec3s(defocus_radius);
    self.defocus_disc_v = v * vec3s(defocus_radius);
}
