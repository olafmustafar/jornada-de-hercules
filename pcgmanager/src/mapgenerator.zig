const std = @import("std");
const Generator = @import("Generator.zig").Generator;

const InstructionTag = enum { generate, place_manual };

pub const Instruction = union(InstructionTag) {
    generate: struct { position: Position },
    place_manual: struct { chunk: Chunk },
};

pub const Position = struct { x: i32, y: i32 };

pub const Chunk = struct {
    const Tile = enum { plane, ocean };
    tilemap: [10][10]Tile,
    quadrant: Position,
};

fn generate(instruction: Instruction) Chunk {
    switch (instruction) {
        .generate => |params| {
            var chunk: Chunk = undefined;
            chunk.quadrant = params.position;
            for (0..chunk.tilemap.len) |l| {
                for (0..chunk.tilemap[l].len) |r| {
                    chunk.tilemap[l][r] = .plane;
                }
            }
            return chunk;
        },
        .place_manual => |params| {
            return params.chunk;
        },
    }
}

pub const MapGenerator = Generator(Instruction, Chunk, generate);
