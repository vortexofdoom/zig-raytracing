const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const SimdV3 = vec3.SimdV3;

pub const Ray = struct {
    origin: Vec3 = Vec3{},
    dir: Vec3 = Vec3{},

    pub fn new(origin: Vec3, dir: Vec3) Ray {
        return Ray{
            .origin = origin,
            .dir = dir,
        };
    }

    pub fn at(self: *const Ray, t: f64) Vec3 {
        return Vec3.fromSimd(self.origin.toSimd() + self.dir.scale(t).toSimd());
    }
};