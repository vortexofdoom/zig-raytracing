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
const texture = @import("texture.zig");
const Texture = texture.Texture;
const Solid = texture.Solid;
const Checker = texture.Checker;
const Noise = texture.Noise;
const Perlin = @import("perlin.zig");
const ImageTex = texture.ImageTex;
const zstbi = @import("zstbi");
const Image = zstbi.Image;
const Quad = @import("quad.zig");

const inf = std.math.inf(f64);
const pi = std.math.pi;
const white = vec3s(1.0);

var gpa_impl = std.heap.GeneralPurposeAllocator(.{}){};
pub const gpa = gpa_impl.allocator();

pub fn main() !void {
    @import("util.zig").init();
    zstbi.init(gpa);
    defer zstbi.deinit();
    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    // Camera
    var camera = Camera{
        .aspect_ratio = 16.0 / 9.0,
        .img_width = 400,
        .samples_per_pixel = 100,
        .max_depth = 50,
        .vfov = 20.0,
        .look_from = Vec3{13.0, 2.0, 3.0},
        .look_at = Vec3{0.0, 0.0, 0.0},
        .vup = Vec3{0.0, 1.0, 0.0},
        .defocus_angle = 0.6,
        .focus_dist = 10.0,
    };
    try switch (4) {
        0 => bouncingSpheres(-11.0, 11.0, gpa, stdout, &camera),
        1 => checkeredSpheres(gpa, stdout, &camera),
        2 => earth(gpa, stdout, &camera),
        3 => perlin(gpa, stdout, &camera),
        4 => quads(gpa, stdout, &camera),
        else => unreachable
    };
    try bw.flush(); // don't forget to flush!
}

pub fn quads(alloc: std.mem.Allocator, writer: anytype, camera: *Camera) !void {
    var world = HittableList.init(alloc);

    const left_red = try Material.init(Lambertian{ .tex = try Texture.init( Solid{.albedo = Vec3{ 1.0, 0.2, 0.2 }}, alloc)}, alloc);
    const back_green = try Material.init(Lambertian{ .tex = try Texture.init( Solid{.albedo = Vec3{ 0.2, 1.0, 0.2 }}, alloc)}, alloc);
    const right_blue = try Material.init(Lambertian{ .tex = try Texture.init( Solid{.albedo = Vec3{ 0.2, 0.2, 1.0 }}, alloc)}, alloc);
    const upper_orange = try Material.init(Lambertian{ .tex = try Texture.init( Solid{.albedo = Vec3{ 1.0, 0.5, 0.0 }}, alloc)}, alloc);
    const lower_teal = try Material.init(Lambertian{ .tex = try Texture.init( Solid{.albedo = Vec3{ 0.2, 0.8, 0.8 }}, alloc)}, alloc);

    try world.add(Quad.init(Vec3{-3.0, -2.0, 5.0}, Vec3{0.0, 0.0, -4.0}, Vec3{0.0, 4.0, 0.0}, left_red));
    try world.add(Quad.init(Vec3{-2.0, -2.0, 0.0}, Vec3{4.0, 0.0, 0.0}, Vec3{0.0, 4.0, 0.0}, back_green));
    try world.add(Quad.init(Vec3{3.0, -2.0, 1.0}, Vec3{0.0, 0.0, 4.0}, Vec3{0.0, 4.0, 0.0}, right_blue));
    try world.add(Quad.init(Vec3{-2.0, 3.0, 1.0}, Vec3{4.0, 0.0, 0.0}, Vec3{0.0, 0.0, 4.0}, upper_orange));
    try world.add(Quad.init(Vec3{-2.0, -3.0, 5.0}, Vec3{4.0, 0.0, 0.0}, Vec3{0.0, 0.0, -4.0}, lower_teal));
    
    const hittable = try Hittable.init(world, alloc);
    defer hittable.deinit();
    camera.look_from = Vec3{0.0, 0.0, 9.0};
    camera.look_at = vec3s(0.0);
    camera.defocus_angle = 0.0;
    camera.vfov = 80.0;
    camera.aspect_ratio = 1.0;
    try camera.render(hittable, writer);
}

pub fn perlin(alloc: std.mem.Allocator, writer: anytype, camera: *Camera) !void {
    const perl = try Material.init(Lambertian{ .tex = try Texture.init(Noise{ .noise = try Perlin.init(alloc), .scale = 4.0}, alloc)}, alloc);
    var world = HittableList.init(alloc);
    try world.add(Sphere.new(Vec3{0.0, -1000.0, 0.0}, null, 1000.0, perl));
    try world.add(Sphere.new(Vec3{0.0, 2.0, 0.0}, null, 2.0, perl));
    const hittable = try Hittable.init(world, alloc);
    defer hittable.deinit();
    try camera.render(hittable, writer);
}

