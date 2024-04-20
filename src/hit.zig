const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const SimdV3 = vec3.SimdV3;
const Ray = @import("ray.zig").Ray;
const std = @import("std");
const List = std.ArrayList;
const Rc = @import("rc.zig").RefCounted;
const interface = @import("interface");
const SelfType = interface.SelfType;
const Interface = interface.Interface;

pub const HitRecord = struct {
    p: Vec3,
    normal: Vec3 = undefined,
    t: f64,
    front: bool = undefined,

    /// Sets the hit record normal vector
    /// `outward_normal` is expected to have unit length (be normalized)
    pub fn setFaceNormal(self: *HitRecord, ray: *const Ray, outward_normal: *const Vec3) void {
        self.front = ray.dir.dot(outward_normal) < 0.0;
        self.normal = if (self.front) outward_normal.* else Vec3.fromSimd(outward_normal.toSimd() * @as(SimdV3, @splat(-1.0)));
    }
};

pub const Hittable = struct {
    const IFace = Interface(struct {
        hit: *const fn (*SelfType, ray: *const Ray, t_min: f64, t_max: f64) ?HitRecord,
    }, interface.Storage.Owning);

    iface: IFace,

    pub fn init(obj: anytype, allocator: std.mem.Allocator) !Hittable {
        return Hittable {
            .iface = try IFace.init(obj, allocator),
        };
    }

    pub fn hit(self: *const Hittable, ray: *const Ray, t_min: f64, t_max: f64) ?HitRecord {
        return self.iface.call("hit", .{ray, t_min, t_max});
    }

    pub fn deinit(self: *const Hittable) void {
        self.iface.deinit();
    }
};

pub const HittableList = struct {
    list: List(Hittable),
    allocator: std.mem.Allocator,
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self {
            .allocator = allocator,
            .list = List(Hittable).init(allocator),
        };
    }

    pub fn hit(self: *const Self, ray: *const Ray, t_min: f64, t_max: f64) ?HitRecord {
        var hit_record: ?HitRecord = null;
        var closest = t_max;

        for (self.list.items) |*obj| {
            if (obj.hit(ray, t_min, closest)) |rec| {
                closest = rec.t;
                hit_record = rec;
            }
        }

        return hit_record;
    }

    pub fn deinit(self: *Self) void {
        self.clearRetainingCapacity();
        self.list.deinit();
    }

    pub fn add(self: *Self, item: anytype) !void {
        const new = try Hittable.init(item, self.allocator);
        try self.list.append(new);
    }

    pub fn clearRetainingCapacity(self: *Self) void {
        for (self.list.items) |*i| i.deinit();
        self.list.clearRetainingCapacity();
    }
};