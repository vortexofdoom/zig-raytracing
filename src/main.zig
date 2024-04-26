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
const DiffuseLight = material.DiffuseLight;
const Transform = @import("transform.zig");
const ConstantMedium = @import("volume.zig").Constant;

const inf = std.math.inf(f64);
const pi = std.math.pi;

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
    try switch (6) {
        0 => bouncingSpheres(-11.0, 11.0, gpa, stdout, &camera),
        1 => checkeredSpheres(gpa, stdout, &camera),
        2 => earth(gpa, stdout, &camera),
        3 => perlin(gpa, stdout, &camera),
        4 => quads(gpa, stdout, &camera),
        5 => simpleLight(gpa, stdout, &camera),
        6 => edit: {
            camera.aspect_ratio = 1.0;
            camera.vfov = 40.0;
            camera.img_width = 600;
            camera.samples_per_pixel = 200;
            camera.bg_color = vec3.zero;
            camera.look_from = Vec3{278.0, 278.0, -800.0};
            camera.look_at = Vec3{278.0, 278.0, 0.0};
            camera.defocus_angle = 0.0;
            break :edit cornellBox(gpa, stdout, &camera);
        },
        7 => edit: {
            camera.aspect_ratio = 1.0;
            camera.vfov = 40.0;
            camera.img_width = 600;
            camera.samples_per_pixel = 200;
            camera.bg_color = vec3.zero;
            camera.look_from = Vec3{278.0, 278.0, -800.0};
            camera.look_at = Vec3{278.0, 278.0, 0.0};
            camera.defocus_angle = 0.0;
            break :edit cornellSmoke(gpa, stdout, &camera);
        },
        8 => edit: {
            camera.img_width = 800;
            camera.samples_per_pixel = 10000;
            camera.max_depth = 40;
            break :edit finalScene(gpa, stdout, &camera);
        },
        else => edit: {
            camera.img_width = 400;
            camera.samples_per_pixel = 250;
            camera.max_depth = 4;
            break :edit finalScene(gpa, stdout, &camera);
        },
    };
    try bw.flush(); // don't forget to flush!
}

