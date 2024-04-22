const Aabb = @import("aabb.zig");
const hittable = @import("hit.zig");
const HitRecord = hittable.HitRecord;
const Hittable = hittable.Hittable;
const HittableList = hittable.HittableList;
const Interval = @import("interval.zig");
const Ray = @import("ray.zig");
const Rc = @import("rc.zig").RefCounted;
const std = @import("std");
const sort = std.sort.block;

left: Rc(Hittable) = undefined,
right: Rc(Hittable) = undefined,
bbox: Aabb = Aabb{},

const Self = @This();

fn lt(axis: usize, a: Rc(Hittable), b: Rc(Hittable)) bool {
    return (a.weakRef().boundingBox().min < b.weakRef().boundingBox().min)[axis];
}

pub fn new(list: HittableList) !Self {
    return Self.init(list.list.items, list.allocator);
}

pub fn init(objects: []Rc(Hittable), allocator: std.mem.Allocator) !Self {
    var self = Self{};
    for (objects) |obj| self.bbox = self.bbox.combined(obj.weakRef().boundingBox());
    const axis = self.bbox.longestAxis();
    if (objects.len == 1) {
        self.left = objects[0].strongRef();
        self.right = objects[0].strongRef();
    } else if (objects.len == 2) {
        self.left = objects[0].strongRef();
        self.right = objects[1].strongRef();
    } else {
        sort(Rc(Hittable), objects, axis, lt);
        const mid = objects.len / 2;
        self.left = try Hittable.init(try Self.init(objects[0..mid], allocator), allocator);
        self.right = try Hittable.init(try Self.init(objects[mid..], allocator), allocator);
    }
    self.bbox = Aabb.combined(self.left.weakRef().boundingBox(), self.right.weakRef().boundingBox());
    return self;
}

pub fn deinit(self: *const Self) void {
    Hittable.deinit(self.left);
    Hittable.deinit(self.right);
}

pub fn boundingBox(self: *const Self) Aabb {
    return self.bbox;
}

pub fn hit(self: *const Self, ray: Ray, t: Interval) ?HitRecord {
    if (!self.bbox.hit(ray, t)) return null;

    const left = self.left.weakRef();
    const hit_left = left.hit(ray, t);

    const right = self.right.weakRef();
    const hit_right = right.hit(ray, Interval.new(t.min, if (hit_left) |l| l.t else t.max));
    return hit_right orelse hit_left;
}