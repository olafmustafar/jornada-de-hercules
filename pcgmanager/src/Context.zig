const std = @import("std");

const Self = @This();

mutex: std.Thread.Mutex,
random: std.Random.DefaultPrng,

pub fn init() Self {
    return .{
        .mutex = .{},
        .random = .init(1),
    };
}
