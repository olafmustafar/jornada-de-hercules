const std = @import("std");
const pcgmanager = @import("root.zig");
const MapGenerator = @import("MapGenerator.zig");
const Context = @import("Context.zig");

fn gen_instr(x: i32, y: i32) MapGenerator.Instruction {
    return MapGenerator.Instruction{ .generate = .{ .position = .{ .x = x, .y = y } } };
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;
    const ctx: *Context = undefined;

    var generator = try MapGenerator.init(ctx, 2, alloc);
    defer generator.deinit();

    try generator.generate(gen_instr(1, 1));
    try generator.generate(gen_instr(0, 0));
    try generator.generate(gen_instr(0, 1));
    try generator.generate(gen_instr(1, 0));
    try generator.generate(gen_instr(2, 0));

    const results = try generator.wait_results();

    for (results.items) |chunk| {
        std.debug.print("chunk {d} {d}\n", .{ chunk.quadrant.x, chunk.quadrant.y });
    }

}
