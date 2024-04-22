const std = @import("std");
pub var rand: std.rand.DefaultPrng = undefined;

pub fn init() void {
    rand = std.rand.DefaultPrng.init(@bitCast(std.time.timestamp()));
}

pub const inf = std.math.inf(f64);

pub fn random() f64 {
    return rand.random().float(f64);
}

pub fn randRange(min: f64, max: f64) f64 {
    return min + (max - min) * random();
}