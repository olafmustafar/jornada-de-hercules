const std = @import("std");
//
// const WaveFunctionCollapse = struct {
//     const Direction = enum { up, right, down, left, size };
//     const Rule = struct {
//         neighbors: [@intFromEnum(Tile.size)][Direction.size]bool,
//         weight: u8,
//     };
//     const Rules = [@intFromEnum(Tile.size)]Rule;
//
//     tilemap: *Tilemap,
//     rules: Rules,
//     rnd: std.Random.DefaultPrng,
//
//     pub fn init(tilemap: *Tilemap, pattern: []u8) void {
//         var rule: Rules = undefined;
//         for (pattern) |c| { 
//             cfr
//         }
//
//     }
//
//     pub fn process(self: *WaveFunctionCollapse) void {
//         self.rnd = std.Random.DefaultPrng.init(0);
//         self.clear_tilemap();
//
//         var min_entropy = 100;
//         var min_entropy_pos: Position = undefined;
//         while (!self.all_collapsed()) {
//             for (0..self.tilemap.len) |x| {
//                 for (0..self.tilemap[x]) |y| {
//                     const pos = Position{ .x = x, .y = y };
//                     const entr = self.entropy(pos);
//                     if (entr < min_entropy) {
//                         min_entropy = 100;
//                         min_entropy_pos = pos;
//                     }
//                 }
//             }
//
//             if (!collapse(min_entropy_pos)) {
//                 std.debug.print("conflict!");
//                 self.clear_tilemap();
//             }
//         }
//     }
//
//     fn clear_tilemap(self: *WaveFunctionCollapse) void {
//         for (self.tilemap) |*row| {
//             for (row) |*tile| {
//                 tile = .empty;
//             }
//         }
//     }
//
//     fn entropy(self: WaveFunctionCollapse, pos: Position) f32 {
//         const w = self.tilemap.len;
//         const h = self.tilemap[0].len;
//
//         // const nbrs : std.EnumArray(Direction,Tile) = .init(.);
//         const nbrs = [_]Tile{
//             if (pos.x - 1 < 0) self.tilemap[pos.x - 1][pos.y] else .empty,
//             if (pos.x + 1 >= w) self.tilemap[pos.x + 1][pos.y] else .empty,
//             if (pos.y - 1 < 0) self.tilemap[pos.x][pos.y - 1] else .empty,
//             if (pos.y + 1 >= h) self.tilemap[pos.x][pos.y + 1] else .empty,
//         };
//
//         var sum_w = 0;
//         var sum_w_log = 0;
//         for (0..Tile.size) |tile_i| {
//             var allowed = true;
//             for (0..Direction.size) |dir| {
//                 allowed &= self.rules[nbrs[dir]].neighbors[tile_i][dir];
//             }
//             if (allowed) {
//                 const weight = self.rules[tile_i].weight;
//                 sum_w += weight;
//                 sum_w_log += weight * @log(weight);
//             }
//         }
//
//         return @log(sum_w) - (sum_w_log / sum_w);
//     }
//
//     fn collapse(self: *WaveFunctionCollapse, pos: Position) bool {
//         const w = self.tilemap.len;
//         const h = self.tilemap[0].len;
//         const nbrs = [_]Tile{
//             if (pos.x - 1 < 0) self.tilemap[pos.x - 1][pos.y] else .empty,
//             if (pos.x + 1 >= w) self.tilemap[pos.x + 1][pos.y] else .empty,
//             if (pos.y - 1 < 0) self.tilemap[pos.x][pos.y - 1] else .empty,
//             if (pos.y + 1 >= h) self.tilemap[pos.x][pos.y + 1] else .empty,
//         };
//
//         var sum_w = 0;
//         var allowed = [_]bool{false} ** Tile.size;
//         for (0..Tile.size) |tile_i| {
//             for (0..Direction.size) |dir| {
//                 allowed &= self.rules[nbrs[dir]].neighbors[tile_i][dir];
//             }
//             if (allowed) {
//                 sum_w += self.rules[tile_i].weight;
//             }
//         }
//
//         if (std.mem.allEqual(bool, allowed, false)) {
//             return false;
//         }
//
//         const chance = self.rnd.random().float();
//         var sum_w_2 = 0;
//         for (0..allowed.len) |tile_i| {
//             if (allowed[tile_i]) {
//                 if (chance < (self.rules[tile_i].weight / sum_w)) {
//                     self.tilemap[pos.x][pos.y] = @enumFromInt(tile_i);
//                     return true;
//                 }
//                 sum_w_2 += self.rules[tile_i].weight;
//             }
//         }
//         return false;
//     }
//
//     fn all_collapsed(self: WaveFunctionCollapse) bool {
//         for (self.tilemap) |*row| {
//             for (row) |tile| {
//                 if (tile == .empty) {
//                     return true;
//                 }
//             }
//         }
//         return false;
//     }
// };
//
// pub const MapGenerator = Generator(Instruction, Chunk, generate);
