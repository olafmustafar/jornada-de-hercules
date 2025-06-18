const std = @import("std");

const PCGManager = @import("pcgmanager");
const c = @import("commons.zig");
const rl = @import("raylib.zig");
const rll = @import("rlights.zig");
const World = @import("World.zig");
const scenes = @import("scenes.zig");

pub fn main() !void {
    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(c.window_w, c.window_h, "raylib [core] example - basic window");
    rl.SetTargetFPS(60);
    defer rl.CloseWindow();

    const alloc = std.heap.c_allocator;
    var pcg = try PCGManager.init(alloc);
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
    defer for (level.items) |l| {
        l.deinit();
    };

    const initial = try scenes.initial_scene(alloc);
    defer initial.deinit();

    var world = try World.init(alloc, initial);
    defer world.deinit();

    while (!rl.WindowShouldClose()) {
        try world.update();
        world.render();
        if (world.finished) {
            world.deinit();
            world = try World.init(alloc, level.items[0]);
        }
    }
}

fn _test() void {
    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(c.window_w, c.window_h, "raylib [core] example - basic window");
    rl.SetTargetFPS(60);
    defer rl.CloseWindow();

    const model = rl.LoadModel("assets/lion.glb");
    var count: i32 = 0;
    const animations = rl.LoadModelAnimations("assets/lion.glb", &count);

    var camera = rl.Camera{
        .fovy = 60,
        .position = c.vec3xyz(5),
        .target = rl.Vector3Zero(),
        .projection = rl.CAMERA_PERSPECTIVE,
        .up = c.vec3up(),
    };

    var frame: i32 = 0;

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.BeginMode3D(camera);
        defer rl.EndMode3D();

        frame = @mod(frame + 1, animations[3].frameCount);
        rl.UpdateModelAnimation(model, animations[3], frame);
        rl.ClearBackground(rl.RAYWHITE);
        rl.UpdateCamera(&camera, rl.CAMERA_ORBITAL);
        rl.DrawModel(model, rl.Vector3Zero(), 1, rl.WHITE);
    }
}
