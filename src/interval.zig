const std = @import("std");
const inf = std.math.inf(f64);

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

pub fn contains(self: *const Self, x: f64) bool {
    return self.min <= x and self.max >= x;
}

pub fn surrounds(self: *const Self, x: f64) bool {
    return self.min < x and self.max > x;
}
