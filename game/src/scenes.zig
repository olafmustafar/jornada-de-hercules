const std = @import("std");
const Level = @import("pcgmanager").Contents.Level;
const Tile = @import("pcgmanager").Contents.Tile;

const spawn =
    \\TTTTTTTTT#..#TTTTTTTTT
    \\TTTTTTTTT#..#TTTTTTTTT
    \\TTTTTTTTT#..#TTTTTTTTT
    \\TTTTTTTTT#..#TTTTTTTTT
    \\TTTT######dd######TTTT
    \\TTTT#............#TTTT
    \\TTTT#............#TTTT
    \\TTTT#............#TTTT
    \\TTTT#............#TTTT
    \\TTTT######dd######TTTT
    \\TTT...T.........TTTTTT
    \\TTTTT............TTTTT
    \\TTT.....T.........TTTT
    \\TTTT............T.TTTT
    \\TTTT.TT.......T.TTTTTT
    \\TTT...............TTTT
    \\TTTT................TT
    \\TTT...TT.T....T.TT.TTT
    \\TTTTTTTTTT..TTTTTTTTTT
    \\TTTTTTTTTT.TTTTTTTTTTT
    \\TTTTTTTTTTTTTTTTTTTTTT
    \\TTTTTTTTTTTTTTTTTTTTTT
;

pub fn initial_scene(alloc: std.mem.Allocator) !Level {
    var level = try Level.from_string(alloc, spawn);

    try level.placeholders.append(.{ .position = .init(10, 14), .entity = .{ .player = {} } });

    try level.placeholders.append(.{ .position = .init(8, 5), .entity = .{ .npc = .{
        .name = "Urubu",
        .dialog = "Olá Hercúles",
    } } });

    try level.placeholders.append(.{ .position = .init(13, 5), .entity = .{ .item = {} } });
    try level.placeholders.append(.{ .position = .init(10, 4), .entity = .{ .exit = .up } });
    try level.placeholders.append(.{ .position = .init(11, 4), .entity = .{ .exit = .up } });

    try level.room_rects.append(.{ .x = 4, .y = 4, .w = 14, .h = 6 });
    try level.room_rects.append(.{ .x = 4, .y = 10, .w =14, .h = 8 });

    return level;
}
