const std = @import("std");
const pcgmanager = @import("root.zig");
const Context = @import("Context.zig");
const RoomGenerator = @import("roomgenerator.zig").RoomGenerator;

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    var context = Context.init();

    var generator = try RoomGenerator.init(&context, 3, alloc);
    defer generator.deinit();

    try generator.add(.{.generate = .{}});
    try generator.add(.{.generate = .{}});
    // try generator.add(.{.generate = .{}});
    // try generator.add(.{.generate = .{}});
    // try generator.add(.{.generate = .{}});
    // try generator.add(.{.generate{}});
    // try generator.add(.{.generate{}});

    const results = try generator.wait_results();

    for (results.items) |chunk| {
        for (chunk.tilemap) |line| {
            for (line) |tile| {
                switch (tile) {
                    .empty => std.debug.print(" ", .{}),
                    .plane => std.debug.print(".", .{}),
                    .ocean => std.debug.print("~", .{}),
                    .mountain => std.debug.print("^", .{}),
                    .sand => std.debug.print("/", .{}),
                    .trees => std.debug.print("T", .{}),
                    .size => std.debug.print("X", .{}),
                }
            }
            std.debug.print("\n", .{});
        }
    }
}
