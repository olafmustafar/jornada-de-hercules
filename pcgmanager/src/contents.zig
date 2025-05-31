const std = @import("std");

pub const Direction = enum {
    up,
    right,
    down,
    left,

    fn inverse(self: Direction) Direction {
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

    fn init(x: i32, y: i32) Position {
        return .{ .x = x, .y = y };
    }

    fn move(self: Position, dir: Direction) Position {
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
    size,

    const chars = std.EnumMap(Tile, u8).init(.{
        .empty = ' ',
        .plane = '.',
        .ocean = '~',
        .mountain = '^',
        .sand = '/',
        .trees = 'T',
        .wall = '█',
        .door = '󰠚',
        .entrance = '@',
        .size = 'X',
    });

    fn toChar(tile: Tile) u8 {
        return chars.get(tile).?;
    }

    fn fromChar(char: u8) Tile {
        for (0..@intFromEnum(Tile.size) + 1) |i| {
            const tile: Tile = @enumFromInt(i);
            if (tile.toChar() == char) {
                return tile;
            }
        }
        return Tile.empty;
    }
};

pub const Room = [8][12]Tile;

pub const Node = struct {
    pos: Position,
    directions: std.EnumArray(Direction, bool),
    is_branch: bool,
};

pub const Architecture = std.ArrayList(Node);

pub const Level = [][]Tile;
