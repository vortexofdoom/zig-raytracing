const std = @import("std");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const vec3s = vec3.vec3s;
const Ray = @import("ray.zig").Ray;
const hit = @import("hit.zig");
const Hittable = hit.Hittable;
const HitRecord = hit.HitRecord;
const HittableList = hit.HittableList;
const Rc = @import("rc.zig").RefCounted;
const Sphere = @import("sphere.zig");
const Interval = @import("interval.zig");
const Camera = @import("camera.zig");

const inf = std.math.inf(f64);
const pi = std.math.pi;
const white = vec3s(1.0);

var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
pub const gpa = gpa_impl.allocator();

pub fn main() !void {
    @import("util.zig").init();
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // World
    var world = HittableList.init(gpa);
    try world.add(Sphere{
        .center = Vec3{ 0.0, 0.0, -1.0 },
        .radius = 0.5,
    });
    try world.add(Sphere{
        .center = Vec3{ 0.0, -100.5, -1 },
        .radius = 100.0,
    });
    const hittable = try Hittable.init(world, gpa);
    defer hittable.deinit();

    // Camera
    var camera = Camera{};
    camera.aspect_ratio = 16.0 / 9.0;
    camera.img_width = 400;
    camera.samples_per_pixel = 100;
    try camera.render(&hittable, stdout);

    try bw.flush(); // don't forget to flush!
}
