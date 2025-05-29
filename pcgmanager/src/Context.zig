const std = @import("std");

const Self = @This();

mutex: std.Thread.Mutex,
gpa: std.mem.Allocator,
random: std.Random.DefaultPrng,

pub fn init(gpa: std.mem.Allocator) Self {
    return .{
        .mutex = .{},
        .random = .init(1),
        .gpa = gpa,
    };
}
