const std = @import("std");
const pcgmanager = @import("root.zig");
const MapGenerator = @import("MapGenerator.zig");
const Generator = @import("Generator.zig").Generator;
const Context = @import("Context.zig");

fn gen_instr(x: i32, y: i32) MapGenerator.Instruction {
    return MapGenerator.Instruction{ .generate = .{ .position = .{ .x = x, .y = y } } };
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    // const ctx: *Context = undefined;

    var generator = try Generator.init(alloc, 3);
    // var generator = try MapGenerator.init(ctx, 2, alloc);
    defer generator.deinit();

    try generator.add(.{});
    try generator.add(.{});
    try generator.add(.{});
    try generator.add(.{});
    try generator.add(.{});

    const results = try generator.wait_results();

    for (results.items, 0..) |_, i| {
        std.debug.print("chunk {d}\n", .{i});
    }
}
