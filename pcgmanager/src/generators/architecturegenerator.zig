const std = @import("std");
const Generator = @import("Generator.zig").Generator;
const Context = @import("../Context.zig");
const contents = @import("../contents.zig");
const Architecture = contents.Architecture;
const Direction = contents.Direction;
const Position = contents.Position;
const Node = contents.Node;

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

fn reset_state(ctx: *Context, architecture: *Architecture, position_set: *std.AutoHashMap(Position, void), expand_queue: *std.ArrayList(Expand), diameter: usize) !void {
    architecture.clearAndFree();
    position_set.clearAndFree();
    expand_queue.clearAndFree();

    try architecture.append(Node{
        .directions = .initDefault(false, .{ .down = true }),
        .exit = null,
        .pos = .init(0, 0),
        .is_branch = false,
        .is_spawn = true,
        .difficulty_class = ctx.difficulty_level - 1,
    });
    try position_set.put(architecture.getLast().pos, {});
    try architecture.append(Node{
        .directions = .initDefault(false, .{ .down = true }),
        .exit = null,
        .pos = .init(0, -1),
        .is_branch = false,
        .is_spawn = false,
        .difficulty_class = ctx.difficulty_level - 1,
    });
    try position_set.put(architecture.getLast().pos, {});
    try expand_queue.append(Expand{
        .is_branch = false,
        .origin_idx = architecture.items.len - 1,
        .diameter_left = diameter - 1,
        .direction = .up,
        .corridor_count = 0,
    });
}

fn generate_architecture(ctx: *Context, args: GenerateArgs) !Architecture {
    const rnd = ctx.random.random();

    var position_set = std.AutoHashMap(Position, void).init(ctx.gpa);
    defer position_set.deinit();
    var architecture = Architecture.init(ctx.gpa);
    var expand_queue = std.ArrayList(Expand).init(ctx.gpa);

    try reset_state(ctx, &architecture, &position_set, &expand_queue, args.diameter);

    var count: i32 = 0;
    while (expand_queue.items.len > 0) {
        const expand = expand_queue.pop().?;
        if (expand.diameter_left == 0) {
            continue;
        }

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
                try reset_state(ctx, &architecture, &position_set, &expand_queue, args.diameter);
            }
            continue;
        }

        var exit: ?Direction = null;
        if (!expand.is_branch and (expand.diameter_left - 1) == 0) {
            exit = choose_random_available_direction(rnd, origin.pos, &origin.directions, position_set, expand.direction);
            if (exit) |dir| {
                try position_set.put(origin.pos.move(dir), {});
            } else {
                count = 0;
                try reset_state(ctx, &architecture, &position_set, &expand_queue, args.diameter);
                continue;
            }
        }

        const dir = dir_opt.?;
        origin.directions.set(dir, true);
        var new_node = Node{
            .pos = origin.pos.move(dir),
            .directions = .initDefault(false, .{}),
            .exit = exit,
            .is_spawn = false,
            .is_branch = expand.is_branch,
            .difficulty_class = if (@as(f32, @floatFromInt(expand.diameter_left)) > (@as(f32, @floatFromInt(args.diameter)) * 0.6))
                ctx.difficulty_level - 1
            else if (@as(f32, @floatFromInt(expand.diameter_left)) > (@as(f32, @floatFromInt(args.diameter)) * 0.2))
                ctx.difficulty_level
            else
                ctx.difficulty_level + 1,
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
}
pub const ArchitectureGenerator = Generator(Instruction, Architecture, generate);
