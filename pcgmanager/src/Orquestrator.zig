const std = @import("std");
const contents = @import("contents.zig");
const Room = contents.Room;
const Architecture = contents.Architecture;
const Level = contents.Level;
const Pos = contents.Position;
const Direction = contents.Direction;
const Tile = contents.Tile;
const Node = contents.Node;

const Self = @This();

const ContentTag = enum {
    room,
    architecture,
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

pub fn add(self: *Self, content: Content) !void {
    try switch (content) {
        .architecture => |arch| self.architecture = arch,
        .room => |room| self.rooms.append(room),
    };
}

pub fn combine(self: *Self) !Level {
    std.debug.assert(self.architecture != null);
    std.debug.assert(self.rooms.items.len > 0);
    const architecture = &self.architecture.?;

    var arch_min_pos = Pos.init(100, 100);
    var arch_max_pos = Pos.init(-100, -100);
    for (architecture.items) |node| {
        arch_min_pos.x = @min(arch_min_pos.x, node.pos.x);
        arch_min_pos.y = @min(arch_min_pos.y, node.pos.y);
        arch_max_pos.x = @max(arch_max_pos.x, node.pos.x);
        arch_max_pos.y = @max(arch_max_pos.y, node.pos.y);
    }

    const room_w = @typeInfo(@typeInfo(Room).array.child).array.len;
    const size_w = ((arch_max_pos.x - arch_min_pos.x + 1) * (room_w + 1)) + 1;

    const room_h = @typeInfo(Room).array.len;
    const size_h = ((arch_max_pos.y - arch_min_pos.y + 1) * (room_h + 1)) + 1;

    const x_shift = -arch_min_pos.x;
    const y_shift = -arch_min_pos.y;

    var level = try Level.init(self.gpa, @intCast(size_w), @intCast(size_h));

    var room_idx: usize = 0;
    for (architecture.items) |node| {
        const x: usize = @intCast((x_shift + node.pos.x) * (room_w + 1));
        const y: usize = @intCast((y_shift + node.pos.y) * (room_h + 1));

        for (0..(room_w + 2)) |i| {
            const up = level.get(x + i, y);
            const down = level.get(x + i, y + room_h + 1);
            if (tile_is_central(i, room_w)) {
                if (node.directions.get(.up)) {
                    up.* = if (node.entrance == Direction.up) .entrance else .door;
                } else {
                    up.* = .wall;
                }
                if (node.directions.get(.down)) {
                    down.* = if (node.entrance == Direction.down) .entrance else .door;
                } else {
                    down.* = .wall;
                }
            } else {
                up.* = .wall;
                down.* = .wall;
            }
        }

        for (0..(room_h + 2)) |i| {
            const left = level.get(x, y + i);
            const right = level.get(x + room_w + 1, y + i);
            if (tile_is_central(i, room_h)) {
                if (node.directions.get(.left)) {
                    left.* = if (node.entrance == Direction.left) .entrance else .door;
                } else {
                    left.* = .wall;
                }

                if (node.directions.get(.right)) {
                    right.* = if (node.entrance == Direction.right) .entrance else .door;
                } else {
                    right.* = .wall;
                }
            } else {
                left.* = .wall;
                right.* = .wall;
            }
        }

        //add entrance

        const room = self.rooms.items[room_idx];
        for (0..room.len) |ry| {
            for (0..room[ry].len) |rx| {
                level.get(x + rx + 1, y + ry + 1).* = room[ry][rx];
            }
        }

        room_idx = (room_idx + 1) % self.rooms.items.len;
    }

    return level;
}

fn tile_is_central(pos: usize, len: usize) bool {
    return if (len % 2 == 0)
        pos == (len / 2) or pos == ((len / 2) + 1)
    else
        pos == ((len - 1) / 2) + 1;
}
