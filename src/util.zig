const std = @import("std");
var random: std.rand.DefaultPrng = undefined;

pub fn init() void {
    random = std.rand.DefaultPrng.init(@bitCast(std.time.timestamp()));
}

pub const inf = std.math.inf(f64);

pub fn rand() f64 {
    return random.random().float(f64);
}

pub fn randRange(min: f64, max: f64) f64 {
    return min + (max - min) * rand();
}