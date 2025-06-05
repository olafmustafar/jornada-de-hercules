const std = @import("std");

const Self = @This();

difficulty_level: usize = 5,
difficulty_classes: usize = 10,
gpa: std.mem.Allocator,
random: std.Random.DefaultPrng,

pub fn init(gpa: std.mem.Allocator) Self {
    return .{
        .random = .init(1),
        .difficulty_level = 5,
        .difficulty_classes = 10,
        .gpa = gpa,
    };
}
