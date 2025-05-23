const std = @import("std");
const Queue = @import("queue.zig").Queue;

const Self = @This();

const Chunk = struct {
    tilemap: [10][10]Tile = undefined,
    quadrant: struct { x: u8, y: u8 },
    const Tile = enum { plane, ocean };
};

const InstructionTag = enum {
    generate,
    place_manual,
};

const Instruction = union(InstructionTag) {
    generate: struct {},
    place_manual: struct {},
};

instructions: Queue(InstructionTag),

const Worker = struct {
    thread: std.Thread,
    callback: *const fn (chunk: Chunk) void,

    // pub fn init(callback: *const fn (chunk: Chunk) void) Worker {}

    fn generate() void {}
};

const Cache = struct {};
const Params = struct {};

pub fn init(allocator: std.mem.Allocator) Self {
    return .{ .instructions = .init(allocator) };
}

pub fn generate(self: Self, instruction: Instruction) void {
    self.instructions.enqueue(instruction);
}
