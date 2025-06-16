const std = @import("std");

const PCGManager = @import("pcgmanager");
const c = @import("commons.zig");
const rl = @import("raylib.zig");
const rll = @import("rlights.zig");
const World = @import("World.zig");
const scenes = @import("scenes.zig");

pub fn main() !void {
    const alloc = std.heap.c_allocator;

    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(c.window_w, c.window_h, "raylib [core] example - basic window");
    rl.SetTargetFPS(60);
    defer rl.CloseWindow();

    // var animation_count: usize = 0;
    // const player_animations = rl.LoadModelAnimations("assets/player.glb", @ptrCast(&animation_count));
    // const sprint = player_animations[27];
    // var frame: i32 = 0;
    //
    // for(0.. animation_count) |i| {
    //     std.debug.print("{}: {s}\n", .{i, player_animations[i].name});
    // }
    //
    // const model = rl.LoadModel("assets/player.glb");
    // const sword = rl.LoadModel("assets/sword.glb");
    // var camera = rl.Camera3D{
    //     .position = c.vec3(-5, 5, -5),
    //     .fovy = 60,
    //     .projection = rl.CAMERA_PERSPECTIVE,
    //     .target = rl.Vector3Zero(),
    //     .up = c.vec3(0, 1, 0),
    // };
    //
    // var right_hand_bone_idx: usize = undefined;
    // for (0..@intCast(model.boneCount)) |i| {
    //     std.debug.print("{s}\n", .{model.bones[i].name});
    //     if (rl.TextIsEqual(&model.bones[i].name, "DEF-hand.R")) {
    //         right_hand_bone_idx = i;
    //     }
    // }
    // std.debug.print("ridght hand boune {d}\n", .{right_hand_bone_idx});
    //
    // while (!rl.WindowShouldClose()) {
    //     rl.BeginDrawing();
    //     defer rl.EndDrawing();
    //
    //     rl.UpdateCamera(&camera, rl.CAMERA_ORBITAL);
    //     frame = @mod(frame + 1, sprint.frameCount);
    //     rl.UpdateModelAnimation(model, sprint, frame);
    //
    //     const bone_trans = sprint.framePoses[@intCast(frame)][right_hand_bone_idx];
    //     const in_rotation = model.bindPose[right_hand_bone_idx].rotation;
    //     const out_rotation = bone_trans.rotation;
    //
    //     // Calculate socket rotation (angle between bone in initial pose and same bone in current animation frame)
    //     const rotate = rl.QuaternionMultiply(out_rotation, rl.QuaternionInvert(in_rotation));
    //     var mat_trans = rl.MatrixIdentity();
    //     mat_trans=  rl.MatrixMultiply(mat_trans, rl.MatrixRotateXYZ(c.vec3(90, 0, 0)));
    //     mat_trans = rl.MatrixMultiply(mat_trans, rl.QuaternionToMatrix(rotate));
    //     mat_trans = rl.MatrixMultiply(mat_trans, rl.MatrixScale(0.1, 0.1, 0.1));
    //     mat_trans = rl.MatrixMultiply(mat_trans, rl.MatrixTranslate(bone_trans.translation.x, bone_trans.translation.y, bone_trans.translation.z));
    //     mat_trans = rl.MatrixMultiply(mat_trans, model.transform);
    //
    //     rl.BeginMode3D(camera);
    //     defer rl.EndMode3D();
    //
    //     rl.ClearBackground(rl.RAYWHITE);
    //     rl.DrawModel(model, rl.Vector3Zero(), 1, rl.WHITE);
    //     rl.DrawMesh(sword.meshes[0], sword.materials[1], mat_trans);
    //     // rl.DrawModel(sword, rl.Vector3Zero(), 1, rl.WHITE);
    // }

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
        if( world.finished ){
            world.deinit();
            world = try World.init(alloc, level.items[0]);
        }
    }
}
