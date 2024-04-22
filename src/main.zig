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
const rand = util.random;
const Bvh = @import("bvh.zig");

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
    try world.add(Sphere.new(Vec3{0.0, 1.0, 0.0}, null, 1.0, mat1));
    const mat2 = try Material.init(Lambertian{ .albedo = Vec3{0.4, 0.2, 0.1}}, gpa);
    try world.add(Sphere.new(Vec3{-4.0, 1.0, 0.0}, null, 1.0, mat2));
    const mat3 = try Material.init(
        Metal{ 
            .albedo = Vec3{0.7, 0.6, 0.5},
            .fuzz = 0.0,
        },
        gpa
    );
    try world.add(Sphere.new(Vec3{4.0, 1.0, 0.0}, null, 1.0, mat3));
    const mat_ground = try Material.init(Lambertian{ .albedo = Vec3{0.5, 0.5, 0.5}}, gpa);
    try world.add(Sphere.new(Vec3{ 0.0, -1000.0, -1.0 }, null, 1000.0, mat_ground));

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
                try world.add(Sphere.new(
                    center,
                    Vec3{0.0, util.randRange(0.0, 0.5), 0.0},
                    0.2,
                    mat,
                ));
            }
        }
    }

    const hittable = try Hittable.init(try Bvh.new(world), gpa);
    defer hittable.deinit();
    //const hittable = try Hittable.init(world, gpa);

    // Camera
    var camera = Camera{
        .aspect_ratio = 16.0 / 9.0,
        .img_width = 400,
        .samples_per_pixel = 100,
        .max_depth = 50.0,
        .vfov = 20.0,
        .look_from = Vec3{13.0, 2.0, 3.0},
        .look_at = Vec3{0.0, 0.0, 0.0},
        .vup = Vec3{0.0, 1.0, 0.0},
        .defocus_angle = 0.6,
        .focus_dist = 10.0,
    };

    try camera.render(hittable, stdout);

    try bw.flush(); // don't forget to flush!
}

test "test_deinit" {
    const ta = std.testing.allocator;

    @import("util.zig").init();
    const Writer = struct {
        pub fn print(_: @This(), _: []const u8, _: anytype) !void {}
    };


    // World
    var world = HittableList.init(ta);

    const mat1 = try Material.init(Dielectric{.refraction_idx = 1.50}, ta);
    try world.add(Sphere.new(Vec3{0.0, 1.0, 0.0}, null, 1.0, mat1));
    const mat2 = try Material.init(Lambertian{ .albedo = Vec3{0.4, 0.2, 0.1}}, ta);
    try world.add(Sphere.new(Vec3{-4.0, 1.0, 0.0}, null, 1.0, mat2));
    const mat3 = try Material.init(
        Metal{ 
            .albedo = Vec3{0.7, 0.6, 0.5},
            .fuzz = 0.0,
        },
        ta
    );
    try world.add(Sphere.new(Vec3{4.0, 1.0, 0.0}, null, 1.0, mat3));
    const mat_ground = try Material.init(Lambertian{ .albedo = Vec3{0.5, 0.5, 0.5}}, ta);
    try world.add(Sphere.new(Vec3{ 0.0, -1000.0, -1.0 }, null, 1000.0, mat_ground));

    var a: f64 = -4.0;
    while (a < 4.0) : (a += 1.0) {
        var b: f64 = -4.0;
        while (b < 4.0) : (b += 1.0) {
            const choose_mat = rand();
            const center = Vec3{ a + 0.9 * rand(), 0.2, b + 0.9 * rand()};
            if (vec3.length(center - Vec3{4.0, 0.2, 0.0}) > 0.9) {
                const mat = if (choose_mat < 0.8) try Material.init(
                    Lambertian{ .albedo = vec3.random() * vec3.random()}, ta)
                else if (choose_mat < 0.95) try Material.init(
                    Metal{
                        .albedo = vec3.randomRange(0.5, 1.0), 
                        .fuzz = util.randRange(0.0, 0.5),
                    },
                    ta,
                ) else try Material.init(Dielectric{ .refraction_idx = 1.5 }, ta);
                try world.add(Sphere.new(
                    center,
                    Vec3{0.0, util.randRange(0.0, 0.5), 0.0},
                    0.2,
                    mat,
                ));
            }
        }
    }
    
    const hittable = try Hittable.init(world, ta);
    defer Hittable.deinit(hittable);

    // Camera
    var camera = Camera{
        .aspect_ratio = 16.0 / 9.0,
        .img_width = 40,
        .samples_per_pixel = 5,
        .max_depth = 10.0,
        .vfov = 20.0,
        .look_from = Vec3{13.0, 2.0, 3.0},
        .look_at = Vec3{0.0, 0.0, 0.0},
        .vup = Vec3{0.0, 1.0, 0.0},
        .defocus_angle = 0.6,
        .focus_dist = 10.0,
    };

    try camera.render(hittable, Writer{});
    try std.testing.expectEqual(1, mat1.tagged_data_ptr.ref_count);
    try std.testing.expectEqual(1, mat2.tagged_data_ptr.ref_count);
    try std.testing.expectEqual(1, mat3.tagged_data_ptr.ref_count);
    try std.testing.expectEqual(1, mat_ground.tagged_data_ptr.ref_count);
}
