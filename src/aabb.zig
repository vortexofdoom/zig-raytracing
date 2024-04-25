const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Ray = @import("ray.zig");
const Interval = @import("interval.zig");
const inf = @import("util.zig").inf;
const vec3s = vec3.vec3s;

const Self = @This();

pub const UNIVERSE = Self{
    .max = vec3s(inf),
    .min = vec3s(-inf),
};

pub const EMPTY = Self{};

max: Vec3 = vec3s(-inf),
min: Vec3 = vec3s(inf),

pub fn new(a: Vec3, b: Vec3) Self {
    return Self {
        .max = @max(a, b),
        .min = @min(a, b),
    };
}

pub fn longestAxis(self: *Self) usize {
    const diff = self.max - self.min;
    const a = @intFromBool(diff[1] > diff[0]);
    return if (diff[a] > diff[2]) a else 2;
}

const min_delta = 0.0001;

fn padToMin(self: *Self) void {
    const d = vec3s(min_delta);
    self.expand(@select(Vec3, (self.max - self.min) < d, d, vec3s(0.0)));
}

pub fn offset(self: *const Self, v: Vec3) Self {
    return Self{
        .max = self.max + v,
        .min = self.min + v,
    };
}

fn expand(self: *Self, delta: Vec3) void {
    const delta_v = delta / vec3s(2.0);
    self.max += delta_v;
    self.min -= delta_v;
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