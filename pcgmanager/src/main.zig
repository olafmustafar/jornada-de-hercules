const std = @import("std");
const PCGManager = @import("root.zig");

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    var pcg = try PCGManager.init(alloc);

    try pcg.generate(.{ .rooms = .{ .generate = .{} } });
    try pcg.generate(.{ .enemies = .{ .generate = .{} } });
    try pcg.generate(.{ .architecture = .{ .generate = .{
        .diameter = 10,
        .max_corridor_length = 5,
        .branch_chance = 0.25,
        .min_branch_diameter = 2,
        .max_branch_diameter = 5,
        .change_direction_chance = 0.25,
    } } });

    const levels = try pcg.retrieve_level();
    defer levels.deinit();
    defer for (levels.items) |lvl| lvl.deinit();

    for (levels.items) |level| {
        for (0..level.tilemap.height) |y| {
            for (0..level.tilemap.width) |x| {
                var is_placeholder = false;
                for (level.placeholders.items) |hdr| {
                    if (hdr.position.x == x and hdr.position.y == y) {
                        switch (hdr.entity) {
                            .player => std.debug.print("@", .{}),
                            .exit => std.debug.print("E", .{}),
                            .enemy => std.debug.print("e", .{}),
                            .item => std.debug.print("i", .{}),
                            .npc => std.debug.print("%", .{}),
                        }
                        is_placeholder = true;
                        break;
                    }
                }

                if (!is_placeholder) {
                    std.debug.print("{c}", .{level.tilemap.get(x, y).to_char()});
                }
            }
            std.debug.print("\n", .{});
        }
    }
}
