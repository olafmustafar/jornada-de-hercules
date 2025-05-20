const std = @import("std");
const rl = @import("raylib.zig");
const rll = @import("rlights.zig");

const window_w = 800;
const window_h = 600;

const Type = enum { mountain, ocean, plane, sand, trees };

const TileGrid = std.ArrayList(std.ArrayList(Type));

// const World = struct {
//     tiles: TileGrid,
// };

pub fn vec3(x: f32, y: f32, z: f32) rl.Vector3 {
    return rl.Vector3{ .x = x, .y = y, .z = z };
}

pub fn vec2(x: f32, y: f32) rl.Vector2 {
    return rl.Vector2{ .x = x, .y = y };
}

pub fn main() !void {
    rl.InitWindow(window_w, window_h, "raylib [core] example - basic window");
    rl.SetTargetFPS(60);
    rl.DisableCursor();
    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    defer rl.CloseWindow();

    const shader = rl.LoadShader("assets/shaders/glsl100/lighting.vs", "assets/shaders/glsl100/lighting.fs");
    defer rl.UnloadShader(shader);

    var light = rll.CreateLight(rll.Light.Type.point, vec3(-2, 1, -2), rl.Vector3Zero(), rl.WHITE, shader);

    var camera = rl.Camera3D{
        .position = vec3(10.0, 5.0, 10.0),
        .target = vec3(0.0, 0.0, 0.0),
        .up = vec3(0.0, 1.0, 0.0),
        .fovy = 60.0,
        .projection = rl.CAMERA_PERSPECTIVE,
    };

    const models = [_]rl.Model{
        rl.LoadModel("assets/mountain_sqr.glb"),
        rl.LoadModel("assets/ocean_sqr.glb"),
        rl.LoadModel("assets/plane_sqrt.glb"),
        rl.LoadModel("assets/sand_sqr.glb"),
        rl.LoadModel("assets/trees_srq.glb"),
    };
    defer for (models) |model| rl.UnloadModel(model);

    for (models) |model| model.materials[1].shader = shader;

    while (!rl.WindowShouldClose()) {
        rl.UpdateCamera(&camera, rl.CAMERA_FREE);

        rl.SetShaderValue(
            shader,
            shader.locs[rl.SHADER_LOC_VECTOR_VIEW],
            &[3]f32{ camera.position.x, camera.position.y, camera.position.z },
            rl.SHADER_UNIFORM_VEC3,
        );

        light.position = camera.position;
        rll.UpdateLightValues(shader, light);

        rl.BeginDrawing();
        rl.BeginMode3D(camera);
        {
            rl.ClearBackground(rl.DARKGRAY);
            for (models, 0..) |model, i| rl.DrawModel(model, vec3(@floatFromInt(i * 2), 0, 0), 1.0, rl.WHITE);
            rl.DrawSphere(camera.target, 0.05, rl.RED);
            rl.DrawGrid(25, 1.0);
        }
        rl.EndMode3D();
        rl.EndDrawing();
    }
}
