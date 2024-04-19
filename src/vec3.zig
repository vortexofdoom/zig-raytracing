pub const SimdV3 = @Vector(3, f64);

pub const Vec3 = packed struct {
    x: f64 = 0.0,
    y: f64 = 0.0,
    z: f64 = 0.0,

    const Self = @This();

    pub fn new(x: f64, y: f64, z: f64) Self {
        return Self{
            .x = x,
            .y = y,
            .z = z,
        };
    }

    pub fn toSimd(self: *const Self) SimdV3 {
        return @bitCast(self.*);
    }

    pub fn fromSimd(vec: SimdV3) Self {
        return @bitCast(vec);
    }

    pub fn length(self: *const Self) f64 {
        return @sqrt(self.lengthSquared());
    }

    pub fn lengthSquared(self: *const Self) f64 {
        return self.dot(self);
    }

    pub fn print(self: *const Self, writer: anytype) !void {
        try writer.print("{d} {d} {d}", .{self.x, self.y, self.z});
    }

    pub fn scale(self: *const Self, amt: f64) Self {
        return Self.fromSimd(self.toSimd() * @as(SimdV3, @splat(amt)));
    }

    // There are better ways
    // see https://github.com/ziglang/zig/issues/4961#issuecomment-610050227
    pub fn dot(u: *const Self, v: *const Self) f64 {
        return @reduce(.Add, u.toSimd() * v.toSimd());
    }

    // Maybe a SIMD way to do this
    pub fn cross(u: *const Self, v: *const Self) Self {
        return Self{
            .x = u.y * v.z - u.z * v.y,
            .y = u.z * v.x - u.x * v.z,
            .z = u.x * v.y - u.y * v.x,
        };
    }

    pub fn normalize(self: *const Self) Self {
        return Self.fromSimd(self.toSimd() * @as(SimdV3, @splat(1 / self.length())));
    }
};