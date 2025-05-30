const std = @import("std");
const Generator = @import("Generator.zig").Generator;
const Context = @import("Context.zig");

pub const Architecture = std.ArrayList(Node);

pub const GenerateArgs = struct {
    diameter: usize,
    change_direction_chance: f32,
    branch_diameter: usize,
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
};

const Expand = struct {
    origin_idx: usize,
    is_branch: bool,
    diameter_left: usize,
    direction: Direction,
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

    var architecture = Architecture.init(ctx.gpa);

    //initial node
    try architecture.append(Node{ .directions = .initDefault(false, .{}), .pos = .{ .x = 0, .y = 0 } });

    //begin expanding from initial
    var expand_queue = std.ArrayList(Expand).init(ctx.gpa);
    try expand_queue.insert(0, Expand{
        .is_branch = true,
        .origin_idx = architecture.items.len - 1,
        .diameter_left = args.diameter,
        .direction = .right,
    });

    while (expand_queue.items.len > 0) {
        const expand = expand_queue.pop().?;
        if (expand.diameter_left == 0) {
            continue;
        }

        var origin = &architecture.items[expand.origin_idx];

        var dir_opt: ?Direction = false;
        if (rnd.float() < args.change_direction_chance) {
            dir_opt = choose_random_available_direction(rnd, origin.pos, origin.directions, position_set);
        } else if (position_set.getEntry(origin.pos.move(expand.direction)) != null) {
            dir_opt = expand.direction;
        } else {
            dir_opt = null;
        }

        if (dir_opt == null) {
            //nowhere to expand to
            if (!expand.is_branch) {
                // TODO failure too high, first create path then only  after create branches
                //try again
                position_set.clearAndFree();
                architecture.clearAndFree();
                try architecture.append(Node{ .directions = .initDefault(false, .{}), .pos = .{ .x = 0, .y = 0 } });
                expand_queue.clearAndFree();
                try expand_queue.insert(0, Expand{
                    .is_branch = true,
                    .origin_idx = architecture.items.len - 1,
                    .diameter_left = args.diameter,
                });
            }
            continue;
        }

        // position_set.put(dir, {});
        origin.directions.set(dir, true);

        var new_node = Node{
            .pos = origin.pos.move(dir),
            .directions = .initDefault(false, .{}),
        };
        new_node.directions.set(dir.inverse(), true);

        try position_set.put(new_node.pos, {});
        try architecture.append(new_node);

        if (expand.is_branch) {
            try expand_queue.insert(0, .{
                .origin_idx = architecture.items.len - 1,
                .is_branch = true,
                .diameter_left = expand.diameter_left - 1,
                .direction = dir,
            });
        } else if (rnd.float(f32) < args.branch_chance) {
            try expand_queue.insert(0, .{
                .origin_idx = architecture.items.len - 1,
                .is_branch = true,
                .diameter_left = args.branch_diameter,
                .direction = dir, //new dir?
            });
        }

        try expand_queue.insert(0, .{
            .origin_idx = architecture.items.len - 1,
            .is_branch = false,
            .diameter_left = expand.diameter_left - 1,
            .direction = dir,
        });
    }

    return architecture;
}

fn choose_random_available_direction(rnd: std.Random, current_pos: Position, available: std.EnumArray(Direction, bool), occupied_pos: std.AutoHashMap(Position, void)) ?Direction {
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

    return directions[rnd.uintAtMost(usize, 0, dir_i - 1)];
}

pub const ArchitectureGenerator = Generator(Instruction, Architecture, generate);
