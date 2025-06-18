const std = @import("std");

const contents = @import("../contents.zig");
const Room = contents.Room;
const Rooms = contents.Rooms;
const Enemy = contents.Enemy;
const Tile = contents.Tile;
const Context = @import("../Context.zig");
const Generator = @import("Generator.zig").Generator;

const InstructionTag = enum { generate };

pub const Instruction = union(InstructionTag) {
    generate: struct { dummy: i32 = 0 },
};

const Prefab = struct { []const u8, []const struct { usize, usize } };

const prefabs = [_]Prefab{
    .{
        \\............
        \\.##..##..##.
        \\.##..##..##.
        \\.....##.....
        \\.##......##.
        \\.##..##..##.
        \\.##..##..##.
        \\............  
        ,
        &.{ .{ 5, 4 }, .{ 6, 4 } },
    },
    .{ // 012345678901
        \\////////////
        \\//~~////~~//
        \\//~~////~~//
        \\////////////
        \\////////////
        \\//~~////~~//
        \\//~~////~~//
        \\//////////// 
        ,
        &.{ .{ 7, 3 }, .{ 4, 5 } },
    },
    .{ // 012345678901
        \\............
        \\.T~..T~..T~.
        \\.~T..~T..~T.
        \\............
        \\............
        \\.~T..~T..~T.
        \\.T~..T~..T~.
        \\............ 
        ,
        &.{ .{ 4, 3 }, .{ 5, 5 }, .{ 7, 6 } },
    },
    .{ // 012345678901
        \\............
        \\.####..####.
        \\.##......##.
        \\.....##.....
        \\.....##.....
        \\.##......##.
        \\.####.#####.
        \\............ 
        ,
        &.{ .{ 3, 5 }, .{ 8, 2 } },
    },
    .{
        \\////////////
        \\~~~~~~~~////
        \\////////////
        \\////~~~~~~~~
        \\////////////
        \\////////////
        \\~~~~~~~~////
        \\//////////// 
        ,
        &.{ .{ 8, 1 }, .{ 4, 3 }, .{ 8, 6 } },
    },
    .{
        \\^^........^^
        \\^^........^^
        \\....^^^^....
        \\..^^^^^^^^..
        \\..^^^^^^^^..
        \\....^^^^....
        \\^^........^^
        \\^^........^^ 
        ,
        &.{ .{ 8, 2 }, .{ 3, 5 } },
    },
    .{
        \\TTT.......TT
        \\TTTT.....TTT
        \\TTT....TTTT.
        \\.......TTT..
        \\............
        \\TT..........
        \\TTT.....TTT.
        \\TT.....TTTTT 
        ,
        &.{ .{ 3, 3 }, .{ 7, 5 } },
    },
    .{
        \\~~~//..//~~~
        \\~~~//..//~~~
        \\/////../////
        \\............
        \\............
        \\/////...////
        \\~~~//..//~~~
        \\~~~//..//~~~ 
        ,
        &.{ .{ 2, 4 }, .{ 3, 5 }, .{ 5, 7 } },
    },
};

const boss_room = Prefab{
    \\####....####
    \\##........##
    \\#..........#
    \\............
    \\............
    \\#..........#
    \\##........##
    \\####....####
    ,
    &.{.{ 5, 3 }},
};

const enemy_sets = [_][]const Enemy.Type{
    &.{ .flyer, .flyer },
    &.{ .fast_chaser, .fast_chaser },
    &.{ .flyer, .slow_chaser, .flyer },
    &.{ .walking_shooter, .walking_shooter },
    &.{ .shooter, .shooter, .shooter },
    &.{ .fast_chaser, .slow_chaser },
    &.{ .fast_chaser, .slow_chaser },
    &.{ .walking_shooter, .flyer, .flyer },
};

fn generate(ctx: *Context, instruction: Instruction) Rooms {
    switch (instruction) {
        .generate => |_| {
            return generate_rooms(ctx.random.random(), ctx.gpa) catch {
                unreachable;
            };
        },
    }
}

fn generate_rooms(rnd: std.Random, alloc: std.mem.Allocator) !Rooms {
    var rooms = Rooms{
        .normal_rooms = .init(alloc),
        .boss_room = undefined,
    };

    for (prefabs) |prefab| {
        const room_str, const placeholders = prefab;
        var room = Room{
            .enemies = .init(alloc),
            .type = .normal_room,
            .tilemap = create_tilemap_from_string(room_str),
        };
        const enemies = get_random_enemy_set(rnd, placeholders.len);
        for (placeholders, enemies) |p, e| {
            try room.enemies.append(.{
                .pos = .{ .x = @intCast(p[0]), .y = @intCast(p[1]) },
                .type = e,
            });
        }
        try rooms.normal_rooms.append(room);
    }

    const room_str, const placeholders = boss_room;
    var room = Room{
        .enemies = .init(alloc),
        .type = .boss_room,
        .tilemap = create_tilemap_from_string(room_str),
    };
    for (placeholders) |p| {
        try room.enemies.append(.{
            .pos = .{ .x = @intCast(p[0]), .y = @intCast(p[1]) },
            .type = .boss,
        });
    }
    rooms.boss_room = room;

    return rooms;
}

fn create_tilemap_from_string(str: []const u8) [8][12]Tile {
    var tilemap: [8][12]Tile = undefined;
    var it = std.mem.splitSequence(u8, str, "\n");
    var row: usize = 0;
    while (it.next()) |line| {
        for (line[0..12], 0..) |char, col| {
            tilemap[row][col] = Tile.from_char(char);
        }
        row += 1;
    }
    return tilemap;
}

fn get_random_enemy_set(rnd: std.Random, size: usize) []const Enemy.Type {
    var enemy_set = enemy_sets[rnd.uintAtMost(usize, enemy_sets.len - 1)];
    while (enemy_set.len != size)
        enemy_set = enemy_sets[rnd.uintAtMost(usize, enemy_sets.len - 1)];
    return enemy_set;
}

pub const RoomGenerator = Generator(Instruction, Rooms, generate);
