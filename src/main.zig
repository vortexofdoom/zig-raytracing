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
const util = @import("util.zig");
const rand = util.rand;

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

    const mat1 = try Material.init(Dielectric{.refraction_idx = 1.50}, gpa);
    try world.add(Sphere{
        .center = Vec3{0.0, 1.0, 0.0},
        .radius = 1.0,
        .mat = mat1,
    });
    const mat2 = try Material.init(Lambertian{ .albedo = Vec3{0.4, 0.2, 0.1}}, gpa);
    try world.add(Sphere{
        .center = Vec3{-4.0, 1.0, 0.0},
        .radius = 1.0,
        .mat = mat2,
    });
    const mat3 = try Material.init(
        Metal{ 
            .albedo = Vec3{0.7, 0.6, 0.5},
            .fuzz = 0.0,
        },
        gpa
    );
    try world.add(Sphere{
        .center = Vec3{4.0, 1.0, 0.0},
        .radius = 1.0,
        .mat = mat3,
    });
    const mat_ground = try Material.init(Lambertian{ .albedo = Vec3{0.5, 0.5, 0.5}}, gpa);
    try world.add(Sphere{
        .center = Vec3{ 0.0, -100.5, -1 },
        .radius = 100.0,
        .mat = mat_ground,
    });

    var a: f64 = -11.0;
    while (a < 11.0) : (a += 1.0) {
        var b: f64 = -11.0;
        while (b < 11.0) : (b += 1.0) {
            const choose_mat = rand();
            const center = Vec3{ a + 0.9 * rand(), 0.2, b + 0.9 * rand()};
            if (vec3.length(center - Vec3{4.0, 0.2, 0.0}) > 0.9) {
                const mat = if (choose_mat < 0.8) try Material.init(
                    Lambertian{ .albedo = vec3.random() * vec3.random()}, gpa)
                else if (choose_mat < 0.95) try Material.init(
                    Metal{
                        .albedo = vec3.randomRange(0.5, 1.0), 
                        .fuzz = util.randRange(0.0, 0.5),
                    },
                    gpa,
                ) else try Material.init(Dielectric{ .refraction_idx = 1.5 }, gpa);
                try world.add(Sphere{
                    .center = center,
                    .radius = 0.2,
                    .mat = mat,
                });
            }
        }
    }
    
    var hittable = try Hittable.init(world, gpa);
    defer hittable.deinit();

    // Camera
    var camera = Camera{
        .aspect_ratio = 16.0 / 9.0,
        .img_width = 1200,
        .samples_per_pixel = 500,
        .max_depth = 50.0,
        .vfov = 20.0,
        .look_from = Vec3{13.0, 12.0, 3.0},
        .look_at = Vec3{0.0, 0.0, 0.0},
        .vup = Vec3{0.0, 1.0, 0.0},
        .defocus_angle = 0.6,
        .focus_dist = 10.0,
    };

    try camera.render(&hittable, stdout);

    try bw.flush(); // don't forget to flush!
}
