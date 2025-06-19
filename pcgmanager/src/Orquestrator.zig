const std = @import("std");
const contents = @import("contents.zig");
const Room = contents.Room;
const Rooms = contents.Rooms;
const Architecture = contents.Architecture;
const Level = contents.Level;
const Tilemap = contents.Tilemap;
const Pos = contents.Position;
const Direction = contents.Direction;
const Tile = contents.Tile;
const Node = contents.Node;
const EnemiesPerDifficulty = contents.EnemiesPerDifficulty;

const Self = @This();

const ContentTag = enum {
    rooms,
    architecture,
    enemies_per_difficulty,
};

const Content = union(ContentTag) {
    rooms: Rooms,
    architecture: Architecture,
    enemies_per_difficulty: EnemiesPerDifficulty,
};

rooms: ?Rooms,
enemies_per_difficulty: ?EnemiesPerDifficulty,
architecture: ?Architecture,
gpa: std.mem.Allocator,

const spawn_tilemap =
    \\   #....#   
    \\   #....#   
    \\   #....#   
    \\   #....#   
    \\   ######   
    \\            
    \\            
    \\            
;

pub fn init(alloc: std.mem.Allocator) Self {
    return .{ .rooms = null, .architecture = null, .enemies_per_difficulty = null, .gpa = alloc };
}

pub fn add(self: *Self, content: Content) void {
    switch (content) {
        .architecture => |arch| {
            if (self.architecture) |old_arch| old_arch.deinit();
            self.architecture = arch;
        },

        .rooms => |rooms| {
            if (self.rooms) |old_rooms| old_rooms.deinit();
            self.rooms = rooms;
        },

        .enemies_per_difficulty => |enemies_per_difficulty| {
            if (self.enemies_per_difficulty) |enemies| enemies.deinit();
            self.enemies_per_difficulty = enemies_per_difficulty;
        },
    }
}

pub fn combine(self: *Self) !Level {
    return try self.combine_impl(self.architecture.?, self.rooms.?, self.enemies_per_difficulty.?);
}

fn combine_impl(self: Self, architecture: Architecture, rooms: Rooms, enemies_map: EnemiesPerDifficulty) !Level {
    var arch_min_pos = Pos.init(100, 100);
    var arch_max_pos = Pos.init(-100, -100);
    for (architecture.items) |node| {
        arch_min_pos.x = @min(arch_min_pos.x, node.pos.x);
        arch_min_pos.y = @min(arch_min_pos.y, node.pos.y);
        arch_max_pos.x = @max(arch_max_pos.x, node.pos.x);
        arch_max_pos.y = @max(arch_max_pos.y, node.pos.y);
    }

    const room_w = @typeInfo(@typeInfo(@FieldType(Room, "tilemap")).array.child).array.len;
    const room_h = @typeInfo(@FieldType(Room, "tilemap")).array.len;
    const size_w = ((arch_max_pos.x - arch_min_pos.x + 1) * (room_w + 1)) + 1;
    const size_h = ((arch_max_pos.y - arch_min_pos.y + 1) * (room_h + 1)) + 1;
    const x_shift = -arch_min_pos.x;
    const y_shift = -arch_min_pos.y;

    var level = try Level.init(self.gpa, @intCast(size_w), @intCast(size_h));

    var room_idx: usize = 0;
    for (architecture.items) |*node| {
        const x: usize = @intCast((x_shift + node.pos.x) * (room_w + 1));
        const y: usize = @intCast((y_shift + node.pos.y) * (room_h + 1));

        try level.room_rects.append(.{
            .x = @as(f32, @floatFromInt(x)) + 0.5,
            .y = @as(f32, @floatFromInt(y)) + 0.5,
            .w = room_w + 1,
            .h = room_h + 1,
        });

        if (node.is_spawn) {
            var tilemap = try Tilemap.from_string(self.gpa, spawn_tilemap);
            defer tilemap.deinit();
            try level.placeholders.append(.{ .position = .init(@as(i32, @intCast(x)) + 5, @as(i32, @intCast(y)) + 2), .entity = .{ .player = {} } });
            for (0..tilemap.width) |rx| {
                for (0..tilemap.height) |ry| {
                    level.tilemap.set(x + rx + 1, y + ry + 1, tilemap.get(rx, ry).*);
                }
            }
            continue;
        }

        const room = if (node.exit == null) rooms.normal_rooms.items[room_idx] else rooms.boss_room;
        for (0..room_h + 2) |ry| {
            for (0..room_w + 2) |rx| {
                if (ry == 0 or ry == room_h + 1 or rx == 0 or rx == room_w + 1) {
                    level.tilemap.set(x + rx, y + ry, .wall);
                } else {
                    level.tilemap.set(x + rx, y + ry, room.tilemap[ry - 1][rx - 1]);
                }
            }
        }

        var it = node.directions.iterator();
        while (it.next()) |pair| {
            if (pair.value.*) {
                try place_door(&level, @intCast(x), @intCast(y), pair.key);
            }
        }

        if (node.exit) |exit_dir| {
            try place_exit(&level, @intCast(x), @intCast(y), exit_dir);
        }

        for (room.enemies.items) |placeholder| {
            const enemies = &enemies_map.items[node.difficulty_class];
            try level.placeholders.append(.{
                .position = .{
                    .x = placeholder.pos.x + @as(i32, @intCast(x)) + 1,
                    .y = placeholder.pos.y + @as(i32, @intCast(y)) + 1,
                },
                .entity = .{ .enemy = enemies.get(placeholder.type) },
            });
        }

        room_idx = (room_idx + 1) % rooms.normal_rooms.items.len;
    }

    return level;
}

fn place_door(level: *Level, x: i32, y: i32, direction: Direction) !void {
    try place_door_impl(level, x, y, direction, false);
}

fn place_exit(level: *Level, x: i32, y: i32, direction: Direction) !void {
    try place_door_impl(level, x, y, direction, true);
}

fn place_door_impl(level: *Level, x: i32, y: i32, direction: Direction, is_exit: bool) !void {
    var doors: [2]Pos = undefined;
    const room_w = @typeInfo(@typeInfo(@FieldType(Room, "tilemap")).array.child).array.len;
    const room_h = @typeInfo(@FieldType(Room, "tilemap")).array.len;
    switch (direction) {
        .up => {
            doors[0] = .init(x + (room_w / 2), y);
            doors[1] = .init(x + (room_w / 2) + 1, y);
        },
        .down => {
            doors[0] = .init(x + (room_w / 2), y + room_h + 1);
            doors[1] = .init(x + (room_w / 2) + 1, y + room_h + 1);
        },
        .left => {
            doors[0] = .init(x, y + (room_h / 2));
            doors[1] = .init(x, y + (room_h / 2) + 1);
        },
        .right => {
            doors[0] = .init(x + room_w + 1, y + (room_h / 2));
            doors[1] = .init(x + room_w + 1, y + (room_h / 2) + 1);
        },
    }
    level.tilemap.set(@intCast(doors[0].x), @intCast(doors[0].y), .door);
    level.tilemap.set(@intCast(doors[1].x), @intCast(doors[1].y), .door);
    if (is_exit) {
        try level.placeholders.append(.{ .position = doors[0], .entity = .{ .exit = direction } });
        try level.placeholders.append(.{ .position = doors[1], .entity = .{ .exit = direction } });
    }
}

fn tile_is_central(pos: usize, len: usize) bool {
    return if (len % 2 == 0)
        pos == (len / 2) or pos == ((len / 2) + 1)
    else
        pos == ((len - 1) / 2) + 1;
}
