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

    tilemap: *Tilemap,
    rules: Rules,

    pub fn process(self: *WaveFunctionCollapse) void {
        self.clear_tilemap();

        while (!self.all_collapsed()) {}
    }

    fn clear_tilemap(self: *WaveFunctionCollapse) void {
        for (self.tilemap) |*row| {
            for (row) |*tile| {
                tile = .empty;
            }
        }
    }

    fn entropy(self: WaveFunctionCollapse, pos: Position) f32 {
        const w = self.tilemap.len;
        const h = self.tilemap[0].len;

        const nbrs = [_]Tile{
            if (pos.x - 1 < 0) self.tilemap[pos.x - 1][pos.y] else .empty,
            if (pos.x + 1 >= w) self.tilemap[pos.x + 1][pos.y] else .empty,
            if (pos.y - 1 < 0) self.tilemap[pos.x][pos.y - 1] else .empty,
            if (pos.y + 1 >= h) self.tilemap[pos.x][pos.y + 1] else .empty,
        };

        var sum_w = 0;
        var sum_w_log = 0;
        for (0..Tile.size) |tile_i| {
            var allowed = true;
            for (0..Direction.size) |dir| {
                allowed &= self.rules[nbrs[dir]].neighbors[tile_i][dir];
            }
            if (allowed) {
                const weight = self.rules[tile_i].weight;
                sum_w += weight;
                sum_w_log += weight * @log(weight);
            }
        }

        return @log(sum_w) - (sum_w_log / sum_w);
    }

    fn collapse(self: *WaveFunctionCollapse, pos: Position) void {
        const w = self.tilemap.len;
        const h = self.tilemap[0].len;
        const nbrs = [_]Tile{
            if (pos.x - 1 < 0) self.tilemap[pos.x - 1][pos.y] else .empty,
            if (pos.x + 1 >= w) self.tilemap[pos.x + 1][pos.y] else .empty,
            if (pos.y - 1 < 0) self.tilemap[pos.x][pos.y - 1] else .empty,
            if (pos.y + 1 >= h) self.tilemap[pos.x][pos.y + 1] else .empty,
        };

        //todo
        //
        var sum_w = 0;
        var sum_w_log = 0;
        for (0..Tile.size) |tile_i| {
            var allowed = true;
            for (0..Direction.size) |dir| {
                allowed &= self.rules[nbrs[dir]].neighbors[tile_i][dir];
            }
            if (allowed) {
                const weight = self.rules[tile_i].weight;
                sum_w += weight;
                sum_w_log += weight * @log(weight);
            }
        }
    }

    fn all_collapsed(self: WaveFunctionCollapse) bool {
        for (self.tilemap) |*row| {
            for (row) |tile| {
                if (tile == .empty) {
                    return true;
                }
            }
        }
        return false;
    }
};

pub const MapGenerator = Generator(Instruction, Chunk, generate);
