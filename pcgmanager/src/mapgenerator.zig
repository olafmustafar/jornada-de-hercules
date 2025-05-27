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
    const Rule = struct { a: Tile, b: Tile };
    const Weights = [@intFromEnum(Tile.size)]f32;
    const rules = [_]Rule{
        .{ .a = .plane, .b = .plane },
        .{ .a = .plane, .b = .mountain },
        .{ .a = .plane, .b = .sand },
        .{ .a = .plane, .b = .trees },
        .{ .a = .plane, .b = .ocean },
        .{ .a = .sand, .b = .sand },
        .{ .a = .sand, .b = .ocean },
        .{ .a = .sand, .b = .plane },
        .{ .a = .trees, .b = .trees },
        .{ .a = .trees, .b = .plane },
        .{ .a = .trees, .b = .mountain },
        .{ .a = .mountain, .b = .mountain },
        .{ .a = .mountain, .b = .trees },
        .{ .a = .mountain, .b = .plane },
        .{ .a = .ocean, .b = .ocean },
        .{ .a = .ocean, .b = .sand },
        .{ .a = .ocean, .b = .plane },
    };

    weights: Weights,
    tilemap: *Tilemap,
    // pub fn process(probabilities: ProbabilitiesVector, tilemap: *Chunk.Tilemap) void {
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
        const neighbors = [_]Tile{
            if (pos.x + 1 >= w) self.tilemap[pos.x + 1][pos.y] else .empty,
            if (pos.x - 1 < 0) self.tilemap[pos.x - 1][pos.y] else .empty,
            if (pos.y + 1 >= h) self.tilemap[pos.x][pos.y + 1] else .empty,
            if (pos.y - 1 < 0) self.tilemap[pos.x][pos.y - 1] else .empty,
        };

        const allowed_tiles = [_]bool{false} ** Tile.size;

        for (neighbors) |tile| {
            for (rules) |rule| {
                if (rule.a == tile) {
                    allowed_tiles[@intFromEnum(rule.b)] = true;
                }
            }
        }

        for(allowed_tiles, self.weights) |allowed, weight|{
            if( allowed ){
                weight 
            }
        }

        // shannon_entropy_for_square =
        //   log(sum(weight)) -
        //   (sum(weight) * log(weight)) / sum(weight))
    }

    //
    // fn collapse(tilemap: *Chunk.Tilemap) void {
    //
    // }

    // fn all_collapsed(tilemap : * Chunk.Tilemap ) void { }
};

pub const MapGenerator = Generator(Instruction, Chunk, generate);