pub fn finalScene(alloc: std.mem.Allocator, writer: anytype, camera: *Camera) !void {
    var boxes1 = HittableList.init(alloc);
    const ground = try Lambertian.initColor(Vec3{0.48, 0.83, 0.53}, alloc);
    defer ground.deinit();
    const boxes_per_side: usize = 20;
    for (0..boxes_per_side) |i| {
        for (0..boxes_per_side) |j| {
            const w = 100.0;
            const x0 = -1000.0 + @as(f64, @floatFromInt(i)) * w;
            const z0 = -1000.0 + @as(f64, @floatFromInt(j)) * w;
            const y0 = 0.0;
            const x1 = x0 + w;
            const y1 = util.randRange(1.0, 101.0);
            const z1 = z0 + w;
            try boxes1.add(try hit.box(Vec3{x0, y0, z0}, Vec3{x1, y1, z1}, ground.strongRef()));
        }
    }

    var world = HittableList.init(alloc);
    try world.add(try Bvh.new(&boxes1));

    const light = try DiffuseLight.init(vec3s(7.0), alloc);
    try world.add(Quad.init(Vec3{123.0, 554.0, 147.0}, Vec3{300.0, 0.0, 0.0}, Vec3{0.0, 0.0, 265.0}, light));

    try world.add(Sphere.new(Vec3{400.0, 400.0, 200.0}, Vec3{30.0, 0.0, 0.0}, 50, try Lambertian.initColor(Vec3{0.7, 0.3, 0.1}, alloc)));

    const dielectric = try Dielectric.init(1.5, alloc);

    try world.add(Sphere.new(Vec3{260.0, 150.0, 45.0}, null, 50.0, dielectric));

    try world.add(Sphere.new(Vec3{0.0, 150.0, 145.0}, null, 50.0, try Metal.init(Vec3{0.8, 0.8, 0.9}, 1.0, alloc)));

    var boundary = Sphere.new(Vec3{360.0, 150.0, 145.0}, null, 70.0, dielectric.strongRef());
    try world.add(boundary);
    try world.add(try ConstantMedium.init(world.list.getLast().strongRef(), 0.2, Vec3{0.2, 0.4, 0.9}));
    boundary = Sphere.new(vec3.zero, null, 5000.0, dielectric.strongRef());
    try world.add(try ConstantMedium.init(try Hittable.init(boundary, alloc), 0.0001, vec3.unit));

    const earth_tex = try ImageTex.initFile("earthmap.jpg", alloc);
    try world.add(Sphere.new(Vec3{400.0, 200.0, 400.0}, null, 100.0, try Lambertian.init(earth_tex)));
    const perl_tex = try Noise.init(0.2, alloc);
    try world.add(Sphere.new(Vec3{220.0, 280.0, 300.0}, null, 80.0, try Lambertian.init(perl_tex)));

    var boxes2 = HittableList.init(alloc);
    const white = try Lambertian.initColor(vec3s(0.73), alloc);
    defer white.deinit();
    for (0..1000) |_| {
        try boxes2.add(Sphere.new(vec3.randomRange(0.0, 165.0), null, 10.0, white.strongRef()));
    }

    try world.add(Transform.init(try Hittable.init(try Bvh.new(&boxes2), alloc), 15.0, Vec3{-100.0, 270.0, 395.0}));

    camera.vfov = 40.0;
    camera.aspect_ratio = 1.0;
    camera.look_from = Vec3{478.0, 278.0, -600.0};
    camera.look_at = Vec3{278.0, 278.0, 0.0};
    camera.defocus_angle = 0.0;
    camera.bg_color = vec3.zero;

    const hittable = try Hittable.init(world, alloc);
    defer hittable.deinit();
    try camera.render(hittable, writer);
}

pub fn cornellSmoke(alloc: std.mem.Allocator, writer: anytype, camera: *Camera) !void {
    const red = try Lambertian.initColor(Vec3{0.65, 0.05, 0.05}, alloc);
    const white = try Lambertian.initColor(Vec3{0.73, 0.73, 0.73}, alloc);
    const green = try Lambertian.initColor(Vec3{0.12, 0.45, 0.15}, alloc);
    const light = try DiffuseLight.init(vec3s(15.0), alloc);

    var world = HittableList.init(alloc);
    try world.add(Quad.init(Vec3{555.0, 0.0, 0.0}, Vec3{0.0, 555.0, 0.0}, Vec3{0.0, 0.0, 555.0}, green));
    try world.add(Quad.init(Vec3{0.0, 0.0, 0.0}, Vec3{0.0, 555.0, 0.0}, Vec3{0.0, 0.0, 555.0}, red));
    try world.add(Quad.init(Vec3{343.0, 554.0, 332.0}, Vec3{-130.0, 0.0, 0.0}, Vec3{0.0, 0.0, -105.0}, light));
    try world.add(Quad.init(Vec3{0.0, 0.0, 0.0}, Vec3{555.0, 0.0, 0.0}, Vec3{0.0, 0.0, 555.0}, white));
    try world.add(Quad.init(Vec3{555.0, 555.0, 555.0}, Vec3{-555.0, 0.0, 0.0}, Vec3{0.0, 0.0, -555.0}, white.strongRef()));
    try world.add(Quad.init(Vec3{0.0, 0.0, 555.0}, Vec3{555.0, 0.0, 0.0}, Vec3{0.0, 555.0, 0.0}, white.strongRef()));


    const box1 = Transform.init(try hit.box(Vec3{0.0, 0.0, 0.0}, Vec3{165.0, 330.0, 165.0}, white.strongRef()), 15.0, Vec3{265.0, 0.0, 295.0});
    const box2 = Transform.init(try hit.box(Vec3{0.0, 0.0, 0.0}, Vec3{165.0, 165.0, 165.0}, white.strongRef()), -18.0, Vec3{130.0, 0.0, 65.0});

    try world.add(try ConstantMedium.init(try Hittable.init(box1, alloc), 0.01, vec3.zero));
    try world.add(try ConstantMedium.init(try Hittable.init(box2, alloc), 0.01, vec3.unit));

    const hittable = try Hittable.init(world, alloc);
    defer hittable.deinit();
    try camera.render(hittable, writer);
}

