const std = @import("std");
const rl = @import("raylib.zig");
const rll = @import("rlights.zig");

const window_w = 800;
const window_h = 600;

const Tile = enum { plane, mountain, sand, trees, ocean, count };
const Tilemap = [100][100]Tile;

pub fn vec3(x: f32, y: f32, z: f32) rl.Vector3 {
    return rl.Vector3{ .x = x, .y = y, .z = z };
}

pub fn vec2(x: f32, y: f32) rl.Vector2 {
    return rl.Vector2{ .x = x, .y = y };
}

const World = struct {
    tilemap: Tilemap,
    models: [@intFromEnum(Tile.count)]rl.Model,
    shader: rl.Shader,
    light: rll.Light,
    camera: rl.Camera3D,
    player_position: rl.Vector2,
    player_speed: f32,

    pub fn init() World {
        var self: World = undefined;

        self.player_position = vec2(0, 0);
        self.player_speed = 2.00;

        self.camera = rl.Camera3D{
            .position = vec3(10.0, 5.0, 10.0),
            .target = to_world_pos(self.player_position),
            .up = vec3(0.0, 1.0, 0.0),
            .fovy = 60.0,
            .projection = rl.CAMERA_PERSPECTIVE,
        };

        self.shader = rl.LoadShader("assets/shaders/glsl100/lighting.vs", "assets/shaders/glsl100/lighting.fs");
        self.light = rll.CreateLight(rll.Light.Type.point, rl.Vector3Zero(), rl.Vector3Zero(), rl.WHITE, self.shader);

        const ambientLoc = rl.GetShaderLocation(self.shader, "ambient");
        rl.SetShaderValue(self.shader, ambientLoc, &[4]f32{ 2.0, 2.0, 2.0, 10.0 }, rl.SHADER_UNIFORM_VEC4);

        self.models = [_]rl.Model{
            rl.LoadModel("assets/mountain_sqr.glb"),
            rl.LoadModel("assets/ocean_sqr.glb"),
            rl.LoadModel("assets/plane_sqrt.glb"),
            rl.LoadModel("assets/sand_sqr.glb"),
            rl.LoadModel("assets/trees_srq.glb"),
        };
        for (self.models) |model| {
            model.materials[1].shader = self.shader;
        }

        for (&self.tilemap) |*row| {
            for (row) |*tile| {
                tile.* = @enumFromInt(rl.GetRandomValue(0, self.models.len - 1));
            }
        }

        return self;
    }

    pub fn deinit(self: World) void {
        rl.UnloadShader(self.shader);
        for (self.models) |model| rl.UnloadModel(model);
    }

    pub fn update(self: *World) void {
        self.camera.target = to_world_pos(self.player_position);
        self.camera.position = rl.Vector3Add(to_world_pos(self.player_position), vec3(0, 5, 5));
        rl.UpdateCamera(&self.camera, rl.CAMERA_CUSTOM);
        rl.SetShaderValue(
            self.shader,
            self.shader.locs[rl.SHADER_LOC_VECTOR_VIEW],
            &[3]f32{ self.camera.position.x, self.camera.position.y, self.camera.position.z },
            rl.SHADER_UNIFORM_VEC3,
        );

        self.light.position = rl.Vector3Add(self.camera.position, vec3(5, 5, 5));
        rll.UpdateLightValues(self.shader, self.light);

        const delta = rl.GetFrameTime();
        var movement = rl.Vector2Zero();
        if (rl.IsKeyDown(rl.KEY_D) or rl.IsKeyDown(rl.KEY_RIGHT)) {
            movement = rl.Vector2Add(movement, vec2(1, 0));
        }
        if (rl.IsKeyDown(rl.KEY_A) or rl.IsKeyDown(rl.KEY_LEFT)) {
            movement = rl.Vector2Add(movement, vec2(-1, 0));
        }
        if (rl.IsKeyDown(rl.KEY_W) or rl.IsKeyDown(rl.KEY_UP)) {
            movement = rl.Vector2Add(movement, vec2(0, -1));
        }
        if (rl.IsKeyDown(rl.KEY_S) or rl.IsKeyDown(rl.KEY_DOWN)) {
            movement = rl.Vector2Add(movement, vec2(0, 1));
        }
        self.player_position = rl.Vector2Add(self.player_position, rl.Vector2Scale(rl.Vector2Normalize(movement), delta * self.player_speed));
    }

    pub fn render(self: World) void {
        rl.BeginDrawing();
        rl.BeginMode3D(self.camera);
        {
            rl.ClearBackground(rl.DARKGRAY);

            for (self.tilemap, 0..) |row, i|
                for (row, 0..) |tile, j|
                    rl.DrawModel(
                        self.models[@intFromEnum(tile)],
                        World.to_world_pos(vec2(@floatFromInt(i), @floatFromInt(j))),
                        1.0,
                        rl.WHITE,
                    );

            rl.DrawSphere(self.camera.target, 0.05, rl.RED);
            rl.DrawSphere(self.light.position, 0.15, rl.YELLOW);
            rl.DrawGrid(25, 1.0);
        }
        rl.EndMode3D();
        rl.EndDrawing();
    }

    fn to_world_pos(pos: rl.Vector2) rl.Vector3 {
        return vec3(pos.x * 0.90, 0, pos.y * 0.90);
    }
};

pub fn main() !void {
    rl.InitWindow(window_w, window_h, "raylib [core] example - basic window");
    rl.SetTargetFPS(60);
    rl.DisableCursor();
    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    defer rl.CloseWindow();

    var world = World.init();

    while (!rl.WindowShouldClose()) {
        world.update();
        world.render();
    }
}
