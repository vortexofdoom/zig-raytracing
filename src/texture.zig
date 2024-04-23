const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const vec3s = vec3.vec3s;
const Ray = @import("ray.zig");
const std = @import("std");
const List = std.ArrayList;
const Rc = @import("rc.zig").RefCounted;
const interface = @import("interface");
const SelfType = interface.SelfType;
const Interface = interface.Interface;
const Interval = @import("interval.zig");
const Material = @import("material.zig").Material;
const Aabb = @import("aabb.zig");

pub const Texture = struct {
    const IFace = Interface(struct {
        value: *const fn (*const SelfType, f64, f64, Vec3) Vec3,
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

    pub fn init(scale: f64, even: Rc(Texture), odd: Rc(Texture)) Checker {
        return Checker{
            .scale = scale,
            .even = even,
            .odd = odd,
        };
    }

    pub fn initColor(scale: f64, left: Vec3, right: Vec3, allocator: std.mem.Allocator) !Checker {
        return Checker{
            .scale = scale,
            .even = try Texture.init(Solid{ .albedo = left}, allocator),
            .odd = try Texture.init(Solid{ .albedo = right}, allocator),
        };
    }

    pub fn value(self: *const Checker, u: f64, v: f64, p: Vec3) Vec3 {
        const scale = vec3s(self.scale);
        const is_even = @as(i64, @intFromFloat(@reduce(.Add, @floor(scale * p)))) & 1 == 0;
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