pub fn cornellBox(alloc: std.mem.Allocator, writer: anytype, camera: *Camera) !void {
    const red = try Lambertian.initColor(Vec3{0.65, 0.05, 0.05}, alloc);
    const white = try Lambertian.initColor(Vec3{0.73, 0.73, 0.73}, alloc);
    const green = try Lambertian.initColor(Vec3{0.12, 0.45, 0.15}, alloc);
    const light = try DiffuseLight.init(vec3s(15.0), alloc);

    var world = HittableList.init(alloc);
    try world.add(Quad.init(Vec3{555.0, 0.0, 0.0}, Vec3{0.0, 555.0, 0.0}, Vec3{0.0, 0.0, 555.0}, green));
    try world.add(Quad.init(Vec3{0.0, 0.0, 0.0}, Vec3{0.0, 555.0, 0.0}, Vec3{0.0, 0.0, 555.0}, red));
    try world.add(Quad.init(Vec3{343.0, 554.0, 332.0}, Vec3{-130.0, 0.0, 0.0}, Vec3{0.0, 0.0, -105.0}, light));
    try world.add(Quad.init(Vec3{0.0, 0.0, 0.0}, Vec3{555.0, 0.0, 0.0}, Vec3{0.0, 0.0, 555.0}, white));
    try world.add(Quad.init(Vec3{555.0, 555.0, 555.0}, Vec3{-555.0, 0.0, 0.0}, Vec3{0.0, 0.0, -555.0}, white.strongRef()));
    try world.add(Quad.init(Vec3{0.0, 0.0, 555.0}, Vec3{555.0, 0.0, 0.0}, Vec3{0.0, 555.0, 0.0}, white.strongRef()));


    const box1 = Transform.init(try hit.box(Vec3{0.0, 0.0, 0.0}, Vec3{165.0, 330.0, 165.0}, white.strongRef()), 15.0, Vec3{265.0, 0.0, 295.0});
    const box2 = Transform.init(try hit.box(Vec3{0.0, 0.0, 0.0}, Vec3{165.0, 165.0, 165.0}, white.strongRef()), -18.0, Vec3{130.0, 0.0, 65.0});

    try world.add(box1);
    try world.add(box2);

    const hittable = try Hittable.init(world, alloc);
    defer hittable.deinit();
    try camera.render(hittable, writer);
}

pub fn simpleLight(alloc: std.mem.Allocator, writer: anytype, camera: *Camera) !void {
    const perl = try Lambertian.init(try Noise.init(4.0, alloc));
    camera.look_from = Vec3{26.0, 3.0, 6.3};
    camera.look_at = Vec3{0.0, 2.0, 1.0};
    camera.bg_color = vec3s(0.0);
    var world = HittableList.init(alloc);
    try world.add(Sphere.new(Vec3{0.0, -1000.0, 0.0}, null, 1000.0, perl));
    try world.add(Sphere.new(Vec3{0.0, 2.0, 0.0}, null, 2.0, perl.strongRef()));

    const diff_light = try DiffuseLight.init(vec3s(4.0), alloc);
    try world.add(Quad.init(Vec3{3.0, 1.0, -2.0}, Vec3{2.0, 0.0, 0.0}, Vec3{0.0, 2.0, 0.0}, diff_light));
    try world.add(Sphere.new(Vec3{0.0, 7.0, 0.0}, null, 2.0, diff_light.strongRef()));
    const hittable = try Hittable.init(world, alloc);
    defer hittable.deinit();
    try camera.render(hittable, writer);
}

