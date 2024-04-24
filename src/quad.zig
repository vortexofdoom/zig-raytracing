const Aabb = @import("aabb.zig");
const HitRecord = @import("hit.zig").HitRecord;
const Interval = @import("interval.zig");
const Material = @import("material.zig").Material;
const Ray = @import("ray.zig");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const vec3s = vec3.vec3s;

const Self = @This();

q: Vec3,
u: Vec3,
v: Vec3,
w: Vec3,
normal: Vec3,
d: f64,
mat: Material,
bbox: Aabb,

pub fn init(q: Vec3, u: Vec3, v: Vec3, mat: Material) Self {
    const n = vec3.cross(u, v);
    const normal = vec3.normalize(n);
    return Self {
        .q = q,
        .u = u,
        .v = v,
        .w = n / vec3s(vec3.dot(n, n)),
        .mat = mat,
        .normal = normal,
        .d = vec3.dot(normal, q),
        .bbox = calcBoundingBox(q, u, v),
    };

}

pub fn boundingBox(self: *const Self) Aabb {
    return self.bbox;
}

fn calcBoundingBox(q: Vec3, u: Vec3, v: Vec3) Aabb {
    const diag_1 = Aabb.new(q, q + u + v);
    const diag_2 = Aabb.new(q + u, q + v);
    return Aabb.combined(diag_1, diag_2);
}

pub fn hit(self: *const Self, ray: Ray, ray_t: Interval) ?HitRecord {
    const denom = vec3.dot(self.normal, ray.dir);
    if (@abs(denom) < 1e-8) return null;

    const t = (self.d - vec3.dot(self.normal, ray.origin)) / denom;
    if (!ray_t.contains(t)) return null;
    
    const intersection = ray.at(t);
    const planar_hit_vec = intersection - self.q;
    const alpha = vec3.dot(self.w, vec3.cross(planar_hit_vec, self.v));
    const beta = vec3.dot(self.w, vec3.cross(self.u, planar_hit_vec));

    const unit = Interval.new(0.0, 1.0);
    if (!unit.contains(alpha) or !unit.contains(beta)) return null;

    var rec = HitRecord{
       .t = t,
       .u = alpha,
       .v = beta,
       .p = intersection,
       .mat = self.mat, 
    };

    rec.setFaceNormal(ray, self.normal);
    return rec;
}

pub fn deinit(self: *const Self) void {
    self.mat.deinit();
}