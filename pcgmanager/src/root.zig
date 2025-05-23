const std = @import("std");
const Queue = @import("queue.zig").Queue;
const MapGenerator = @import("MapGenerator.zig");

const Position = struct {
    x: i32,
    y: i32,
};

const InstructionTag = enum {
    map,
    enemies,
};

const Instruction = union(InstructionTag) {
    map: MapGenerator.Instruction,
    enemies: struct {},
};


const Level = struct {};

const Orquestrator = struct {
    pub fn addChunk(_: Orquestrator, _: MapGenerator.Chunk) void {}
    pub fn Orquestrate(_: Orquestrator) Level {}
};

const PCGManager = struct {};
