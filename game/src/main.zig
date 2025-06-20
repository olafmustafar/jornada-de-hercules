const std = @import("std");

const PCGManager = @import("pcgmanager");
const contents = PCGManager.Contents;
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

    const initial = try scenes.initial_scene(alloc);
    defer initial.deinit();

    const test_scene = try scenes.test_scene(alloc);
    defer test_scene.deinit();

    const levels = try generate_levels(alloc);
    defer for (levels) |lvl| lvl.deinit();

    var world = try World.init(alloc, test_scene, .hydra);
    defer world.deinit();

    var lvl_i: usize = 0;
    while (!rl.WindowShouldClose()) {
        try world.update();
        world.render();

        if (world.finished) {
            if (lvl_i == levels.len) {
                break;
            }

            world.deinit();
            world = try World.init(alloc, levels[0], .lion);
            lvl_i += 1;
        }
    }
}

fn generate_levels(alloc: std.mem.Allocator) ![3]contents.Level {
    var levels: [3]contents.Level = undefined;

    var pcg = try PCGManager.init(alloc);
    defer pcg.deinit();

    pcg.context.difficulty_level = 4;
    try pcg.generate(.{ .rooms = .{ .generate = .{} } });
    try pcg.generate(.{ .enemies = .{ .generate = .{} } });
    try pcg.generate(.{ .architecture = .{ .generate = .{
        .diameter = 3,
        .max_corridor_length = 3,
        .branch_chance = 0.25,
        .min_branch_diameter = 2,
        .max_branch_diameter = 5,
        .change_direction_chance = 0.25,
    } } });
    levels[0] = try pcg.retrieve_level();

    pcg.context.difficulty_level = 4;
    try pcg.generate(.{ .enemies = .{ .generate = .{} } });
    try pcg.generate(.{ .architecture = .{ .generate = .{
        .diameter = 5,
        .max_corridor_length = 2,
        .branch_chance = 0.25,
        .min_branch_diameter = 1,
        .max_branch_diameter = 1,
        .change_direction_chance = 0.30,
    } } });
    levels[1] = try pcg.retrieve_level();

    pcg.context.difficulty_level = 5;
    try pcg.generate(.{ .enemies = .{ .generate = .{} } });
    try pcg.generate(.{ .architecture = .{ .generate = .{
        .diameter = 6,
        .max_corridor_length = 3,
        .branch_chance = 0.25,
        .min_branch_diameter = 2,
        .max_branch_diameter = 5,
        .change_direction_chance = 0.25,
    } } });
    levels[2] = try pcg.retrieve_level();

    return levels;
}

fn _test() void {
    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(c.window_w, c.window_h, "raylib [core] example - basic window");
    rl.SetTargetFPS(60);
    defer rl.CloseWindow();

    const model = rl.LoadModel("assets/hydra_body.glb");
    const model2 = rl.LoadModel("assets/hydra_head.glb");

    var count: i32 = 0;
    const animations = rl.LoadModelAnimations("assets/hydra_head.glb", &count);

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

        frame = @mod(frame + 1, animations[4].frameCount);
        rl.UpdateModelAnimation(model2, animations[4], frame);

        rl.ClearBackground(rl.RAYWHITE);
        rl.UpdateCamera(&camera, rl.CAMERA_ORBITAL);
        rl.DrawModel(model, rl.Vector3Zero(), 1, rl.WHITE);
        rl.DrawModel(model2, rl.Vector3Zero(), 1, rl.WHITE);
    }
}
