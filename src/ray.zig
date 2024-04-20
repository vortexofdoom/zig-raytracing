const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const SimdV3 = vec3.Vec3;

const Self = @This();

origin: Vec3 = undefined,
dir: Vec3 = undefined,

pub fn new(origin: Vec3, dir: Vec3) Self {
    return Self{
        .origin = origin,
        .dir = dir,
    };
}

pub fn at(self: *const Self, t: f64) Vec3 {
    return self.origin + self.dir * vec3.vec3s(t);
}
