const std = @import("std");
const PCGManager = @import("root.zig");

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var pcg = try PCGManager.init(alloc);

    try pcg.generate(.{ .room = .{ .generate = .{} } });
    try pcg.generate(.{ .room = .{ .generate = .{} } });
    try pcg.generate(.{ .room = .{ .generate = .{} } });
    try pcg.generate(.{ .room = .{ .generate = .{} } });
    try pcg.generate(.{ .room = .{ .generate = .{} } });
    try pcg.generate(.{ .architecture = .{ .generate = .{
        .diameter = 10,
        .max_corridor_length = 5,
        .branch_chance = 0.25,
        .min_branch_diameter = 2,
        .max_branch_diameter = 5,
        .change_direction_chance = 0.25,
    } } });

    const level = try pcg.retrieve_level();
    defer level.deinit();

    for (0..level.height) |y| {
        for (0..level.width) |x| {
            std.debug.print("{c}", .{level.get(x,y).to_char()});
        }
        std.debug.print("\n", .{});
    }
}
