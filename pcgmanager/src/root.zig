const std = @import("std");
const Context = @import("Context.zig");
const RoomGenerator = @import("./generators/roomgenerator.zig").RoomGenerator;
const ArchitectureGenerator = @import("./generators/architecturegenerator.zig").ArchitectureGenerator;
const EnemiesGenerator = @import("./generators/enemygenerator.zig").EnemiesGenerator;
const Orquestrator = @import("Orquestrator.zig");

pub const Contents = @import("contents.zig");

const Self = @This();

context: *Context,
room_generator: RoomGenerator,
enemies_generator: EnemiesGenerator,
architecture_generator: ArchitectureGenerator,
orquestrator: Orquestrator,
gpa: std.mem.Allocator,

const InstructionTag = enum {
    rooms,
    architecture,
    enemies,
};

pub const Instruction = union(InstructionTag) {
    rooms: RoomGenerator.Instruction,
    architecture: ArchitectureGenerator.Instruction,
    enemies: EnemiesGenerator.Instruction,
};

pub fn init(allocator: std.mem.Allocator) !Self {
    const context = try allocator.create(Context);
    context.* = .init(allocator);
    return .{
        .context = context,
        .room_generator = try .init(context, 3, allocator),
        .enemies_generator = try .init(context, 1, allocator),
        .architecture_generator = try .init(context, 1, allocator),
        .orquestrator = .init(allocator),
        .gpa = allocator,
    };
}

pub fn deinit(self: *Self) void {
    self.room_generator.deinit();
    self.gpa.destroy(self.context);
}

pub fn generate(self: *Self, instruction: Instruction) !void {
    try switch (instruction) {
        .rooms => |room_inst| self.room_generator.add(room_inst),
        .architecture => |arch_instr| self.architecture_generator.add(arch_instr),
        .enemies => |instr| self.enemies_generator.add(instr),
    };
}

pub fn retrieve_level(self: *Self) !Contents.Levels {
    const rooms_list = try self.room_generator.wait_results();
    defer rooms_list.deinit();
    for (rooms_list.items) |rooms| {
        try self.orquestrator.add(.{ .rooms = rooms });
    }

    const enemies_per_difficulty = try self.enemies_generator.wait_results();
    defer enemies_per_difficulty.deinit();
    for (enemies_per_difficulty.items) |enemies| {
        try self.orquestrator.add(.{ .enemies_per_difficulty = enemies });
    }

    const archs = try self.architecture_generator.wait_results();
    defer archs.deinit();
    for (archs.items) |arch| {
        try self.orquestrator.add(.{ .architecture = arch });
    }

    return try self.orquestrator.combine();
}
