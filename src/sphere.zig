const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const SimdV3 = vec3.Vec3;
const Ray = @import("ray.zig");
const hittable = @import("hit.zig");
const Hittable = hittable.Hittable;
const HitRecord = hittable.HitRecord;
const Interval = @import("interval.zig");
const Material = @import("material.zig").Material;
const Rc = @import("rc.zig").RefCounted;
const Aabb = @import("aabb.zig");

center: Vec3,
center_mov: ?Vec3 = null,
radius: f64,
mat: Material,
bbox: Aabb = Aabb{},

const Self = @This();

pub fn new(center: Vec3, center_mov: ?Vec3, radius: f64, mat: Material) Self {
    const rvec = vec3.vec3s(radius);
    var bbox = Aabb.new(center - rvec, center + rvec);
    if (center_mov) |c2| bbox = bbox.combined(Aabb.new(c2 - rvec, c2 + rvec));
    return Self{
        .center = center,
        .center_mov = center_mov,
        .radius = @max(radius, 0.0),
        .mat = mat,
        .bbox = bbox,
    };
}

pub fn deinit(self: *Self) void {
    self.mat.deinit();
}

pub fn boundingBox(self: *const Self) Aabb {
    return self.bbox;
}

fn centerAt(self: *const Self, t: f64) Vec3 {
    return if (self.center_mov) |c2| self.center + vec3.vec3s(t) * c2 else self.center;
}

pub fn hit(self: *const Self, ray: Ray, ray_t: Interval) ?HitRecord {
    const oc = self.centerAt(ray.time) - ray.origin;
    const a = vec3.lengthSquared(ray.dir);
    const h = vec3.dot(ray.dir, oc);
    const c = vec3.lengthSquared(oc) - (self.radius * self.radius);
    const discriminant = h * h - a * c;

    if (discriminant < 0.0) return null;
    const sqrtd = @sqrt(discriminant);
    var root: f64 = (h - sqrtd) / a;
    if (!ray_t.surrounds(root)) {
        root = (h + sqrtd) / a;
        if (!ray_t.surrounds(root)) return null;
    }

    var rec = HitRecord{
        .t = root,
        .p = ray.at(root),
        .mat = self.mat,
    };
    const outward_normal = (rec.p - self.center) / vec3.vec3s(self.radius);
    rec.setFaceNormal(ray, outward_normal);
    return rec;
}
