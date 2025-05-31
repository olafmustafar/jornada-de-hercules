const std = @import("std");
const contents = @import("contents.zig");
const Room = contents.Room;
const Architecture = contents.Architecture;
const Level = contents.Level;
const Pos = contents.Position;
const Tile = contents.Tile;
const Node = contents.Node;

const Self = @This();

const ContentTag = enum {
    room,
    arch,
};

const Content = union(ContentTag) {
    room: Room,
    architecture: Architecture,
};

rooms: std.ArrayList(Room),
architecture: ?Architecture,
gpa: std.mem.Allocator,

pub fn init(alloc: std.mem.Allocator) Self {
    return .{ .rooms = .init(alloc), .architecture = null, .gpa = alloc };
}

pub fn add(self: *Self, content: Content) void {
    switch (content) {
        .architecture => |arch| self.architecture = arch,
        .room => |room| self.rooms.append(room),
    }
}

pub fn combine(self: *Self) Level {
    std.debug.assert(self.architecture);
    std.debug.assert(self.rooms.items.len > 0);

    var arch_min_pos = Pos.init(100, 100);
    var arch_max_pos = Pos.init(-100, -100);
    for (self.architecture) |node| {
        arch_min_pos.x = @min(arch_min_pos.x, node.pos.x);
        arch_min_pos.y = @min(arch_min_pos.y, node.pos.y);
        arch_max_pos.x = @max(arch_max_pos.x, node.pos.x);
        arch_max_pos.y = @max(arch_max_pos.y, node.pos.y);
    }

    const room_w = @typeInfo(@typeInfo(Room).array.child).array.len;
    const size_w = ((arch_max_pos.x - arch_min_pos.x) * (room_w + 1)) + 1;

    const room_h = @typeInfo(Room).array.len;
    const size_h = ((arch_max_pos.y - arch_min_pos.y) * (room_h + 1)) + 1;

    var level: Level = self.gpa.alloc([size_w]Tile, size_h);

    var room_idx : usize = 0;
    for (self.architecture) |node| {
        const x = (arch_min_pos.x + node.pos.x) * (room_w + 1);
        const y = (arch_min_pos.y + node.pos.y) * (room_h + 1);

        for (0..(room_w + 2)) |i| {
            const tile: Tile = if (tile_is_central(i, room_w)) .door else .wall;
            level[y][x + i] = tile;
            level[y + room_h + 2][x + i] = tile;
        }

        for (0..(room_h + 2)) |i| {
            const tile: Tile = if (tile_is_central(i, room_w)) .door else .wall;
            level[y + i][x] = tile;
            level[y + i][x + room_w + 2] = tile;
        }

        const room = self.rooms.items[room_idx];
        for(0..room.len) |rx| {
            for(0..room[x]) |ry| {
                level[y+ry][x+rx];
            }
        }


        room_idx = ( room_idx + 1 ) % self.rooms.items.len;
    }
}

fn tile_is_central(pos: usize, len: usize) bool {
    return if (len % 2 == 0)
        pos == (len / 2) or pos == ((len / 2) + 1)
    else
        pos == ((len - 1) / 2) + 1;
}
