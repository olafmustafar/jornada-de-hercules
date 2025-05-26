const std = @import("std");
const Context = @import("Context.zig");
const ThreadSafe = @import("threadsafe.zig").ThreadSafe;

const Self = @This();

const InstructionTag = enum { generate, place_manual };

pub const Instruction = union(InstructionTag) {
    generate: struct { position: Position },
    place_manual: struct {},
};

pub const Position = struct { x: i32, y: i32 };

pub const Chunk = struct {
    const Tile = enum { plane, ocean };
    tilemap: [10][10]Tile,
    quadrant: Position,
};

const Params = struct {};

const Worker = struct {
    const SharedContext = struct {
        const State = enum { initializing, waiting, working };
        generator_context: *GeneratorContext,
        should_finish: ThreadSafe(bool),
        state: ThreadSafe(State),
    };

    shared_context: *SharedContext,
    thread: std.Thread,
    allocator: std.mem.Allocator,

    fn init(allocator: std.mem.Allocator, generator_context: *GeneratorContext) !Worker {
        const shared = try allocator.create(SharedContext);
        shared.* = .{
            .generator_context = generator_context,
            .should_finish = .init(false),
            .state = .init(.initializing),
        };

        return .{
            .thread = try std.Thread.spawn(.{}, worker_function, .{shared}),
            .shared_context = shared,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Worker) void {
        const shared = self.shared_context;
        shared.should_finish.set(true);
        shared.generator_context.cv.signal();
        self.thread.join();
        self.allocator.destroy(shared);
    }

    pub fn wait_until_completed(self: *Worker) void {
        const gc = self.shared_context.generator_context;
        {
            gc.mutex.lock();
            defer gc.mutex.unlock();
            while (gc.queue.items.len != 0 or self.shared_context.state.get() != .waiting) {
                std.debug.print("wait for finish\n", .{});
                gc.cv.wait(&gc.mutex);
            }
            std.debug.print("wait for finish OK\n", .{});
        }
    }

    fn worker_function(ctx: *SharedContext) void {
        var instruction_opt: ?Instruction = null;
        loop: while (true) {
            {
                ctx.generator_context.mutex.lock();
                defer ctx.generator_context.mutex.unlock();
                if (ctx.generator_context.queue.items.len == 0 and ctx.should_finish.get() == false) {
                    std.debug.print("{}: waiting for new instruction or finish command\n", .{@as(i32,@intCast(std.Thread.getCurrentId()))});
                    ctx.state.set(.waiting);
                }
            }
            ctx.generator_context.cv.signal();

            {
                ctx.generator_context.mutex.lock();
                defer ctx.generator_context.mutex.unlock();
                while (ctx.generator_context.queue.items.len == 0 and ctx.should_finish.get() == false) {
                    ctx.generator_context.cv.wait(&ctx.generator_context.mutex);
                }

                if (ctx.should_finish.get()) {
                    std.debug.print("exiting\n", .{});
                    break :loop;
                }

                std.debug.print("{}: pull from queue\n", .{@as(i32,@intCast(std.Thread.getCurrentId()))});
                instruction_opt = ctx.generator_context.queue.pop();
            }
            ctx.generator_context.cv.signal();

            if (instruction_opt) |instruction| {
                {
                    ctx.generator_context.mutex.lock();
                    defer ctx.generator_context.mutex.unlock();
                    ctx.state.set(.working);
                }
                ctx.generator_context.cv.signal();

                const pos = instruction.generate.position;
                const chunk: Chunk = .{
                    .quadrant = pos,
                    .tilemap = undefined,
                };

                {
                    ctx.generator_context.mutex.lock();
                    defer ctx.generator_context.mutex.unlock();
                    ctx.generator_context.cache.append(chunk) catch {
                        std.debug.print("error on generation\n", .{});
                    };
                    ctx.generator_context.results.append(chunk) catch {
                        std.debug.print("error on generation\n", .{});
                    };

                    std.debug.print("{}: appended to results x:{} y:{}\n", .{ @as(i32,@intCast(std.Thread.getCurrentId())), pos.x, pos.y });
                }
                ctx.generator_context.cv.signal();
            }
        }
    }
};

const GeneratorContext = struct {
    cache: std.ArrayList(Chunk),
    results: std.ArrayList(Chunk),
    mutex: std.Thread.Mutex,
    queue: std.ArrayList(Instruction),
    cv: std.Thread.Condition,
};

const Data = struct {
    params: Params,
    context: *Context,
    workers: std.ArrayList(Worker),
    generator_context: *GeneratorContext,
};

data: *Data,
allocator: std.mem.Allocator,

pub fn init(context: *Context, worker_count: u8, allocator: std.mem.Allocator) !Self {
    var data = try allocator.create(Data);
    data.* = Data{
        .workers = .init(allocator),
        .context = context,
        .params = .{},
        .generator_context = try allocator.create(GeneratorContext),
    };

    data.generator_context.* = .{
        .queue = .init(allocator),
        .cache = .init(allocator),
        .results = .init(allocator),
        .mutex = .{},
        .cv = .{},
    };

    for (0..worker_count) |_|
        try data.workers.append(try Worker.init(allocator, data.generator_context));

    return .{ .allocator = allocator, .data = data };
}

pub fn deinit(self: *Self) void {
    var data = self.data;
    for (data.workers.items) |*worker|
        worker.deinit();
    data.workers.deinit();
    data.generator_context.queue.deinit();
    data.generator_context.cache.deinit();
    data.generator_context.results.deinit();
    self.allocator.destroy(data.generator_context);
    self.allocator.destroy(data);
    self.* = undefined;
}

pub fn generate(self: Self, instruction: Instruction) !void {
    {
        self.data.generator_context.mutex.lock();
        defer self.data.generator_context.mutex.unlock();
        try self.data.generator_context.queue.insert(0, instruction);
        std.debug.print("pushed to queue\n", .{});
    }
    self.data.generator_context.cv.signal();
}

pub fn wait_results(self: Self) !std.ArrayList(Chunk) {
    for (self.data.workers.items) |*worker|
        worker.wait_until_completed();

    self.data.generator_context.mutex.lock();
    defer self.data.generator_context.mutex.unlock();
    const results = try self.data.generator_context.results.clone();
    self.data.generator_context.results.clearAndFree();
    return results;
}
