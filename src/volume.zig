const Aabb = @import("aabb.zig");
const hittable = @import("hit.zig");
const Hittable = hittable.Hittable;
const HitRecord = hittable.HitRecord;
const Interval = @import("interval.zig");
const material = @import("material.zig");
const Material = material.Material;
const Ray = @import("ray.zig");
const util = @import("util.zig");
const vec3 = @import("vec3.zig");

pub const Constant = struct {
    boundary: Hittable,
    neg_inv_density: f64,
    phase_func: Material,

    pub fn init(boundary: Hittable, density: f64, color: vec3.Vec3) !Constant {
        return Constant{
            .boundary = boundary,
            .neg_inv_density = -1.0 / density,
            .phase_func = try material.Isotropic.initColor(color, boundary.allocator),
        };
    }

    pub fn hit(self: *const Constant, ray: Ray, ray_t: Interval) ?HitRecord {
        var rec1 = self.boundary.hit(ray, Interval.universe) orelse return null;
        var rec2 = self.boundary.hit(ray, Interval.new(rec1.t + 0.0001, util.inf)) orelse return null;

        rec1.t = @max(rec1.t, ray_t.min);
        rec2.t = @min(rec2.t, ray_t.max);

        if (rec1.t >= rec2.t) return null;
        rec1.t = @max(rec1.t, 0.0);

        const ray_len = vec3.length(ray.dir);
        const dist_inside_boundary = (rec2.t - rec1.t) * ray_len;
        const hit_dist = self.neg_inv_density * @log(util.random());
        
        if (hit_dist > dist_inside_boundary) return null;

        const rec_t = rec1.t + hit_dist / ray_len;
        return HitRecord{
            .t = rec_t,
            .p = ray.at(rec_t),
            .normal = vec3.unit,    // arbitrary
            .front = true,          // arbitrary
            .mat = self.phase_func,            
        };
    }

    pub fn boundingBox(self: *const Constant) Aabb {
        return self.boundary.boundingBox();
    }

    pub fn deinit(self: *const Constant) void {
        self.boundary.deinit();
        self.phase_func.deinit();
    }
};