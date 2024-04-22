const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Ray = @import("ray.zig");
const Interval = @import("interval.zig");
const inf = @import("util.zig").inf;
const vec3s = vec3.vec3s;

const Self = @This();

max: Vec3 = vec3s(inf),
min: Vec3 = vec3s(-inf),

pub fn new(a: Vec3, b: Vec3) Self {
    return Self {
        .max = @max(a, b),
        .min = @min(a, b),
    };
}

pub fn combined(a: Self, b: Self) Self {
    return Self{
        .max = @max(a.max, b.max),
        .min = @min(a.min, b.min),
    };
}

pub fn hit(self: *const Self, ray: Ray, ray_t: Interval) bool {
    var t_min = vec3s(ray_t.min);
    var t_max = vec3s(ray_t.max);
    
    const adinv = vec3s(1.0) / ray.dir;
    const t0 = (self.min - ray.origin) * adinv;
    const t1 = (self.max - ray.origin) * adinv;
    t_min = @max(t_min, @min(t0, t1));
    t_max = @min(t_max, @max(t0, t1));

    return @reduce(.And, t_min < t_max);
}