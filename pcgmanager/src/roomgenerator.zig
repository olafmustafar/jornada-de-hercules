const std = @import("std");
const Generator = @import("Generator.zig").Generator;
const Context = @import("Context.zig");

pub const Tile = enum {
    empty,
    plane,
    mountain,
    sand,
    trees,
    ocean,
    size,

    const chars = std.EnumMap(Tile, u8).init(.{ .empty = ' ', .plane = '.', .ocean = '~', .mountain = '^', .sand = '/', .trees = 'T', .size = 'X' });

    fn toChar(tile: Tile) u8 {
        return chars.get(tile).?;
    }

    fn fromChar(char: u8) Tile {
        for (0..@intFromEnum(Tile.size) + 1) |i| {
            const tile: Tile = @enumFromInt(i);
            if (tile.toChar() == char) {
                return tile;
            }
        }
        return Tile.empty;
    }
};

pub const Room = [8][12]Tile;

const InstructionTag = enum { generate, place_manual };

pub const Instruction = union(InstructionTag) {
    generate: struct {},
    place_manual: struct { room: Room },
};

const rooms = [_][]const u8{
    \\////////////
    \\~~~~~~~~////
    \\////////////
    \\////~~~~~~~~
    \\////////////
    \\////////////
    \\~~~~~~~~////
    \\//////////// 
    ,
    \\^^........^^
    \\^^........^^
    \\....^^^^....
    \\..^^^^^^^^..
    \\..^^^^^^^^..
    \\....^^^^....
    \\^^........^^
    \\^^........^^ 
    ,
    \\TTT.......TT
    \\TTTT.....TTT
    \\TTT....TTTT.
    \\.......TTT..
    \\............
    \\TT..........
    \\TTT.....TTT.
    \\TT.....TTTTT 
    ,
    \\~~~//..//~~~
    \\~~~//..//~~~
    \\/////../////
    \\............
    \\............
    \\/////../////
    \\~~~//..//~~~
    \\~~~//..//~~~ 
};

fn generate(ctx: *Context, instruction: Instruction) Room {
    switch (instruction) {
        .generate => |_| {
            return get_random_room(ctx.random.random());
        },
        .place_manual => |params| {
            return params.room;
        },
    }
}

fn get_random_room(rnd: std.Random) Room {
    var room: Room = undefined;
    const i = rnd.intRangeAtMost(usize, 0, rooms.len - 1);
    var it = std.mem.splitSequence(u8, rooms[i], "\n");

    var row: usize = 0;
    while (it.next()) |line| {
        for (line[0..12], 0..) |char, col| {
            room[row][col] = Tile.fromChar(char);
        }
        row += 1;
    }
    return room;
}

pub const RoomGenerator = Generator(Instruction, Room, generate);
