const std = @import("std");

const PCGManager = @import("pcgmanager");
const Tile = PCGManager.Contents.Tile;
const Level = PCGManager.Contents.Level;
const Enemy = PCGManager.Contents.Enemy;

const rl = @import("raylib.zig");
const rll = @import("rlights.zig");

const EnemyInstance = struct {
    model: rl.Model,
    animation: rl.ModelAnimation,
    angle: f32,
    enemy: Enemy,
    active: bool,
    pos: rl.Vector2,
    health_points: f32,
    radius: f32,
    animation_frame: i32,
};

const Animations = struct {
    run: rl.ModelAnimation,
    idle: rl.ModelAnimation,
    attack: rl.ModelAnimation,
};

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
    enemies: std.ArrayList(EnemyInstance),
    doors: std.ArrayList(rl.Vector2),
    doors_open: bool,
    door_open: rl.Model,
    door_closed: rl.Model,

    enemy_models: std.EnumArray(Enemy.Type, ?rl.Model),
    enemy_animations: std.EnumArray(Enemy.Type, ?Animations),

    player_position: rl.Vector2,
    player_radius: f32,
    player_angle: f32,
    player_speed: f32,
    player_model: rl.Model,
    player_current_animation: rl.ModelAnimation,
    player_sprint_animation: rl.ModelAnimation,
    player_idle_animation: rl.ModelAnimation,
    player_animation_counter: i32,

    curr_room: ?rl.Rectangle,

    pub fn init(allocator: std.mem.Allocator, level: Level) !World {
        var self: World = undefined;
        self.level = level;
        self.models = std.ArrayList(rl.Model).init(allocator);
        self.models_animations = .init(allocator);

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

        self.doors_open = false;
        self.door_open = rl.LoadModel("assets/door_open.glb");
        try self.models.append(self.door_open);

        self.door_closed = rl.LoadModel("assets/door_closed.glb");
        try self.models.append(self.door_closed);

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

        self.enemy_models = .init(.{
            .slow_chaser = rl.LoadModel("assets/spider.glb"),
            .fast_chaser = rl.LoadModel("assets/rat.glb"),
            .shooter = rl.LoadModel("assets/snake.glb"),
            .walking_shooter = rl.LoadModel("assets/snake.glb"),
            .flyer = rl.LoadModel("assets/wasp.glb"),
        });

        for (self.enemy_models.values) |model_opt| {
            if (model_opt) |model| {
                try self.models.append(model);
            }
        }

        self.enemy_animations = .initUndefined();
        try load_animation(&self, .slow_chaser, "assets/spider.glb", 0, 2, 4);
        try load_animation(&self, .fast_chaser, "assets/rat.glb", 0, 2, 4);
        try load_animation(&self, .shooter, "assets/snake.glb", 0, 2, 4);
        try load_animation(&self, .walking_shooter, "assets/snake.glb", 0, 2, 4);
        try load_animation(&self, .flyer, "assets/wasp.glb", 0, 2, 2);

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
        try self.models_animations.append(player_animations);

        self.collidable_tiles = .init(allocator);
        self.doors = .init(allocator);
        for (0..self.level.tilemap.height) |y| {
            for (0..self.level.tilemap.width) |x| {
                const tile = self.level.tilemap.get(x, y);
                if (tile.is_collidable()) {
                    try self.collidable_tiles.append(vec2(@floatFromInt(x), @floatFromInt(y)));
                } else if (tile.* == .door) {
                    try self.doors.append(vec2(@floatFromInt(x), @floatFromInt(y)));
                } else if (tile.* == .entrance) {
                    self.player_position = vec2(@floatFromInt(x), @floatFromInt(y));
                    self.camera.target = to_world_pos(self.player_position);
                }
            }
        }

        self.enemies = .init(allocator);

        for (self.level.enemies.items) |e| {
            try self.enemies.append(EnemyInstance{
                .model = self.enemy_models.get(e.enemy.type).?,
                .animation = self.enemy_animations.get(e.enemy.type).?.run,
                .angle = 0.0,
                .enemy = e.enemy,
                .active = true,
                .health_points = e.enemy.health,
                .pos = vec2(@floatFromInt(e.pos.x), @floatFromInt(e.pos.y)),
                .radius = 0.1,
                .animation_frame = 0,
            });
        }

        for (self.enemies.items) |enemy|
            try self.models.append(enemy.model);

        for (self.models.items) |model|
            model.materials[1].shader = self.shader;

        return self;
    }

    pub fn deinit(self: World) void {
        rl.UnloadShader(self.shader);
        for (self.models.items) |model| rl.UnloadModel(model);
        for (self.models_animations.items) |animations| rl.UnloadModelAnimations(animations);
        self.models.deinit();
        self.enemies.deinit();
    }

    pub fn update(self: *World) void {
        self.curr_room = null;
        for (self.level.room_rects.items) |room_rec| {
            const rlrec = rl.Rectangle{ .x = room_rec.x - 0.5, .y = room_rec.y - 0.5, .width = room_rec.w, .height = room_rec.h };
            if (rl.CheckCollisionPointRec(self.player_position, rlrec)) {
                self.curr_room = rl.Rectangle{ .x = room_rec.x, .y = room_rec.y, .width = room_rec.w, .height = room_rec.h };
            }
        }

        const center = blk: {
            if (self.curr_room) |room| {
                break :blk vec2(room.x + (room.width / 2), room.y + (room.height / 2));
            } else {
                break :blk self.player_position;
            }
        };

        const dist = rl.Vector3Distance(self.camera.target, to_world_pos(center));
        self.camera.target = rl.Vector3MoveTowards(self.camera.target, to_world_pos(center), rl.logf(dist + 1.1) * 0.1);
        self.camera.position = rl.Vector3Add(self.camera.target, vec3(0, 8, 0.5));
        rl.UpdateCamera(&self.camera, rl.CAMERA_CUSTOM);
        rl.SetShaderValue(
            self.shader,
            self.shader.locs[rl.SHADER_LOC_VECTOR_VIEW],
            &[3]f32{ self.camera.position.x, self.camera.position.y, self.camera.position.z },
            rl.SHADER_UNIFORM_VEC3,
        );
        self.light.position = rl.Vector3Add(self.camera.position, vec3(5, 5, 5));
        rll.UpdateLightValues(self.shader, self.light);

        //freeze while not focusing on room center
        if (self.curr_room != null and rl.FloatEquals(dist, 0) == 0) {
            return;
        }

        self.doors_open = true;
        self.tile_models.set(.door, self.door_open);
        for (self.enemies.items) |*e| {
            if (self.curr_room != null and rl.CheckCollisionPointRec(e.pos, self.curr_room.?)) {
                self.doors_open = false;
                self.tile_models.set(.door, self.door_closed);
                break;
            }
        }

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
            var new_pos = rl.Vector2Add(self.player_position, rl.Vector2Scale(movement, delta * self.player_speed));
            new_pos = self.solve_collisions(new_pos, self.player_radius);
            self.player_position = new_pos;
            self.player_current_animation = self.player_sprint_animation;
            self.player_angle = rl.Vector2Angle(vec2(0, 1), movement) * -rl.RAD2DEG;
        } else {
            self.player_current_animation = self.player_idle_animation;
        }

        self.player_animation_counter += 1;
        rl.UpdateModelAnimation(self.player_model, self.player_current_animation, self.player_animation_counter);
        if (self.player_animation_counter >= self.player_current_animation.frameCount) self.player_animation_counter = 0;

        if (self.curr_room) |curr_room| {
            for (self.enemies.items) |*e| {
                if (!rl.CheckCollisionPointRec(e.pos, curr_room))
                    continue;

                const previous = e.pos;
                e.pos = rl.Vector2MoveTowards(e.pos, self.player_position, 5 * e.enemy.velocity * delta);
                e.pos = self.solve_collisions(e.pos, e.radius);
                e.angle = rl.Vector2Angle(vec2(0, 1), rl.Vector2Normalize(rl.Vector2Subtract(e.pos, previous))) * -rl.RAD2DEG;

                e.animation_frame += 1;
                rl.UpdateModelAnimation(e.model, e.animation, e.animation_frame);
                if (e.animation_frame >= e.animation.frameCount) e.animation_frame = 0;
            }
        }
    }

    pub fn render(self: World) void {
        // debug draw
        // rl.BeginDrawing();
        // defer rl.EndDrawing();
        // rl.ClearBackground(rl.DARKGRAY);
        // for (self.collidable_tiles.items) |pos| {
        //     const rec = rl.Rectangle{ .x = 10 * (pos.x - 0.5), .y = 10 * (pos.y - 0.5), .width = 10, .height = 10 };
        //     rl.DrawRectangleRec(rec, rl.RED);
        // }
        // rl.DrawCircleV(rl.Vector2Scale(self.player_position, 10), self.player_radius * 10, rl.WHITE);

        rl.BeginDrawing();
        rl.BeginMode3D(self.camera);
        {
            rl.ClearBackground(rl.DARKGRAY);

            for (0..self.level.tilemap.height) |y| {
                for (0..self.level.tilemap.width) |x| {
                    const tile = self.level.tilemap.get(x, y).*;
                    if (self.tile_models.get(tile)) |model| {
                        if (tile == .door) {
                            if (self.level.tilemap.get(x + 1, y).* == .door) {
                                rl.DrawModelEx(model, to_world_pos(vec2(@as(f32, @floatFromInt(x)) + 0.5, @floatFromInt(y))), vec3(0.0, 1.0, 0.0), 90.0, rl.Vector3One(), rl.WHITE);
                            }
                            if (self.level.tilemap.get(x, y + 1).* == .door) {
                                rl.DrawModel(model, World.to_world_pos(vec2(@floatFromInt(x), @as(f32, @floatFromInt(y)) + 0.5)), 1.0, rl.WHITE);
                            }
                        } else {
                            rl.DrawModel(model, World.to_world_pos(vec2(@floatFromInt(x), @floatFromInt(y))), 1.0, rl.WHITE);
                        }
                    }
                }
            }

            for (self.enemies.items) |e|
                rl.DrawModelEx(e.model, to_world_pos(e.pos), vec3(0, 1, 0), e.angle, rl.Vector3Scale(rl.Vector3One(), 0.2), rl.WHITE);

            rl.DrawModelEx(self.player_model, to_world_pos(self.player_position), vec3(0, 1, 0), self.player_angle, rl.Vector3Scale(rl.Vector3One(), 0.5), rl.WHITE);
            rl.DrawSphere(self.light.position, 0.15, rl.YELLOW);
            rl.DrawGrid(255, 0.9);
        }
        rl.EndMode3D();
        rl.EndDrawing();
    }

    fn to_world_pos_y(pos: rl.Vector2, y: f32) rl.Vector3 {
        return vec3(pos.x * 0.90, y, pos.y * 0.90);
    }

    fn to_world_pos(pos: rl.Vector2) rl.Vector3 {
        return vec3(pos.x * 0.90, 0, pos.y * 0.90);
    }

    fn solve_collisions(self: *World, circ: rl.Vector2, radius: f32) rl.Vector2 {
        const new_pos = solve_collisions_impl(circ, radius, self.collidable_tiles);
        return if (self.doors_open) new_pos else solve_collisions_impl(new_pos, radius, self.doors);
    }

    fn solve_collisions_impl(circ: rl.Vector2, radius: f32, tiles: std.ArrayList(rl.Vector2)) rl.Vector2 {
        var res = circ;
        for (tiles.items) |pos| {
            const rec = rl.Rectangle{ .x = pos.x - 0.5, .y = pos.y - 0.5, .width = 1, .height = 1 };
            if (rl.CheckCollisionCircleRec(circ, radius, rec)) {
                const a = vec2(rec.x, rec.y); //upper coner
                const b = vec2(rec.x + rec.width, rec.y + rec.height); //lower corner

                if (circ.x < a.x and circ.y > a.y and circ.y < b.y) {
                    res.x = a.x - radius;
                } else if (circ.x > b.x and circ.y > a.y and circ.y < b.y) {
                    res.x = b.x + radius;
                } else if (circ.y < a.y and circ.x > a.x and circ.x < b.x) {
                    res.y = a.y - radius;
                } else if (circ.y > b.y and circ.x > a.x and circ.x < b.x) {
                    res.y = b.y + radius;
                }
            }
        }
        return res;
    }

    fn load_animation(self: *World, enemy_type: Enemy.Type, name: []const u8, atk_idx: usize, idle_idx: usize, run_idx: usize) !void {
        var anim_count: i32 = 0;
        const anims = rl.LoadModelAnimations(@ptrCast(name), @ptrCast(&anim_count));
        self.enemy_animations.set(enemy_type, Animations{ .attack = anims[atk_idx], .idle = anims[idle_idx], .run = anims[run_idx] });
        try self.models_animations.append(anims);
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
        world.update();
        world.render();
    }
}
