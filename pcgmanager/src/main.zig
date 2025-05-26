const std = @import("std");
const pcgmanager = @import("root.zig");
const mapgen = @import("mapgenerator.zig");
const Context = @import("Context.zig");

fn gen_instr(x: i32, y: i32) mapgen.Instruction {
    return mapgen.Instruction{ .generate = .{ .position = .{ .x = x, .y = y } } };
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    // const ctx: *Context = undefined;

    var generator = try mapgen.MapGenerator.init(alloc, 3);
    // var generator = try MapGenerator.init(ctx, 2, alloc);
    defer generator.deinit();

    try generator.add(gen_instr(0, 0));
    try generator.add(gen_instr(0, 1));
    try generator.add(gen_instr(1, 0));
    try generator.add(gen_instr(1, 1));
    try generator.add(gen_instr(2, 0));

    const results = try generator.wait_results();

    for (results.items) |chunk| {
        std.debug.print("chunk {?}:\n", .{chunk.quadrant});
        for (chunk.tilemap) |line| {
            for (line) |tile| {
                switch (tile) {
                    .plane => std.debug.print(".", .{}),
                    .ocean => std.debug.print("~", .{}),
                }
            }
            std.debug.print("\n", .{});
        }
    }
}
