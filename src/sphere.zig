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

center: Vec3,
radius: f64,
mat: Rc(Material),

const Self = @This();

pub fn new(center: Vec3, radius: f64) Self {
    return Self{
        .center = center,
        .radius = @max(radius, 0.0),
    };
}

pub fn hit(self: *Self, ray: Ray, ray_t: Interval) ?HitRecord {
    const oc = self.center - ray.origin;
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
        .mat = self.mat.strongRef(),
    };
    const outward_normal = (rec.p - self.center) / vec3.vec3s(self.radius);
    rec.setFaceNormal(ray, outward_normal);
    return rec;
}
