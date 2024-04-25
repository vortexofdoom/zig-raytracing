const std = @import("std");
const degToRad = std.math.degreesToRadians;

const Aabb = @import("aabb.zig");
const hittable = @import("hit.zig");
const Hittable = hittable.Hittable;
const HitRecord = hittable.HitRecord;
const Interval = @import("interval.zig");
const Ray = @import("ray.zig");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const inf = @import("util.zig").inf;

const Self = @This();

const Rotation = struct {
    cos_theta: f64 = 0.0,
    sin_theta: f64 = 0.0,

    pub fn hit(self: *const Rotation, ray: Ray, ray_t: Interval, obj: Hittable) ?HitRecord {
        var orig = ray.origin;
        var dir = ray.dir;

        orig[0] = self.cos_theta * ray.origin[0] - self.sin_theta * ray.origin[2];
        orig[2] = self.sin_theta * ray.origin[0] + self.cos_theta * ray.origin[2];

        dir[0] = self.cos_theta * ray.dir[0] - self.sin_theta * ray.dir[2];
        dir[2] = self.sin_theta * ray.dir[0] + self.cos_theta * ray.dir[2];

        const rot = Ray{
            .origin = orig,
            .dir = dir,
            .time = ray.time,
        };

        var rec = obj.hit(rot, ray_t) orelse return null;

        var p = rec.p;
        p[0] = self.cos_theta * rec.p[0] + self.sin_theta * rec.p[2];
        p[2] = -self.sin_theta * rec.p[0] + self.cos_theta * rec.p[2];

        var norm = rec.normal;

        norm[0] = self.cos_theta * rec.normal[0] + self.sin_theta * rec.normal[2];
        norm[0] = -self.sin_theta * rec.normal[0] + self.cos_theta * rec.normal[2];

        rec.p = p;
        rec.normal = norm;
        return rec;
    }
};

obj: Hittable,
offset: Vec3 = vec3.zero,
rot_y: Rotation,
bbox: Aabb,

pub fn init(obj: Hittable, angle: f64, offset: Vec3) Self {
    var self = Self{
        .obj = obj,
        .offset = offset,
        .rot_y = Rotation{},
        .bbox = obj.boundingBox().offset(offset),
    };

    self.rotY(angle);
    return self;
}

pub fn hit(self: *const Self, ray: Ray, ray_t: Interval) ?HitRecord {
    const offset_r = Ray{
        .origin = ray.origin - self.offset,
        .dir = ray.dir,
        .time = ray.time,
    };

    var rec = self.rot_y.hit(offset_r, ray_t, self.obj) orelse return null;
    rec.p += self.offset;
    return rec;
}

pub fn rotY(self: *Self, degrees: f64) void {
    const radians = degToRad(degrees);
    self.rot_y.sin_theta = @sin(radians);
    self.rot_y.cos_theta = @cos(radians);
    self.bbox = self.obj.boundingBox();

    var min = vec3.vec3s(inf);
    var max = vec3.vec3s(-inf);

    for (0..2) |i| {
        for (0..2) |j| {
            for (0..2) |k| {
                const ijk = @as(Vec3, @floatFromInt(@Vector(3, usize){i, j, k}));
                const xyz = (ijk * self.bbox.max) + (vec3.unit - ijk) * self.bbox.min;

                const new_x = self.rot_y.cos_theta * xyz[0] + self.rot_y.sin_theta * xyz[2];
                const new_z = -self.rot_y.sin_theta * xyz[0] + self.rot_y.cos_theta * xyz[2];
                const tester = Vec3{new_x, xyz[1], new_z};
                min = @min(min, tester);
                max = @max(max, tester);
            }
        }
    }
    self.bbox = Aabb{
        .min = min, 
        .max = max
    };
}

pub fn boundingBox(self: *const Self) Aabb {
    return self.bbox;
}

pub fn deinit(self: *const Self) void {
    self.obj.deinit();
}