pub fn quads(alloc: std.mem.Allocator, writer: anytype, camera: *Camera) !void {
    var world = HittableList.init(alloc);

    const left_red = try Lambertian.initColor(Vec3{ 1.0, 0.2, 0.2 }, alloc);
    const back_green = try Lambertian.initColor(Vec3{ 0.2, 1.0, 0.2 }, alloc);
    const right_blue = try Lambertian.initColor(Vec3{ 0.2, 0.2, 1.0 }, alloc);
    const upper_orange = try Lambertian.initColor(Vec3{ 1.0, 0.5, 0.0 }, alloc);
    const lower_teal = try Lambertian.initColor(Vec3{ 0.2, 0.8, 0.8 }, alloc);

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
    const perl = try Lambertian.init(try Noise.init(4.0, alloc));
    var world = HittableList.init(alloc);
    try world.add(Sphere.new(Vec3{0.0, -1000.0, 0.0}, null, 1000.0, perl));
    try world.add(Sphere.new(Vec3{0.0, 2.0, 0.0}, null, 2.0, perl));
    const hittable = try Hittable.init(world, alloc);
    defer hittable.deinit();
    try camera.render(hittable, writer);
}

pub fn earth(alloc: std.mem.Allocator, writer: anytype, camera: *Camera) !void {
    camera.look_from = Vec3{0.0, 0.0, 12.0};
    const earth_tex = try ImageTex.initFile("earthmap.jpg", alloc);
    const surface = try Lambertian.init(earth_tex);
    const globe = try Hittable.init(Sphere.new(Vec3{0.0, 0.0, 0.0}, null, 2.0, surface), alloc);
    defer globe.deinit();
    try camera.render(globe, writer);
}

pub fn checkeredSpheres(alloc: std.mem.Allocator, writer: anytype, camera: *Camera) !void {
    var world = HittableList.init(alloc);
    const checker = try Lambertian.init(try Checker.initColor(0.32, Vec3{0.2, 0.3, 0.1}, Vec3{0.9, 0.9, 0.9}, alloc));
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
    const mat2 = try Lambertian.init(try Solid.init(Vec3{0.4, 0.2, 0.1}, alloc));
    try world.add(Sphere.new(Vec3{-4.0, 1.0, 0.0}, null, 1.0, mat2));
    const mat3 = try Material.init(
        Metal{ 
            .albedo = Vec3{0.7, 0.6, 0.5},
            .fuzz = 0.0,
        },
        alloc
    );
    try world.add(Sphere.new(Vec3{4.0, 1.0, 0.0}, null, 1.0, mat3));
    const checker = try Checker.initColor(0.32, Vec3{0.2, 0.3, 0.1}, Vec3{0.9, 0.9, 0.9}, alloc);
    try world.add(Sphere.new(Vec3{ 0.0, -1000.0, -1.0 }, null, 1000.0, try Lambertian.init(checker)));

    var a = lo;
    while (a < hi) : (a += 1.0) {
        var b = lo;
        while (b < hi) : (b += 1.0) {
            const choose_mat = rand();
            const center = Vec3{ a + 0.9 * rand(), 0.2, b + 0.9 * rand()};
            if (vec3.length(center - Vec3{4.0, 0.2, 0.0}) > 0.9) {
                const mat = try if (choose_mat < 0.8)
                    Lambertian.initColor(vec3.random() * vec3.random(), alloc)
                else if (choose_mat < 0.95)
                    Metal.init(vec3.randomRange(0.5, 1.0), util.randRange(0.0, 0.5), alloc)
                else 
                    Dielectric.init(1.5, alloc);

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
    try simpleLight(ta, Writer{}, &camera);
    try cornellBox(ta, Writer{}, &camera);
    try cornellSmoke(ta, Writer{}, &camera);
    try finalScene(ta, Writer{}, &camera);
}
