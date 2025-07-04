const std = @import("std");
const builtin = @import("builtin");
const Context = @import("../Context.zig");

pub fn Generator(
    comptime InstructionType: type,
    comptime ContentType: type,
    comptime GenFn: *const fn (ctx: *Context, instruction: InstructionType) ContentType,
) type {
    comptime {
        if (builtin.single_threaded) {
            return GeneratorImpl(InstructionType, ContentType, GenFn);
        } else {
            return GeneratorMultithreadImpl(InstructionType, ContentType, GenFn);
        }
    }
}

pub fn GeneratorImpl(
    comptime InstructionType: type,
    comptime ContentType: type,
    comptime GenFn: *const fn (ctx: *Context, instruction: InstructionType) ContentType,
) type {
    const Queue = std.ArrayList(InstructionType);

    return struct {
        pub const Instruction = InstructionType;
        pub const Content = ContentType;

        const Self = @This();

        gen_context: *Context,
        result: std.ArrayList(Content),
        queue: Queue,

        pub fn init(gen_context: *Context, workers: usize, alloc: std.mem.Allocator) !Self {
            _ = workers;
            return Self{ .queue = .init(alloc), .result = .init(alloc), .gen_context = gen_context };
        }

        pub fn deinit(self: *Self) void {
            self.queue.deinit();
            self.result.deinit();
        }

        pub fn add(self: *Self, instruction: Instruction) !void {
            try self.queue.insert(0, instruction);
        }

        pub fn wait_results(self: *Self) !std.ArrayList(Content) {
            while (self.queue.pop()) |instr| {
                const content = GenFn(self.gen_context, instr);
                try self.result.append(content);
            }

            const results = try self.result.clone();
            self.result.clearAndFree();
            return results;
        }
    };
}

pub fn GeneratorMultithreadImpl(
    comptime InstructionType: type,
    comptime ContentType: type,
    comptime GenFn: *const fn (ctx: *Context, instruction: InstructionType) ContentType,
) type {
    const Queue = std.ArrayList(InstructionType);

    return struct {
        pub const Instruction = InstructionType;
        pub const Content = ContentType;

        const SharedContext = struct {
            queue: Queue,
            result: std.ArrayList(Content),
            working: i32,
            should_exit: bool,
            mutex: std.Thread.Mutex,
            thread_cv: std.Thread.Condition,
            cv: std.Thread.Condition,
            gen_context: *Context,
        };

        const Self = @This();

        gpa: std.mem.Allocator,
        shared: *SharedContext,
        workers: std.ArrayList(std.Thread),

        fn worker_fn(ctx: *SharedContext) void {
            var instr_opt: ?Instruction = null;
            const id = @as(i32, @intCast(std.Thread.getCurrentId()));

            while (true) {
                {
                    ctx.mutex.lock();
                    defer ctx.mutex.unlock();

                    while (ctx.queue.items.len == 0 and !ctx.should_exit) ctx.thread_cv.wait(&ctx.mutex);

                    if (ctx.should_exit) {
                        break;
                    } else {
                        instr_opt = ctx.queue.pop();
                        ctx.working += 1;
                    }
                }
                ctx.cv.signal();

                if (instr_opt) |instruction| {
                    const content = GenFn(ctx.gen_context, instruction);

                    {
                        ctx.mutex.lock();
                        defer ctx.mutex.unlock();
                        ctx.result.append(content) catch {
                            std.debug.print("{}: error appending to results\n", .{id});
                        };
                        ctx.working -= 1;
                    }
                    ctx.cv.signal();
                } else {
                    {
                        ctx.mutex.lock();
                        defer ctx.mutex.unlock();
                        ctx.working -= 1;
                    }
                    ctx.cv.signal();
                }
            }
        }

        pub fn init(gen_context: *Context, workers: usize, alloc: std.mem.Allocator) !Self {
            var self = Self{ .gpa = alloc, .shared = try alloc.create(SharedContext), .workers = .init(alloc) };

            self.shared.* = .{ .queue = .init(alloc), .result = .init(alloc), .should_exit = false, .mutex = .{}, .cv = .{}, .thread_cv = .{}, .working = 0, .gen_context = gen_context };

            for (0..workers) |_|
                try self.workers.append(try std.Thread.spawn(.{}, worker_fn, .{self.shared}));

            return self;
        }

        pub fn deinit(self: *Self) void {
            {
                self.shared.mutex.lock();
                defer self.shared.mutex.unlock();
                self.shared.should_exit = true;
            }
            self.shared.thread_cv.broadcast();

            for (self.workers.items) |worker|
                worker.join();

            self.gpa.destroy(self.shared);
            self.* = undefined;
        }

        pub fn add(self: Self, instruction: Instruction) !void {
            {
                self.shared.mutex.lock();
                defer self.shared.mutex.unlock();
                try self.shared.queue.insert(0, instruction);
            }
            self.shared.thread_cv.signal();
        }

        pub fn wait_results(self: Self) !std.ArrayList(Content) {
            self.shared.mutex.lock();
            defer self.shared.mutex.unlock();

            while (self.shared.queue.items.len != 0 or self.shared.working != 0) {
                self.shared.cv.wait(&self.shared.mutex);
            }

            const results = try self.shared.result.clone();
            self.shared.result.clearAndFree();
            return results;
        }
    };
}
