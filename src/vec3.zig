pub const Vec3 = @Vector(3, f64);

vec: Vec3,

pub fn vec3s(val: f64) Vec3 {
    return @splat(val);
}

const Vec3Component = enum { x, y, z };

pub inline fn swizzle(
    v: Vec3,
    comptime x: Vec3Component,
    comptime y: Vec3Component,
    comptime z: Vec3Component,
) Vec3 {
    return @shuffle(f64, v, undefined, [3]i32{ @intFromEnum(x), @intFromEnum(y), @intFromEnum(z) });
}

pub inline fn length(vec: Vec3) f64 {
    return @sqrt(lengthSquared(vec));
}

pub inline fn lengthSquared(vec: Vec3) f64 {
    return dot(vec, vec);
}

pub fn print(vec: Vec3, writer: anytype) !void {
    try writer.print("{d} {d} {d}", .{ vec[0], vec[1], vec[2] });
}

// There are better ways if you never need it as a scalar
// see https://github.com/ziglang/zig/issues/4961#issuecomment-610050227
pub inline fn dot(u: Vec3, v: Vec3) f64 {
    return @reduce(.Add, u * v);
}

pub inline fn cross(u: Vec3, v: Vec3) Vec3 {
    var a = swizzle(u, .y, .z, .x);
    var b = swizzle(v, .z, .x, .y);
    const res = a * b;
    a = swizzle(a, .y, .z, .x);
    b = swizzle(b, .z, .x, .y);
    return res - a * b;
}

pub inline fn normalize(v: Vec3) Vec3 {
    return v / vec3s(length(v));
}
