const std = @import("std");
const Generator = @import("Generator.zig").Generator;
const Context = @import("Context.zig");

const Direction = enum { up, right, down, left };

const Position = struct { x: i32, y: i32 };

const Node = struct {
    const Id = u8;

    id: Id,
    pos: Position,
    directions: std.EnumArray(Direction, Id),
};

const Architecture = std.ArrayList(Node);

const InstructionTag = enum { generate, place_manual };

pub const Instruction = union(InstructionTag) {
    generate: struct {},
    place_manual: struct {},
};

// fn generate(ctx: *Context, instruction: Instruction) Chunk {
//     switch (instruction) {
//         .generate => |_| {
//
//         },
//         .place_manual => |params| {
//         },
//     }
// }
//

fn generate_architecture(rnd: std.Random, max_nodes: usize, diameter: u8) void {
    
}

// pub const RoomGenerator = Generator(Instruction, Chunk, generate);
