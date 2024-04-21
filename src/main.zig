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
const material = @import("material.zig");
const Material = material.Material;
const Lambertian = material.Lambertian;
const Metal = material.Metal;
const Dielectric = material.Dielectric;

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

    const mat_ground = try Material.init(Lambertian{ .albedo = Vec3{0.8, 0.8, 0.0}}, gpa);
const mat_center = try Material.init(Lambertian{ .albedo = Vec3{0.1, 0.2, 0.5}}, gpa);
    const mat_left = try Material.init(
        Dielectric{.refraction_idx = 1.50},
        gpa
    );
    const mat_bubble = try Material.init(
        Dielectric{.refraction_idx = 1.00 / 1.50},
        gpa
    );
    const mat_right = try Material.init(
        Metal{ 
            .albedo = Vec3{0.8, 0.6, 0.2},
            .fuzz = 1.0,
        },
        gpa
    );

    // World
    var world = HittableList.init(gpa);
    try world.add(Sphere{
        .center = Vec3{ 0.0, 0.0, -1.2 },
        .radius = 0.5,
        .mat = mat_center,
    });
    try world.add(Sphere{
        .center = Vec3{ -1.0, 0.0, -1.0 },
        .radius = 0.5,
        .mat = mat_left,
    });
    try world.add(Sphere{
        .center = Vec3{ -1.0, 0.0, -1.0 },
        .radius = 0.4,
        .mat = mat_bubble,
    });
    try world.add(Sphere{
        .center = Vec3{ 1.0, 0.0, -1.0 },
        .radius = 0.5,
        .mat = mat_right,
    });
try world.add(Sphere{
        .center = Vec3{ 0.0, -100.5, -1 },
        .radius = 100.0,
        .mat = mat_ground,
    });
    var hittable = try Hittable.init(world, gpa);
    defer hittable.deinit();

    // Camera
    var camera = Camera{
        .aspect_ratio = 16.0 / 9.0,
        .img_width = 400,
        .samples_per_pixel = 100,
        .max_depth = 50.0,
        .vfov = 20.0,
        .look_from = Vec3{-2.0, 2.0, 1.0},
        .look_at = Vec3{0.0, 0.0, -1.0},
        .vup = Vec3{0.0, 1.0, 0.0},
    };

    try camera.render(&hittable, stdout);

    try bw.flush(); // don't forget to flush!
}
