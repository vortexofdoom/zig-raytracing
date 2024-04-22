const std = @import("std");
const inf = @import("util.zig").inf;

pub const universe = Self.new(-inf, inf);

min: f64 = inf,
max: f64 = -inf,

const Self = @This();

pub fn new(min: f64, max: f64) Self {
    return Self{
        .min = min,
        .max = max,
    };
}

pub fn expand(self: *const Self, delta: f64) Self {
    const padding = delta / 2.0;
    return Self{
        .min = self.min - padding,
        .max = self.max + padding,
    };
}

pub fn clamp(self: *const Self, x: f64) f64 {
    if (x < self.min) return self.min;
    if (x > self.max) return self.max;
    return x;
}

pub fn contains(self: *const Self, x: f64) bool {
    return self.min <= x and self.max >= x;
}

pub fn surrounds(self: *const Self, x: f64) bool {
    return self.min < x and self.max > x;
}
