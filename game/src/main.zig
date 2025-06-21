const std = @import("std");

const PCGManager = @import("pcgmanager");
const contents = PCGManager.Contents;
const c = @import("commons.zig");
const rl = @import("raylib.zig");
const rll = @import("rlights.zig");
const World = @import("World.zig");
const scenes = @import("scenes.zig");

const LevelArgs = struct {
    level: contents.Level,
    boss: World.BossType = .lion,
    tint: rl.Color = rl.WHITE,
};

pub fn main() !void {
    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(c.window_w, c.window_h, "raylib [core] example - basic window");
    rl.SetTargetFPS(60);
    defer rl.CloseWindow();

    const alloc = std.heap.c_allocator;

    const level_args = try generate_levels(alloc);
    defer for (level_args) |lvl| lvl.level.deinit();

    var curr_i: usize = 0;
    var world = try get_world(alloc, level_args[curr_i]);
    defer world.deinit();

    while (!rl.WindowShouldClose()) {
        try world.update();
        world.render();

        if (world.finished) {
            if (world.player.alive) curr_i += 1;

            if (curr_i == level_args.len) break;

            world.deinit();
            world = try get_world(alloc, level_args[curr_i]);
        }
    }
}

fn get_world(alloc: std.mem.Allocator, args: LevelArgs) !World {
    return try World.init(alloc, args.level, args.boss, args.tint);
}

fn generate_levels(alloc: std.mem.Allocator) ![6]LevelArgs {
    var levels: [6]LevelArgs = undefined;

    var pcg = try PCGManager.init(alloc);
    defer pcg.deinit();

    const yellow = rl.Color{ .r = 255, .g = 235, .b = 179, .a = 0 };
    const green = rl.Color{ .r = 86, .g = 117, .b = 115, .a = 0 };
    const light_green = rl.Color{ .r = 227, .g = 255, .b = 163, .a = 0 };

    levels[0].level = try scenes.initial_scene(alloc);
    levels[0].tint = yellow;
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

    levels[1].level = try pcg.retrieve_level();
    levels[1].tint = yellow;
    levels[1].boss = .lion;

    levels[2].level = try scenes.second_scene(alloc);
    levels[2].tint = green;
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
    levels[3].level = try pcg.retrieve_level();
    levels[3].tint = green;
    levels[3].boss = .hydra;

    levels[4].level = try scenes.third_scene(alloc);
    levels[4].tint = light_green;
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
    levels[5].level = try pcg.retrieve_level();
    levels[5].tint = light_green;

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
