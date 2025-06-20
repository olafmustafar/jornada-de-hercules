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

    //max 24 characters
    try level.placeholders.append(.{ .position = .init(8, 5), .entity = .{ .npc = .{
        .name = "Rei Euristeu",
        .dialog = &[_][]const u8{
            \\
            \\Hércules!
            ,
            \\Esse será 
            \\teu primeiro trabalho:
            \\Enfrenta o Leão de Nemeia!
            ,
            \\Um leão, dizem os camponeses
            \\Não é criatura de carne comum,
            ,
            \\Suas garras dilaceram ferro.
            \\Sua pele… impenetrável
            ,
            \\Vai, Hércules!
            \\O tempo dos deuses
            \\já não te protege
        },
    } } });

    try level.placeholders.append(.{ .position = .init(13, 5), .entity = .{ .item = {} } });
    try level.placeholders.append(.{ .position = .init(10, 4), .entity = .{ .exit = .up } });
    try level.placeholders.append(.{ .position = .init(11, 4), .entity = .{ .exit = .up } });

    try level.room_rects.append(.{ .x = 4, .y = 4, .w = 14, .h = 6 });
    try level.room_rects.append(.{ .x = 4, .y = 10, .w = 14, .h = 8 });

    return level;
}

pub fn test_scene(alloc: std.mem.Allocator) !Level {
    const empty =
        \\##############
        \\#............#
        \\#............#
        \\#............#
        \\#............#
        \\#............#
        \\#............#
        \\#............#
        \\#............#
        \\##############
    ;

    var level = try Level.from_string(alloc, empty);

    try level.room_rects.append(.{ .x = 0, .y = 0, .w = 14, .h = 10 });

    try level.placeholders.append(.{ .position = .init(6, 4), .entity = .{ .player = {} } });

    try level.placeholders.append(.{ .position = .init(6, 2), .entity = .{ .enemy = .{
        .type = .boss,
        .health = 0.1,
        .damage = 0.1,
        .velocity = 0.1,
        .shooting_velocity = 0.1,
    } } });

    return level;
}
