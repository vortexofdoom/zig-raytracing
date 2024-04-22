const util = @import("util.zig");
const rand = util.random;
const randRange = util.randRange;
pub const Vec3 = @Vector(3, f64);

vec: Vec3,

pub fn vec3s(val: f64) Vec3 {
    return @splat(val);
}

pub fn random() Vec3 {
    return Vec3{ rand(), rand(), rand() };
}

pub fn randomRange(min: f64, max: f64) Vec3 {
    return Vec3{ randRange(min, max), randRange(min, max), randRange(min, max) };
}

pub inline fn randomInUnitSphere() Vec3 {
    while (true) {
        const p = randomRange(-1.0, 1.0);
        if (length(p) < 1.0) return p;
    }
}

pub inline fn randomUnitVec() Vec3 {
    return normalize(randomInUnitSphere());
}

pub inline fn randomOnHemisphere(normal: Vec3) Vec3 {
    const on_unit_sphere = randomUnitVec();
    return if (dot(on_unit_sphere, normal) > 0.0) on_unit_sphere else -on_unit_sphere;
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

pub inline fn reflect(v: Vec3, n: Vec3) Vec3 {
    return v - vec3s(2.0 * dot(v, n)) * n;
}

pub inline fn refract(uv: Vec3, n: Vec3, etai_over_etat: f64) Vec3 {
    const cos_theta = @min(dot(-uv, n), 1.0);
    const out_perp = vec3s(etai_over_etat) * (uv + vec3s(cos_theta) * n);
    const out_para = vec3s(-@sqrt(@abs(1.0 - lengthSquared(out_perp)))) * n;
    return out_perp + out_para;
}

pub inline fn randomInUnitDisc() Vec3 {
    while (true) {
        const p = Vec3{ randRange(-1.0, 1.0), randRange(-1.0, 1.0), 0.0 };
        if (lengthSquared(p) < 1.0) return p;
    }
}
