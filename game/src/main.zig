const std = @import("std");

const PCGManager = @import("pcgmanager");

const rl = @import("raylib.zig");
const rll = @import("rlights.zig");
const World = @import("World.zig");

const window_w = 800;
const window_h = 600;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    rl.InitWindow(window_w, window_h, "raylib [core] example - basic window");
    rl.SetTargetFPS(60);
    rl.DisableCursor();
    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    defer rl.CloseWindow();

    var pcg = try PCGManager.init(allocator);
    try pcg.generate(.{ .room = .{ .generate = .{} } });
    try pcg.generate(.{ .room = .{ .generate = .{} } });
    try pcg.generate(.{ .room = .{ .generate = .{} } });
    try pcg.generate(.{ .room = .{ .generate = .{} } });
    try pcg.generate(.{ .room = .{ .generate = .{} } });
    try pcg.generate(.{ .enemies = .{ .generate = .{} } });
    try pcg.generate(.{ .architecture = .{ .generate = .{
        .diameter = 10,
        .max_corridor_length = 5,
        .branch_chance = 0.25,
        .min_branch_diameter = 2,
        .max_branch_diameter = 5,
        .change_direction_chance = 0.25,
    } } });
    const level = try pcg.retrieve_level();
    defer level.deinit();

    var world = try World.init(allocator, level);

    while (!rl.WindowShouldClose()) {
        try world.update();
        world.render();
    }
}
