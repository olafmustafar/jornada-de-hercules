const std = @import("std");
const rl = @import("raylib.zig");

const window_w = 800;
const window_h = 600;

pub fn vec3(x: f32, y: f32, z: f32) rl.Vector3 {
    return rl.Vector3{ .x = x, .y = y, .z = z };
}

pub fn main() !void {
    rl.InitWindow(window_w, window_h, "raylib [core] example - basic window");
    rl.SetTargetFPS(60);
    rl.DisableCursor();
    defer rl.CloseWindow();

    var camera = rl.Camera3D{
        .position = vec3(10.0, 5.0, 10.0),
        .target = vec3(0.0, 0.0, 0.0),
        .up = vec3(0.0, 1.0, 0.0),
        .fovy = 60.0,
        .projection = rl.CAMERA_PERSPECTIVE,
    };

    const nave = rl.LoadModel(@embedFile("mountain"));
    std.debug.print("{s}\n", .{@embedFile("mountain")});

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        {
            rl.ClearBackground(rl.RAYWHITE);
            rl.BeginMode3D(camera);
            {
                rl.DrawModel(nave, vec3(0,0,0), 10.0, rl.WHITE);

                rl.DrawGrid(25, 1.0);
                rl.DrawSphere(camera.target, 0.05, rl.RED);
                rl.UpdateCamera(&camera, rl.CAMERA_FREE);
            }
            rl.EndMode3D();
        }
        rl.EndDrawing();
    }
}
