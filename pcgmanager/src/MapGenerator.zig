const std = @import("std");
const Context = @import("Context.zig");
const Queue = @import("queue.zig").Queue;

const Self = @This();

const InstructionTag = enum {
    generate,
    place_manual,
};

const Instruction = union(InstructionTag) {
    generate: struct {
        position: Position,
    },
    place_manual: struct {},
};

const Position = struct {
    x: i32,
    y: i32,
};

const Chunk = struct {
    const Tile = enum { plane, ocean };
    tilemap: [10][10]Tile,
    quadrant: Position,
};

const Params = struct {};

const WorkerCtx = struct {
    queue: Queue(InstructionTag),
    instruction: Instruction,
    on_finish: *const fn (self: *WorkerCtx, position: Position, chunk: Chunk) void,
};

cache: std.ArrayHashMap(Position, Chunk),
params: Params,
context: *Context,
instructions: Queue(InstructionTag),
workers: std.ArrayList(std.Thread),
mutex: std.Thread.Mutex,

pub fn init(context: *Context, thread_count: u8, allocator: std.mem.Allocator) !Self {
    var self = Self{};
    self.instructions = .init(.init(allocator));
    self.cache = .init(allocator);
    self.workers = try .init(allocator);
    self.context = context;
    self.params = .{};
    self.mutex = .{};

    for (0..thread_count) |_| {
        const thread = try std.Thread.spawn(.{}, worker_function, .{});
        self.workers.append(thread);
    }

    return .{};
}

pub fn deinit(self: *Self) void {
    for (self.workers.items) |worker|
        worker.join();
    self.workers.deinit();
    self.cache.deinit();
    self.instructions.deinit();
}

pub fn generate(self: Self, instruction: Instruction) void {
    self.instructions.enqueue(instruction);
}

fn worker_function(context: WorkerCtx) void {
    const chunk = Chunk{};
    const pos = instruction.generate.position;
    std.debug.print("Generating {} on thread {}", .{ pos, @intCast(std.Thread.getCurrentId()) });
    self.handle_generated(chunk);
}

fn handle_generated(self: *Self, position: Position, chunk: Chunk) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    self.cache.put(position, chunk);
}
