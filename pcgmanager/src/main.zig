const std = @import("std");
const pcgmanager = @import("root.zig");
// const Context = @import("Context.zig");
// const RoomGenerator = @import("roomgenerator.zig").RoomGenerator;
// const ArchitectureGenerator = @import("architecturegenerator.zig").ArchitectureGenerator;
// const root = @import("root.zig");

pub fn main() !void {
    // const alloc = std.heap.page_allocator;
    //
    // var context = Context.init(alloc);
    //
    // var generator = try ArchitectureGenerator.init(&context, 1, alloc);
    // defer generator.deinit();
    // try generator.add(.{ .generate = .{
    //     .diameter = 10,
    //     .max_corridor_length = 5,
    //     .branch_chance = 0.25,
    //     .min_branch_diameter = 2,
    //     .max_branch_diameter = 5,
    //     .change_direction_chance = 0.25,
    // } });
    //
    // const results = try generator.wait_results();
    //
    // var yey = std.mem.zeroes([30][30]bool);
    // for (results.items) |arch| {
    //     for (arch.items) |node| {
    //         yey[@intCast(node.pos.y + 15)][@intCast(node.pos.x + 15)] = true;
    //     }
    // }
    //
    // for (yey) |line| {
    //     for (line) |b| {
    //         if (b) {
    //             std.debug.print("[]", .{});
    //         } else {
    //             std.debug.print("..", .{});
    //         }
    //     }
    //     std.debug.print("\n", .{});
    // }
    //
    // //
    // // for (results.items) |room| {
    // //     for (room) |line| {
    // //         for (line) |tile| {
    // //             switch (tile) {
    // //                 .empty => std.debug.print(" ", .{}),
    // //                 .plane => std.debug.print(".", .{}),
    // //                 .ocean => std.debug.print("~", .{}),
    // //                 .mountain => std.debug.print("^", .{}),
    // //                 .sand => std.debug.print("/", .{}),
    // //                 .trees => std.debug.print("T", .{}),
    // //                 .size => std.debug.print("X", .{}),
    // //             }
    // //         }
    // //         std.debug.print("\n", .{});
    // //     }
    // // }
}
