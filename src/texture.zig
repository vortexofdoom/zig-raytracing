const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const vec3s = vec3.vec3s;
const Ray = @import("ray.zig");
const std = @import("std");
const List = std.ArrayList;
const interface = @import("interface");
const SelfType = interface.SelfType;
const Interface = interface.Interface;
const Interval = @import("interval.zig");
const Material = @import("material.zig").Material;
const Aabb = @import("aabb.zig");
const Perlin = @import("perlin.zig");
const Image = @import("zstbi").Image;
const clamp = std.math.clamp;

pub const Texture = struct {
    const IFace = Interface(struct {
        value: *const fn (*SelfType, f64, f64, Vec3) Vec3,
        deinit: *const fn (*SelfType) void,
    }, interface.Storage.Owning);

    iface: IFace,
    ref_count: *usize,
    allocator: std.mem.Allocator,

    pub fn init(obj: anytype, allocator: std.mem.Allocator) !Texture {
        const ref_counter = try allocator.create(usize);
        ref_counter.* = 1;
        return Texture{
            .iface = try IFace.init(obj, allocator),
            .ref_count = ref_counter,
            .allocator = allocator,
        };
    }

    pub fn strongRef(self: *const Texture) Texture {
        self.ref_count.* += 1;
        return Texture{
            .iface = self.iface,
            .ref_count = self.ref_count,
            .allocator = self.allocator,
        };
    }

    pub fn value(self: *const Texture, u: f64, v: f64, p: Vec3) Vec3 {
        return self.iface.call("value", .{ u, v, p });
    }

    pub fn deinit(self: *const Texture) void {
        self.ref_count.* -= 1;
        if (self.ref_count.* == 0) {
            self.iface.call("deinit", .{});
            self.iface.deinit();
            self.allocator.destroy(self.ref_count);
        }
    }
};

pub const Solid = struct {
    albedo: Vec3,

    pub fn value(self: *const Solid, _: f64, _: f64, _: Vec3) Vec3 {
        return self.albedo;
    }

    pub fn deinit(_: *const Solid) void {}
};

pub const Checker = struct {
    scale: f64,
    even: Texture,
    odd: Texture,

    pub fn init(scale: f64, even: Texture, odd: Texture) Checker {
        return Checker{
            .scale = 1.0 / scale,
            .even = even,
            .odd = odd,
        };
    }

    pub fn initColor(scale: f64, even: Vec3, odd: Vec3, allocator: std.mem.Allocator) !Checker {
        return Checker{
            .scale = 1.0 / scale,
            .even = try Texture.init(Solid{ .albedo = even}, allocator),
            .odd = try Texture.init(Solid{ .albedo = odd}, allocator),
        };
    }

    pub fn value(self: *const Checker, u: f64, v: f64, p: Vec3) Vec3 {
        const scale = vec3s(self.scale);
        const is_even = @reduce(.Add, @as(@Vector(3, i64), @intFromFloat(@floor(scale * p)))) & 1 == 0;
        return if (is_even)
            self.even.value(u, v, p)
        else
            self.odd.value(u, v, p);
    }

    pub fn deinit(self: *const Checker) void {
        self.even.deinit();        
        self.odd.deinit();
    }
};

pub const ImageTex = struct {
    img: Image,

    pub fn value(self: *const ImageTex, u: f64, v: f64, _: Vec3) Vec3 {
        const u_clamp = clamp(u, 0.0, 1.0);
        const v_clamp = 1.0 - clamp(v, 0.0, 1.0);

        const i = @as(usize, @intFromFloat(u_clamp * @as(f64, @floatFromInt(self.img.width))));
        const j = @as(usize, @intFromFloat(v_clamp * @as(f64, @floatFromInt(self.img.height))));
        return @import("img.zig").pixelData(&self.img, i, j) / vec3s(255.0);
    }

    pub fn deinit(self: *ImageTex) void {
        self.img.deinit();
    }
};

pub const Noise = struct {
    noise: Perlin,
    scale: f64,

    pub fn value(self: *Noise, _: f64, _: f64, p: Vec3) Vec3 {
        return vec3s(0.5) * (vec3s(1.0) + std.math.sin(vec3s(self.scale * p[2]) + vec3s(10.0) * self.noise.turb(p, 7)));
    }

    pub fn deinit(self: *Noise) void {
        self.noise.deinit();
    }
};