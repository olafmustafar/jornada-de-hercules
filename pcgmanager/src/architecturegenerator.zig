const std = @import("std");
const Generator = @import("Generator.zig").Generator;
const Context = @import("Context.zig");

pub const Architecture = std.ArrayList(Node);

pub const GenerateArgs = struct {
    diameter: usize,
    max_corridor_length: usize,
    change_direction_chance: f32,
    max_branch_diameter: usize,
    min_branch_diameter: usize,
    branch_chance: f32,
};

pub const Instruction = union(InstructionTag) {
    generate: GenerateArgs,
    place_manual: Architecture,
};

const InstructionTag = enum { generate, place_manual };

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

    fn move(self: Position, dir: Direction) Position {
        switch (dir) {
            .up => return .{ .x = self.x, .y = self.y - 1 },
            .down => return .{ .x = self.x, .y = self.y + 1 },
            .left => return .{ .x = self.x - 1, .y = self.y },
            .right => return .{ .x = self.x + 1, .y = self.y },
        }
    }
};

pub const Node = struct {
    pos: Position,
    directions: std.EnumArray(Direction, bool),
    is_branch: bool,
};

const Expand = struct {
    origin_idx: usize,
    is_branch: bool,
    diameter_left: usize,
    direction: Direction,
    corridor_count: usize,
};

fn generate(ctx: *Context, instruction: Instruction) Architecture {
    switch (instruction) {
        .generate => |args| return generate_architecture(ctx, args) catch {
            @panic("error on allocating memory");
        },
        .place_manual => |architecture| return architecture,
    }
}

fn generate_architecture(ctx: *Context, args: GenerateArgs) !Architecture {
    const rnd = ctx.random.random();

    var position_set = std.AutoHashMap(Position, void).init(ctx.gpa);
    defer position_set.deinit();

    //initial node
    var architecture = Architecture.init(ctx.gpa);
    try architecture.append(Node{ .directions = .initDefault(false, .{}), .pos = .{ .x = 0, .y = 0 }, .is_branch = false });
    try position_set.put(architecture.getLast().pos, {});

    //begin expanding from initial
    var expand_queue = std.ArrayList(Expand).init(ctx.gpa);
    try expand_queue.append(Expand{
        .is_branch = false,
        .origin_idx = architecture.items.len - 1,
        .diameter_left = args.diameter - 1,
        .direction = .right,
        .corridor_count = 0,
    });

    var count: i32 = 0;
    while (expand_queue.items.len > 0) {
        const expand = expand_queue.pop().?;
        if (expand.diameter_left == 0) {
            std.debug.print("branch over \n", .{});
            continue;
        }

        if (expand.is_branch) {
            std.debug.print("is branch, ", .{});
        }
        std.debug.print("{}: \n", .{count});
        count += 1;
        print_arch(&architecture);

        var origin = &architecture.items[expand.origin_idx];

        var corridor_length: usize = undefined;
        var dir_opt: ?Direction = null;

        if (rnd.float(f32) < args.change_direction_chance or expand.corridor_count >= args.max_corridor_length) {
            corridor_length = 0;
            dir_opt = choose_random_available_direction(rnd, origin.pos, &origin.directions, position_set, expand.direction);
        } else if (position_set.getEntry(origin.pos.move(expand.direction)) == null) {
            corridor_length = expand.corridor_count + 1;
            dir_opt = expand.direction;
        } else {
            dir_opt = null;
        }

        if (dir_opt == null) {
            //nowhere to expand to
            if (!expand.is_branch) {
                //try again
                count = 0;
                position_set.clearAndFree();
                architecture.clearAndFree();
                try architecture.append(Node{ .directions = .initDefault(false, .{}), .pos = .{ .x = 0, .y = 0 }, .is_branch = false });
                try position_set.put(architecture.getLast().pos, {});
                expand_queue.clearAndFree();
                try expand_queue.insert(0, Expand{
                    .is_branch = false,
                    .origin_idx = architecture.items.len - 1,
                    .diameter_left = args.diameter,
                    .direction = .right,
                    .corridor_count = 0,
                });
            }
            continue;
        }

        const dir = dir_opt.?;
        origin.directions.set(dir, true);
        var new_node = Node{
            .pos = origin.pos.move(dir),
            .directions = .initDefault(false, .{}),
            .is_branch = expand.is_branch,
        };
        new_node.directions.set(dir.inverse(), true);

        try position_set.put(new_node.pos, {});
        try architecture.append(new_node);

        if (expand.is_branch) {
            try expand_queue.append(.{
                .origin_idx = architecture.items.len - 1,
                .is_branch = true,
                .diameter_left = expand.diameter_left - 1,
                .direction = dir,
                .corridor_count = corridor_length,
            });
        } else {
            if (rnd.float(f32) < args.branch_chance and args.min_branch_diameter < expand.diameter_left) {
                try expand_queue.append(.{
                    .origin_idx = architecture.items.len - 1,
                    .is_branch = true,
                    .diameter_left = rnd.intRangeAtMost(usize, args.min_branch_diameter, args.max_branch_diameter),
                    .direction = dir, //new dir?
                    .corridor_count = 0,
                });
            }
            try expand_queue.append(.{
                .origin_idx = architecture.items.len - 1,
                .is_branch = false,
                .diameter_left = expand.diameter_left - 1,
                .direction = dir,
                .corridor_count = corridor_length,
            });
        }
    }

    return architecture;
}

fn choose_random_available_direction(rnd: std.Random, current_pos: Position, available: *std.EnumArray(Direction, bool), occupied_pos: std.AutoHashMap(Position, void), except: ?Direction) ?Direction {
    var directions: [4]Direction = undefined;
    var dir_i: usize = 0;
    var available_it = available.iterator();
    while (available_it.next()) |pair| {
        const newpos = current_pos.move(pair.key);
        if (!pair.value.* and occupied_pos.getEntry(newpos) == null) {
            directions[dir_i] = pair.key;
            dir_i += 1;
        }
    }

    if (dir_i == 0) {
        return null;
    }
    var dir = directions[rnd.uintAtMost(usize, dir_i - 1)];
    while (dir == except) {
        dir = directions[rnd.uintAtMost(usize, dir_i - 1)];
    }
    return dir;
}
fn print_arch(arch: *Architecture) void {
    var board = std.mem.zeroes([20][20]i32);
    for (arch.items) |node| {
        if (node.is_branch) {
            board[@intCast(node.pos.y + 10)][@intCast(node.pos.x + 10)] = 2;
        } else {
            board[@intCast(node.pos.y + 10)][@intCast(node.pos.x + 10)] = 1;
        }
    }
    for (board) |line| {
        for (line) |b| {
            switch (b) {
                0 => std.debug.print("..", .{}),
                1 => std.debug.print("[]", .{}),
                2 => std.debug.print("{{}}", .{}),
                else => unreachable,
            }
        }
        std.debug.print("\n", .{});
    }
    std.Thread.sleep(std.time.ns_per_s * 0.25);
}
pub const ArchitectureGenerator = Generator(Instruction, Architecture, generate);
