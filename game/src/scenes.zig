const std = @import("std");
const Level = @import("pcgmanager").Contents.Level;
const Tile = @import("pcgmanager").Contents.Tile;

const spawn =
    \\######@@#######
    \\#.............#
    \\#.............#
    \\#.............#
    \\######@@#######
    \\..T..........T.
    \\............T..
    \\....T..........
    \\.............T.
    \\..T.......T....
    \\...............
    \\...............
;

pub fn initial_scene(alloc: std.mem.Allocator) !Level {
    var level = try Level.init(alloc, 14, 12);

    var it = std.mem.splitSequence(u8, spawn, "\n");
    var y = 0;
    while (it.next()) |line| {
        for (line, 0..) |char, x| {
            level.tilemap.set(x, y, Tile.from_char(char));
        }
        y += 1;
    }

    level.placeholders.append(.{ .position = .init(6, 10), .entity = .{ .player = {} } });

    level.placeholders.append(.{ .position = .init(4, 2), .entity = .{ .npc = .{
        .name = "Urubu",
        .dialog = "Olá Hercúles",
    } } });

    level.placeholders.append(.{ .position = .init(10, 2), .entity = .{ .item = {} } });

    level.placeholders.append(.{ .position = .init(6, 0), .entity = .{ .exit = {} } });

    level.placeholders.append(.{ .position = .init(7, 0), .entity = .{ .exit = {} } });

    level.room_rects.append(.{ .x = 0, .y = 0, .w = 15, .h = 5 });
}