pub fn earth(alloc: std.mem.Allocator, writer: anytype, camera: *Camera) !void {
    camera.look_from = Vec3{0.0, 0.0, 12.0};
    const img = try Image.loadFromFile("earthmap.jpg", 0);
    const earth_tex = try Texture.init(ImageTex{ .img = img }, alloc);
    const surface = try Material.init(Lambertian{ .tex = earth_tex }, alloc);
    const globe = try Hittable.init(Sphere.new(Vec3{0.0, 0.0, 0.0}, null, 2.0, surface), alloc);
    defer globe.deinit();
    try camera.render(globe, writer);
}

pub fn checkeredSpheres(alloc: std.mem.Allocator, writer: anytype, camera: *Camera) !void {
    var world = HittableList.init(alloc);
    const checker = try Material.init(Lambertian { .tex = try Texture.init(try Checker.initColor(0.32, Vec3{0.2, 0.3, 0.1}, Vec3{0.9, 0.9, 0.9}, alloc), alloc) }, alloc);
    try world.add(try Hittable.init(Sphere.new(Vec3{0.0, -10.0, 0.0}, null, 10.0, checker), alloc));
    try world.add(try Hittable.init(Sphere.new(Vec3{0.0, 10.0, 0.0}, null, 10.0, checker.strongRef()), alloc));
    const hittable = try Hittable.init(world, alloc);
    defer hittable.deinit();
    try camera.render(hittable, writer);
}

pub fn bouncingSpheres(lo: f64, hi: f64, alloc: std.mem.Allocator, writer: anytype, camera: *Camera) !void {
    // World
    var world = HittableList.init(alloc);
    const mat1 = try Material.init(Dielectric{.refraction_idx = 1.50}, alloc);
    try world.add(Sphere.new(Vec3{0.0, 1.0, 0.0}, null, 1.0, mat1));
    const mat2 = try Material.init(Lambertian{ .tex = try Texture.init(Solid{.albedo =  Vec3{0.4, 0.2, 0.1}}, alloc)}, alloc);
    try world.add(Sphere.new(Vec3{-4.0, 1.0, 0.0}, null, 1.0, mat2));
    const mat3 = try Material.init(
        Metal{ 
            .albedo = Vec3{0.7, 0.6, 0.5},
            .fuzz = 0.0,
        },
        alloc
    );
    try world.add(Sphere.new(Vec3{4.0, 1.0, 0.0}, null, 1.0, mat3));
    //const mat_ground = try Material.init(Lambertian{ .albedo = Vec3{0.5, 0.5, 0.5}}, gpa);
    const checker = try texture.Texture.init(try texture.Checker.initColor(0.32, Vec3{0.2, 0.3, 0.1}, Vec3{0.9, 0.9, 0.9}, alloc), alloc);
    try world.add(Sphere.new(Vec3{ 0.0, -1000.0, -1.0 }, null, 1000.0, try Material.init(Lambertian { .tex = try Texture.init(checker, alloc) }, alloc)));

    var a = lo;
    while (a < hi) : (a += 1.0) {
        var b = lo;
        while (b < hi) : (b += 1.0) {
            const choose_mat = rand();
            const center = Vec3{ a + 0.9 * rand(), 0.2, b + 0.9 * rand()};
            if (vec3.length(center - Vec3{4.0, 0.2, 0.0}) > 0.9) {
                const mat = if (choose_mat < 0.8) try Material.init(
                    Lambertian{ 
                        .tex = try Texture.init(Solid{ .albedo = vec3.random() * vec3.random()}, 
                        alloc)
                    },
                    alloc,
                )
                else if (choose_mat < 0.95) try Material.init(
                    Metal{
                        .albedo = vec3.randomRange(0.5, 1.0), 
                        .fuzz = util.randRange(0.0, 0.5),
                    },
                    alloc,
                ) else try Material.init(Dielectric{ .refraction_idx = 1.5 }, alloc);
                try world.add(Sphere.new(
                    center,
                    Vec3{0.0, util.randRange(0.0, 0.5), 0.0},
                    0.2,
                    mat,
                ));
            }
        }
    }

    const hittable = try Hittable.init(try Bvh.new(&world), alloc);
    defer hittable.deinit();
    //const hittable = try Hittable.init(world, gpa);

    try camera.render(hittable, writer);
}

test "test_deinit" {
    const ta = std.testing.allocator;
    zstbi.init(ta);
    defer zstbi.deinit();

    @import("util.zig").init();
    const Writer = struct {
        pub fn print(_: @This(), _: []const u8, _: anytype) !void {}
    };

    // Camera
    var camera = Camera{
        .aspect_ratio = 16.0 / 9.0,
        .img_width = 40,
        .samples_per_pixel = 10,
        .max_depth = 10,
        .vfov = 20.0,
        .look_from = Vec3{13.0, 2.0, 3.0},
        .look_at = Vec3{0.0, 0.0, 0.0},
        .vup = Vec3{0.0, 1.0, 0.0},
        .defocus_angle = 0.6,
        .focus_dist = 10.0,
    };

    try bouncingSpheres(-4.0, 4.0, ta, Writer{}, &camera);
    try checkeredSpheres(ta, Writer{}, &camera);
    try earth(ta, Writer{}, &camera);
    try perlin(ta, Writer{}, &camera);
    try quads(ta, Writer{}, &camera);
}
