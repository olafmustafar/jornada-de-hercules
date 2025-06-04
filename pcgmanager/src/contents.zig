const std = @import("std");

pub const Direction = enum {
    up,
    right,
    down,
    left,

    pub fn inverse(self: Direction) Direction {
        return switch (self) {
            .up => .down,
            .down => .up,
            .left => .right,
            .right => .left,
        };
    }
};

pub const Position = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Position {
        return .{ .x = x, .y = y };
    }

    pub fn move(self: Position, dir: Direction) Position {
        switch (dir) {
            .up => return .{ .x = self.x, .y = self.y - 1 },
            .down => return .{ .x = self.x, .y = self.y + 1 },
            .left => return .{ .x = self.x - 1, .y = self.y },
            .right => return .{ .x = self.x + 1, .y = self.y },
        }
    }
};

pub const Tile = enum {
    empty,
    plane,
    mountain,
    sand,
    trees,
    ocean,
    wall,
    door,
    entrance,
    size,

    const chars = std.EnumMap(Tile, u8).init(.{
        .empty = ' ',
        .plane = '.',
        .ocean = '~',
        .mountain = '^',
        .sand = '/',
        .trees = 'T',
        .wall = '#',
        .door = 'd',
        .entrance = '@',
        .size = 'X',
    });

    pub fn to_char(tile: Tile) u8 {
        return chars.get(tile).?;
    }

    pub fn from_char(char: u8) Tile {
        for (0..@intFromEnum(Tile.size) + 1) |i| {
            const tile: Tile = @enumFromInt(i);
            if (tile.to_char() == char) {
                return tile;
            }
        }
        return Tile.empty;
    }

    pub fn is_collidable(tile: Tile) bool {
        return tile == .mountain or
            tile == .trees or
            tile == .ocean or
            tile == .wall;
    }
};

pub const Room = [8][12]Tile;

pub const Node = struct {
    pos: Position,
    directions: std.EnumArray(Direction, bool),
    is_branch: bool,
    entrance: ?Direction,
};

pub const Architecture = std.ArrayList(Node);

const Tilemap = struct {
    data: []Tile,
    width: usize,
    height: usize,
    gpa: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, width: usize, height: usize) !Tilemap {
        const self = Tilemap{
            .data = try alloc.alloc(Tile, width * height),
            .width = width,
            .height = height,
            .gpa = alloc,
        };
        for (self.data) |*v| v.* = .empty;
        return self;
    }

    pub fn deinit(self: Tilemap) void {
        self.gpa.free(self.data);
    }

    pub fn get(self: Tilemap, x: usize, y: usize) *Tile {
        return &self.data[(y * self.width) + x];
    }
};

const Enemy = struct {
    const Type = enum {
        slow_chaser,
        fast_chaser,
        still_shooter,
        walking_shooter,
        flyer,
    };

    type: Type,
    health: i32,
    damage: i32,
    velocity: f32,
    shooting_velocity: f32,
};

const Enemies = std.ArrayList(std.ArrayList(Enemy));

pub const Rect = struct { x: f32, y: f32, w: f32, h: f32 };

pub const Level = struct {
    pub fn init(alloc: std.mem.Allocator, width: usize, height: usize) !Level {
        return .{
            .tilemap = try .init(alloc, width, height),
            .room_rects = .init(alloc),
        };
    }
    pub fn deinit(self: Level) void {
        self.tilemap.deinit();
        self.room_rects.deinit();
    }

    tilemap: Tilemap,
    room_rects: std.ArrayList(Rect),
};
