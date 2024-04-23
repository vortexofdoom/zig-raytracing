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

pub const HitRecord = struct {
    p: Vec3,
    normal: Vec3 = undefined,
    mat: Material,
    t: f64,
    front: bool = undefined,
    u: f64 = 0.0,
    v: f64 = 0.0,

    /// Sets the hit record normal vector
    /// `outward_normal` is expected to have unit length (be normalized)
    pub fn setFaceNormal(self: *HitRecord, ray: Ray, outward_normal: Vec3) void {
        self.front = vec3.dot(ray.dir, outward_normal) < 0.0;
        self.normal = if (self.front) outward_normal else -outward_normal;
    }
};

pub const Hittable = struct {
    const IFace = Interface(struct {
        hit: *const fn (*const SelfType, Ray, Interval) ?HitRecord,
        deinit: *const fn (*SelfType) void,
        boundingBox: *const fn (*const SelfType) Aabb,
    }, interface.Storage.Owning);

    iface: IFace,
    ref_count: *usize,
    allocator: std.mem.Allocator,

    pub fn init(obj: anytype, allocator: std.mem.Allocator) !Hittable {
        const rc = try allocator.create(usize);
        rc.* = 1;
        return Hittable{
            .iface = try IFace.init(obj, allocator),
            .ref_count = rc,
            .allocator = allocator,
        };
    }

    pub fn strongRef(self: *const Hittable) Hittable {
        self.ref_count.* += 1;
        return Hittable{
            .iface = self.iface,
            .ref_count = self.ref_count,
            .allocator = self.allocator,
        };
    }

    pub fn hit(self: *const Hittable, ray: Ray, ray_t: Interval) ?HitRecord {
        return self.iface.call("hit", .{ ray, ray_t });
    }

    pub fn boundingBox(self: *const Hittable) Aabb {
        return self.iface.call("boundingBox", .{});
    }

    pub fn deinit(self: *const Hittable) void {
        self.ref_count.* -= 1;
        if (self.ref_count.* == 0) {
            self.iface.call("deinit", .{});
            self.iface.deinit();
            self.allocator.destroy(self.ref_count);
        }
    }
};

pub const HittableList = struct {
    list: List(Hittable),
    allocator: std.mem.Allocator,
    bbox: Aabb = Aabb{},
    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
            .list = List(Hittable).init(allocator),
        };
    }

    pub fn hit(self: *const Self, ray: Ray, ray_t: Interval) ?HitRecord {
        var hit_record: ?HitRecord = null;
        var closest = ray_t.max;
        for (self.list.items) |obj| {
            if (obj.hit(ray, Interval.new(ray_t.min, closest))) |rec| {
                // if (hit_record) |hr| Material.deinit(hr.mat);
                closest = rec.t;
                hit_record = rec;
            }
        }

        return hit_record;
    }

    pub fn boundingBox(self: *const Self) Aabb {
        return self.bbox;
    }

    pub fn deinit(self: *Self) void {
        self.clearRetainingCapacity();
        self.list.deinit();
    }

    pub fn add(self: *Self, item: anytype) !void {
        const new = try Hittable.init(item, self.allocator);
        self.bbox = self.bbox.combined(item.boundingBox());
        try self.list.append(new);
    }

    pub fn clearRetainingCapacity(self: *Self) void {
        for (self.list.items) |*h| h.deinit();
        self.list.clearRetainingCapacity();
    }
};
