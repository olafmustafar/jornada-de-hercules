const std = @import("std");
const Generator = @import("Generator.zig").Generator;
const Context = @import("../Context.zig");
const Enemy = @import("../contents.zig").Enemies;
const Enemies = @import("../contents.zig").Enemies;

const InstructionTag = enum { generate };

pub const Instruction = union(InstructionTag) {
    generate: struct {},
};


fn generate(ctx: *Context, instruction: Instruction) Room {
    switch (instruction) {
        .generate => |_| {
            return get_random_room(ctx.random.random());
        },
        .place_manual => |room| {
            return room;
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
            room[row][col] = Tile.from_char(char);
        }
        row += 1;
    }
    return room;
}

pub const RoomGenerator = Generator(Instruction, Room, generate);
