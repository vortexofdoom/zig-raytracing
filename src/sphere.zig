const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const SimdV3 = vec3.SimdV3;
const Ray = @import("ray.zig").Ray;
const hittable = @import("hit.zig");
const Hittable = hittable.Hittable;
const HitRecord = hittable.HitRecord;

center: Vec3,
radius: f64,

const Self = @This();

pub fn new(center: Vec3, radius: f64) Self {
    return Self{
        .center = center,
        .radius = @max(radius, 0.0),
    };
}

pub fn hit(self: *const Self, ray: *const Ray, t_min: f64, t_max: f64) ?HitRecord {
    const oc = Vec3.fromSimd(self.center.toSimd() - ray.origin.toSimd());
    const a = ray.dir.lengthSquared();
    const h = ray.dir.dot(&oc);
    const c = oc.lengthSquared() - (self.radius * self.radius);
    const discriminant = h * h - a * c;
    
    if (discriminant < 0.0) return null;
    const sqrtd = @sqrt(discriminant);
    var root: f64 = (h - sqrtd) / a;
    if (root <= t_min or t_max <= root) {
        root = (h + sqrtd) / a;
        if (root <= t_min or t_max <= root) return null;
    }

    var rec = HitRecord{
        .t = root,
        .p = ray.at(root),
    };
    const outward_normal = Vec3.fromSimd((rec.p.toSimd() - self.center.toSimd()) / @as(SimdV3, @splat(self.radius)));
    rec.setFaceNormal(ray, &outward_normal);
    return rec;
}