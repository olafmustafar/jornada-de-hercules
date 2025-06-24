const std = @import("std");

const Self = @This();

difficulty_level: usize,
difficulty_classes: usize,
gpa: std.mem.Allocator,
random: std.Random.DefaultPrng,

rate_bullets_avoided: f32,
hits_taken: i32,


pub fn init(gpa: std.mem.Allocator) Self {
    return .{
        .random = .init(1),
        // monsters will begin with the difficulty_level -1 and go for +1 at the end of the dungeon
        .difficulty_level = 5,
        .difficulty_classes = 10, //leave at 10 different classes (enemy difficulty_levels will be from 0 to 9)
        .gpa = gpa,
    };
}
