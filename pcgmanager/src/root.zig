const std = @import("std");
const Context = @import("Context.zig");
const RoomGenerator = @import("roomgenerator.zig").RoomGenerator;

const PCGManager = struct {
    context: *Context,
    room_generator: RoomGenerator,
    gpa: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !PCGManager {
        var context = allocator.create(Context);
        context.* = .init();
        return .{
            .context = context,
            .room_generator = try .init(&context, 3, allocator),
        };
    }

    pub fn deinit(self: *PCGManager) void {
        self.room_generator.deinit();
        self.gpa.destroy(self.context);
    }

    pub fn generate(self: *PCGManager, instruction: RoomGenerator.Instruction) void {
        self.room_generator.add(instruction);
    }
};
