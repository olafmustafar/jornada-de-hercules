const std = @import("std");
const Generator = @import("Generator.zig").Generator;

const InstructionTag = enum { generate, place_manual };

pub const Instruction = union(InstructionTag) {
    generate: struct { position: Position },
    place_manual: struct { chunk: Chunk },
};

pub const Tile = enum { empty, plane, mountain, sand, trees, ocean, size };
pub const Tilemap = [10][10]Tile;
pub const Position = struct { x: i32, y: i32 };
pub const Chunk = struct {
    quadrant: Position,
    tilemap: Tilemap,
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

const WaveFunctionCollapse = struct {
    const Direction = enum { up, right, down, left, size };
    const Rule = struct {
        neighbors: [@intFromEnum(Tile.size)][Direction.size]bool,
        weight: u8,
    };
    const Rules = [@intFromEnum(Tile.size)]Rule;
    // const Prefab = [4][3]Tile;

    tilemap: *Tilemap,
    rules: Rules,

    // pub fn process() void {
    //
    // }

    fn clear_tilemap(tilemap: *Tilemap) void {
        for (tilemap) |*row| {
            for (row) |*tile|
                tile = .empty;
        }
    }

    // fn lowest_entropy(tilemap: *Tilemap) Position {}

    fn entropy(self: WaveFunctionCollapse, pos: Position) f32 {
        const w = self.tilemap.len;
        const h = self.tilemap[0].len;

        const nbrs = [_]Tile{
            if (pos.x - 1 < 0) self.tilemap[pos.x - 1][pos.y] else .empty,
            if (pos.x + 1 >= w) self.tilemap[pos.x + 1][pos.y] else .empty,
            if (pos.y - 1 < 0) self.tilemap[pos.x][pos.y - 1] else .empty,
            if (pos.y + 1 >= h) self.tilemap[pos.x][pos.y + 1] else .empty,
        };

        var possibilities = [_]bool{true} ** Tile.size;
        for (0..possibilities.len) |tile| {
            for (0..Direction.size) |dir| {
                possibilities[tile] &= self.rules[nbrs[dir]].neighbors[tile][dir];
            }
        }

        var sum_i = 0;
        var sum_w = 0;
        for (0..possibilities.len) |tile_i| {
            if (possibilities[tile_i]) {
                sum_i += 1;
                sum_w += self.rules[tile_i].weight;
            }
        }
        //
        //
        // shannon_entropy_for_square =
        //   log(sum(weight)) - ((sum(weight) * log(weight)) / sum(weight))
    }

    //
    // fn collapse(tilemap: *Chunk.Tilemap) void {
    //
    // }

    // fn all_collapsed(tilemap : * Chunk.Tilemap ) void { }
};

pub const MapGenerator = Generator(Instruction, Chunk, generate);
