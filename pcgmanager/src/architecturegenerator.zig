const std = @import("std");
const Generator = @import("Generator.zig").Generator;
const Context = @import("Context.zig");

pub const Architecture = std.ArrayList(Node);

pub const Instruction = union(InstructionTag) {
    generate: struct { diameter: usize },
    place_manual: struct { architecture: Architecture },
};

const InstructionTag = enum { generate, place_manual };

const Direction = enum {
    up,
    right,
    down,
    left,

    fn inverse(self: Direction) Direction {
        switch (self) {
            .up => .down,
            .down => .up,
            .left => .right,
            .right => .left,
        }
    }
};

const Position = struct {
    x: i32,
    y: i32,

    fn move(self: Position, dir: Direction) Position {
        switch (dir) {
            .up => return .{ self.x, self.y - 1 },
            .down => return .{ self.x, self.y + 1 },
            .left => return .{ self.x - 1, self.y },
            .right => return .{ self.x + 1, self.y },
        }
    }
};

const Node = struct {
    pos: Position,
    directions: std.EnumArray(Direction, bool),
};

const Expand = struct {
    origin_idx: usize,
    keep_expanding: bool,
    diameter: usize,
};

fn generate(ctx: *Context, instruction: Instruction) Architecture {
    switch (instruction) {
        .generate => |args| {
            return generate_architecture(ctx, args.diameter);
        },
        .place_manual => |args| {
            return args.architecture();
        },
    }
}

fn generate_architecture(ctx: *Context, max_diameter: u8) Architecture {
    const rnd = ctx.random.random();

    var position_set = std.AutoHashMap(Position, void).init(ctx.gpa);
    defer position_set.deinit();

    var architecture = Architecture.init(ctx.gpa);

    //initial node
    architecture.append(Node{ .directions = .initDefault(false), .pos = .{ .x = 0, .y = 0 } });

    //begin expanding from initial
    var expand_queue = std.ArrayList(Expand).init(ctx.gpa);
    expand_queue.insert(0, Expand{
        .keep_expanding = true,
        .origin_idx = architecture.items.len - 1,
        .diameter = 0,
    });

    while (expand_queue.items.len > 0) {
        const expand = expand_queue.pop().?;
        if (expand.diameter > max_diameter) {
            continue;
        }

        var origin = &architecture.items[expand.origin_idx];
        var directions: [4]Direction = undefined;
        var dir_i = 0;

        // add all possible directions to expand to
        const origin_dirs = origin.directions.iterator();
        while (origin_dirs.next()) |pair| {
            const newpos = origin_dirs.pos.move(pair.key);
            if (!pair.value and position_set.getEntry(newpos) == null) {
                directions[dir_i] = pair.key;
                dir_i += 1;
            }
        }

        const dir = directions[rnd.uintAtMost(0, dir_i - 1)];
        origin.directions.set(dir, true);

        const new_node = Node{
            .pos = origin.pos.move(dir),
            .directions = .initDefault(false),
        };
        new_node.directions.set(dir.inverse(), true);

        position_set.put(new_node.pos, {});
        architecture.append(new_node);

        if (expand.keep_expanding) {
            expand_queue.insert(0, .{
                .origin_idx = architecture.items.len - 1,
                .keep_expanding = expand.keep_expanding,
                .diameter = expand.diameter + 1,
            });
        }

        if (rnd.float() < 0.15) {
            expand_queue.insert(0, .{
                .origin_idx = architecture.items.len - 1,
                .keep_expanding = false,
                .diameter = expand.diameter + 1,
            });
        }
    }
}

pub const ArchitectureGenerator = Generator(Instruction, Architecture, generate);
