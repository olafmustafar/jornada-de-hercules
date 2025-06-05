const std = @import("std");
const Generator = @import("Generator.zig").Generator;
const Context = @import("../Context.zig");
const contents = @import("../contents.zig");
const Room = contents.Room;
const Enemy = contents.Enemy;
const Tile = contents.Tile;

const InstructionTag = enum { generate, place_manual };

pub const Instruction = union(InstructionTag) {
    generate: struct {},
    place_manual: Room,
};

const rooms = [_]struct { []const u8, []const struct { usize, usize } }{
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
        &.{ .{ 4, 4 }, .{ 5, 4 } },
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

fn generate(ctx: *Context, instruction: Instruction) Room {
    switch (instruction) {
        .generate => |_| {
            return get_random_room(ctx.random.random(), ctx.gpa) catch {
                unreachable;
            };
        },
        .place_manual => |room| {
            return room;
        },
    }
}

fn get_random_room(rnd: std.Random, alloc: std.mem.Allocator) !Room {
    var room: Room = undefined;
    room.enemies = .init(alloc);

    const room_str, const placeholders = rooms[rnd.uintAtMost(usize, rooms.len - 1)];

    var it = std.mem.splitSequence(u8, room_str, "\n");
    var row: usize = 0;
    while (it.next()) |line| {
        for (line[0..12], 0..) |char, col| {
            room.tilemap[row][col] = Tile.from_char(char);
        }
        row += 1;
    }

    const enemies = get_random_enemy_set(rnd, placeholders.len);
    for (placeholders, enemies) |p, e| {
        try room.enemies.append(.{
            .pos = .{ .x = @intCast(p[0]), .y = @intCast(p[1]) },
            .type = e,
        });
    }

    return room;
}

fn get_random_enemy_set(rnd: std.Random, size: usize) []const Enemy.Type {
    var enemy_set = enemy_sets[rnd.uintAtMost(usize, enemy_sets.len - 1)];
    while (enemy_set.len != size)
        enemy_set = enemy_sets[rnd.uintAtMost(usize, enemy_sets.len - 1)];
    return enemy_set;
}

pub const RoomGenerator = Generator(Instruction, Room, generate);
