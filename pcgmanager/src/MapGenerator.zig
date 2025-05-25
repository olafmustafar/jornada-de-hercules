const std = @import("std");
const Context = @import("Context.zig");

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

const Worker = struct {
    const FinishFn = *const fn (pos: Position, chunk: Chunk) void;
    const SharedContext = struct {
        const State = enum { wait_instr, work, finish };
        instruction: Instruction,
        state: State,
        on_finish: FinishFn,
        cvar: std.Thread.Condition,
        mutex: std.Thread.Mutex,
    };

    shared_context: *SharedContext,
    thread: std.Thread,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, on_finish: FinishFn) !Worker {
        const shared = try allocator.create(SharedContext);
        shared.* = .{
            .instruction = undefined,
            .state = .wait_instr,
            .on_finish = on_finish,
            .cvar = .{},
            .mutex = .{},
        };

        return .{
            .thread = try std.Thread.spawn(.{}, worker_function, .{shared}),
            .shared_context = shared,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Worker) void {
        const shared = self.shared_context;
        {
            shared.mutex.lock();
            defer shared.mutex.unlock();
            shared.state = .finish;
        }
        self.thread.join();
        self.allocator.destroy(shared);
    }

    fn start(self: *Worker, instruction: Instruction) void {
        var shared = self.shared_context;
        {
            shared.mutex.lock();
            defer shared.mutex.unlock();
            shared.instruction = instruction;
            shared.state = 1;
        }
        shared.cvar.signal();
    }

    fn worker_function(ctx: *SharedContext) void {
        ctx.mutex.lock();
        defer ctx.mutex.unlock();
        while (true) {
            switch (ctx.state) {
                .wait_instr => continue,
                .work => worker_generate(ctx),
                .finish => break,
            }
            ctx.cvar.wait(&ctx.mutex);
        }
    }

    fn worker_generate(ctx: *SharedContext) void {
        const chunk = Chunk{};
        const pos = ctx.instruction.generate.position;
        std.debug.print("Generating {} on thread {}", .{ pos, @intCast(std.Thread.getCurrentId()) });
        ctx.on_finish(pos, chunk);
        ctx.state = .wait_instr;
    }
};

const Data = struct {
    cache: std.ArrayHashMap(Position, Chunk),
    params: Params,
    context: *Context,
    queue: std.ArrayList(Instruction),
    workers: std.ArrayList(std.Thread),
    mutex: std.Thread.Mutex,
};

data: *Data,
allocator: std.mem.Allocator,

pub fn init(context: *Context, worker_count: u8, allocator: std.mem.Allocator) !Self {
    var data = try allocator.create(Data);
    data.* = Data{
        .queue = .init(allocator),
        .cache = .init(allocator),
        .workers = .init(allocator),
        .context = context,
        .params = .{},
        .mutex = .{},
    };

    for (0..worker_count) |_|
        data.workers.append(Worker.init(allocator, handle_generated));

    return .{ .allocator = allocator, .data = data };
}

pub fn deinit(self: *Self) void {
    var data = self.data;
    for (&data.workers.items) |*worker|
        worker.deinit();
    data.workers.deinit();
    data.cache.deinit();
    data.queue.deinit();

    self.allocator.destroy(data);
    self.* = undefined;
}

pub fn generate(self: Self, instruction: Instruction) void {
    self.data.queue.insert(0, instruction);
}

fn handle_generated(position: Position, chunk: Chunk) void {
    self.data.cache.put(position, chunk);
}
