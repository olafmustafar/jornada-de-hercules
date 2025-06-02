const std = @import("std");
const rl = @import("raylib.zig");
const rll = @import("rlights.zig");
const PCGManager = @import("pcgmanager");

const Tile = PCGManager.Contents.Tile;
const Level = PCGManager.Contents.Level;

const window_w = 800;
const window_h = 600;

pub fn vec3(x: f32, y: f32, z: f32) rl.Vector3 {
    return rl.Vector3{ .x = x, .y = y, .z = z };
}

pub fn vec2(x: f32, y: f32) rl.Vector2 {
    return rl.Vector2{ .x = x, .y = y };
}

const World = struct {
    level: Level,
    models: std.ArrayList(rl.Model),
    models_animations: std.ArrayList(*rl.ModelAnimation),
    tile_models: std.EnumArray(Tile, ?rl.Model),
    shader: rl.Shader,
    light: rll.Light,
    camera: rl.Camera3D,
    collidable_tiles: std.ArrayList(rl.Vector2),

    player_position: rl.Vector2,
    player_radius: f32,
    player_angle: f32,
    player_speed: f32,
    player_model: rl.Model,
    player_current_animation: rl.ModelAnimation,
    player_sprint_animation: rl.ModelAnimation,
    player_idle_animation: rl.ModelAnimation,
    player_animation_counter: i32,

    pub fn init(allocator: std.mem.Allocator, level: Level) !World {
        var self: World = undefined;
        self.level = level;
        self.models = std.ArrayList(rl.Model).init(allocator);
        self.models_animations = std.ArrayList(*rl.ModelAnimation).init(allocator);

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

        self.tile_models = .init(.{
            .empty = null,
            .plane = rl.LoadModel("assets/plane_sqrt.glb"),
            .mountain = rl.LoadModel("assets/mountain_sqr.glb"),
            .sand = rl.LoadModel("assets/sand_sqr.glb"),
            .trees = rl.LoadModel("assets/trees_srq.glb"),
            .ocean = rl.LoadModel("assets/ocean_sqr.glb"),
            .wall = rl.LoadModel("assets/wall_sqr.glb"),
            .door = null,
            .entrance = null,
            .size = null,
        });

        for (self.tile_models.values) |model_opt| {
            if (model_opt) |model| {
                try self.models.append(model);
            }
        }

        self.player_model = rl.LoadModel("assets/player2.glb");
        try self.models.append(self.player_model);
        var animation_count: usize = 0;
        const player_animations = rl.LoadModelAnimations("assets/player2.glb", @ptrCast(&animation_count));
        self.player_sprint_animation = player_animations[38];
        self.player_idle_animation = player_animations[9];
        self.player_current_animation = self.player_idle_animation;
        self.player_animation_counter = 0;
        self.player_position = vec2(0, 0);
        self.player_radius = 0.1;
        self.player_angle = 0.00;
        self.player_speed = 3.00;

        self.collidable_tiles = .init(allocator);
        for (0..self.level.height) |y| {
            for (0..self.level.width) |x| {
                const tile = self.level.get(x, y);
                if (tile.is_collidable()) {
                    try self.collidable_tiles.append(vec2(@floatFromInt(x), @floatFromInt(y)));
                }
                if (tile.* == .entrance) {
                    self.player_position = vec2(@floatFromInt(x), @floatFromInt(y));
                }
            }
        }

        for (self.models.items) |model|
            model.materials[1].shader = self.shader;

        return self;
    }

    pub fn deinit(self: World) void {
        rl.UnloadShader(self.shader);
        for (self.models.items) |model| rl.UnloadModel(model);
        for (self.models_animations.items) |animations| rl.UnloadModelAnimations(animations);
        self.models.deinit();
    }

    pub fn update(self: *World) void {
        self.camera.target = to_world_pos(self.player_position);
        self.camera.position = rl.Vector3Add(to_world_pos(self.player_position), vec3(0, 7, 1));
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
        if ((rl.Vector2Equals(movement, rl.Vector2Zero())) == 0) {
            movement = rl.Vector2Normalize(movement);

            for (self.collidable_tiles.items) |pos| {
                const rec = rl.Rectangle{ .x = pos.x - 0.5, .y = pos.y - 0.5, .width = 1, .height = 1 };
                if (rl.CheckCollisionCircleRec(self.player_position, self.player_radius, rec)) {
                    if (movement.y > 0 and
                        (self.player_position.y - self.player_radius < rec.y) and
                        (self.player_position.y + self.player_radius > rec.y))
                    {
                        movement.y = 0;
                    }

                    if (movement.y < 0 and
                        (self.player_position.y - self.player_radius < rec.y + rec.height) and
                        (self.player_position.y + self.player_radius > rec.y + rec.height))
                    {
                        movement.y = 0;
                    }

                    if (movement.x > 0 and
                        (self.player_position.x - self.player_radius < rec.x) and
                        (self.player_position.x + self.player_radius > rec.x))
                    {
                        movement.x = 0;
                    }

                    if (movement.x < 0 and
                        (self.player_position.x - self.player_radius < rec.x + rec.width) and
                        (self.player_position.x + self.player_radius > rec.x + rec.width))
                    {
                        movement.x = 0;
                    }
                }
            }

            self.player_position = rl.Vector2Add(self.player_position, rl.Vector2Scale(movement, delta * self.player_speed));
            self.player_current_animation = self.player_sprint_animation;
            self.player_angle = rl.Vector2Angle(vec2(0, 1), movement) * -rl.RAD2DEG;
        } else {
            self.player_current_animation = self.player_idle_animation;
        }
        self.player_animation_counter += 1;
        rl.UpdateModelAnimation(self.player_model, self.player_current_animation, self.player_animation_counter);
        if (self.player_animation_counter >= self.player_current_animation.frameCount) self.player_animation_counter = 0;
    }

    pub fn render(self: World) void {
        rl.BeginDrawing();
        rl.BeginMode3D(self.camera);
        {
            rl.ClearBackground(rl.DARKGRAY);

            for (0..self.level.height) |y| {
                for (0..self.level.width) |x| {
                    const tile = self.level.get(x, y).*;
                    if (self.tile_models.get(tile)) |model| {
                        rl.DrawModel(
                            model,
                            World.to_world_pos(vec2(@floatFromInt(x), @floatFromInt(y))),
                            1.0,
                            rl.WHITE,
                        );
                    }
                }
            }
            rl.DrawModelEx(self.player_model, to_world_pos(self.player_position), vec3(0, 1, 0), self.player_angle, rl.Vector3Scale(rl.Vector3One(), 0.5), rl.WHITE);
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
        world.update();
        world.render();
    }
}
