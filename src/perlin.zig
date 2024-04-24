const util = @import("util.zig");
const std = @import("std");
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const vec3s = vec3.vec3s;

const Self = @This();

const POINT_COUNT = 256;
randvec: []Vec3,
perm_x: []i32,
perm_y: []i32,
perm_z: []i32,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !Self {
    const randvec = try allocator.alloc(Vec3, POINT_COUNT);
    for (0..POINT_COUNT) |i| randvec[i] = vec3.normalize(vec3.randomRange(-1.0, 1.0));
    return Self{
        .randvec = randvec,
        .perm_x = try generatePerm(allocator),
        .perm_y = try generatePerm(allocator),
        .perm_z = try generatePerm(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.allocator.free(self.randvec);
    self.allocator.free(self.perm_x);
    self.allocator.free(self.perm_y);
    self.allocator.free(self.perm_z);
}

fn generatePerm(allocator: std.mem.Allocator) ![]i32 {
    const p = try allocator.alloc(i32, POINT_COUNT);
    for (0..POINT_COUNT) |i| p[i] = @truncate(@as(i32, @intCast(i)));
    permute(p);
    return p;
}

fn permute(p: []i32) void {
    var i: usize = POINT_COUNT - 1;
    while (i > 0) : (i -= 1) {
        const target = util.rand.random().uintAtMost(usize, i);
        std.mem.swap(i32, &p[i], &p[target]);
    }
}

pub fn noise(self: *Self, p: Vec3) Vec3 {
    const floor = @floor(p);
    const uvw = p - floor;
    const ijk = @as(@Vector(3, isize), @intFromFloat(floor));
    var c: [2][2][2]Vec3 = undefined;
    for (0..2) |di| {
        for (0..2) |dj| {
            for (0..2) |dk| {
                const dijk = @as(@Vector(3, usize), @bitCast(@Vector(3, usize){di, dj, dk}));
                const x, const y, const z = @as(@Vector(3, u8), @truncate(@as(@Vector(3, usize), @bitCast(ijk)) +% dijk));
                c[di][dj][dk] = self.randvec[@as(u32, @intCast(self.perm_x[x] ^ self.perm_y[y] ^ self.perm_z[z]))];
            }
        }
    }
    return perlinInterp(c, uvw);
}

/// This feels like it could be done with vectors instead of a 3D array
pub fn perlinInterp(c: [2][2][2]Vec3, uvw: Vec3) Vec3 {
    const uvw2 = uvw * uvw * (vec3s(3.0) - vec3s(2.0) * uvw);
    var accum: f64 = 0.0;
    for (0..2) |i| {
        for (0..2) |j| {
            for (0..2) |k| {
                const ijk = @as(Vec3, @floatFromInt(@Vector(3, usize){i, j, k}));
                const one = vec3s(1.0);
                accum += @reduce(.Mul, (ijk * uvw2) + (one - ijk) * (one - uvw2)) * vec3.dot(c[i][j][k], uvw - ijk);
            }
        }
    }
    return vec3s(accum);
}