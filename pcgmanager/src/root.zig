const std = @import("std");
const Context = @import("Context.zig");
const RoomGenerator = @import("./generators/roomgenerator.zig").RoomGenerator;
const ArchitectureGenerator = @import("./generators/architecturegenerator.zig").ArchitectureGenerator;
const Orquestrator = @import("Orquestrator.zig");

pub const Contents = @import("contents.zig");

const Self = @This();

context: *Context,
room_generator: RoomGenerator,
architecture_generator: ArchitectureGenerator,
orquestrator: Orquestrator,
gpa: std.mem.Allocator,

const InstructionTag = enum {
    room,
    architecture,
};

pub const Instruction = union(InstructionTag) {
    room: RoomGenerator.Instruction,
    architecture: ArchitectureGenerator.Instruction,
};

pub fn init(allocator: std.mem.Allocator) !Self {
    const context = try allocator.create(Context);
    context.* = .init(allocator);
    return .{
        .context = context,
        .room_generator = try .init(context, 3, allocator),
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
        .room => |room_inst| self.room_generator.add(room_inst),
        .architecture => |arch_instr| self.architecture_generator.add(arch_instr),
    };
}

pub fn retrieve_level(self: *Self) !Contents.Level {
    const rooms = try self.room_generator.wait_results();
    defer rooms.deinit();
    const archs = try self.architecture_generator.wait_results();
    defer archs.deinit();

    for (rooms.items) |room| {
        try self.orquestrator.add(.{ .room = room });
    }
    for (archs.items) |arch| {
        try self.orquestrator.add(.{ .architecture = arch });
    }

    return try self.orquestrator.combine();
}
