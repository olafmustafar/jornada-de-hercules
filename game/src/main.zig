const std = @import("std");
const rl = @import("raylib.zig");
const rll = @import("rlights.zig");

const window_w = 800;
const window_h = 600;

const Type = enum { mountain, ocean, plane, sand, trees };

pub fn vec3(x: f32, y: f32, z: f32) rl.Vector3 {
    return rl.Vector3{ .x = x, .y = y, .z = z };
}

pub fn main() !void {
    rl.InitWindow(window_w, window_h, "raylib [core] example - basic window");
    rl.SetTargetFPS(60);
    rl.DisableCursor();
    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    defer rl.CloseWindow();

    const shader = rl.LoadShader("assets/shaders/glsl330/lighting.vs", "assets/shaders/glsl330/lighting.fs");
    defer rl.UnloadShader(shader);

    shader.locs[rl.SHADER_LOC_VECTOR_VIEW] = rl.GetShaderLocation(shader, "viewPos");
    const ambientLoc = rl.GetShaderLocation(shader, "ambient");

    rl.SetShaderValue(shader, ambientLoc, &[4]f32{ 0.1, 0.1, 0.1, 1.0 }, rl.SHADER_UNIFORM_VEC4);

    const lights = [rll.MAX_LIGHTS]rll.Light{
        rll.CreateLight(rll.Light.Type.point, vec3(-2, 1, -2), rl.Vector3Zero(), rl.YELLOW, shader),
        rll.CreateLight(rll.Light.Type.point, vec3(2, 1, 2), rl.Vector3Zero(), rl.RED, shader),
        rll.CreateLight(rll.Light.Type.point, vec3(-2, 1, 2), rl.Vector3Zero(), rl.GREEN, shader),
        rll.CreateLight(rll.Light.Type.point, vec3(2, 1, -2), rl.Vector3Zero(), rl.BLUE, shader),
    };
    // const light = rll.CreateLight(rll.Light.Type.point, vec3(-2, 1, -2), rl.Vector3Zero(), rl.RED, shader);

    var camera = rl.Camera3D{
        .position = vec3(10.0, 5.0, 10.0),
        .target = vec3(0.0, 0.0, 0.0),
        .up = vec3(0.0, 1.0, 0.0),
        .fovy = 60.0,
        .projection = rl.CAMERA_PERSPECTIVE,
    };

    const models = [_]rl.Model{
        rl.LoadModel("assets/mountain.glb"),
        rl.LoadModel("assets/mountain_sqr.glb"),
        rl.LoadModel("assets/ocean.glb"),
        rl.LoadModel("assets/ocean_sqr.glb"),
        rl.LoadModel("assets/plane.glb"),
        rl.LoadModel("assets/plane_sqrt.glb"),
        rl.LoadModel("assets/sand.glb"),
        rl.LoadModel("assets/sand_sqr.glb"),
        rl.LoadModel("assets/trees.glb"),
        rl.LoadModel("assets/trees_srq.glb"),
    };

    defer for (models) |model| {
        rl.UnloadModel(model);
    };

    while (!rl.WindowShouldClose()) {
        rl.UpdateCamera(&camera, rl.CAMERA_FREE);
        rl.SetShaderValue(
            shader,
            shader.locs[rl.SHADER_LOC_VECTOR_VIEW],
            &[3]f32{ camera.position.x, camera.position.y, camera.position.z },
            rl.SHADER_UNIFORM_VEC3,
        );

        for (0..rll.MAX_LIGHTS) |i| {
            rll.UpdateLightValues(shader, lights[i]);
        }

        rl.BeginDrawing();
        {
            rl.ClearBackground(rl.RAYWHITE);

            rl.BeginMode3D(camera);
            {
                rl.BeginShaderMode(shader);
                {
                    rl.DrawPlane(rl.Vector3Zero(), rl.Vector2{ .x = 10.0, .y = 10.0 }, rl.WHITE);
                    rl.DrawCube(rl.Vector3Zero(), 2.0, 4.0, 2.0, rl.WHITE);
                    for (models, 0..) |model, i| {
                        rl.DrawModel(model, vec3(@floatFromInt(i * 2), 0, 0), 1.0, rl.WHITE);
                    }
                }
                rl.EndShaderMode();

                for (0..rll.MAX_LIGHTS) |i| {
                    if (lights[i].enabled) {
                        rl.DrawSphereEx(lights[i].position, 0.2, 8, 8, lights[i].color);
                    } else {
                        rl.DrawSphereWires(lights[i].position, 0.2, 8, 8, rl.ColorAlpha(lights[i].color, 0.3));
                    }
                }

                rl.DrawSphere(camera.target, 0.05, rl.RED);

                rl.DrawGrid(25, 1.0);
            }
            rl.EndMode3D();
        }
        rl.EndDrawing();
    }
}
