const std = @import("std");
const builtin = @import("builtin");

const PCGManager = @import("pcgmanager");
const Tile = PCGManager.Contents.Tile;
const Level = PCGManager.Contents.Level;
const Enemy = PCGManager.Contents.Enemy;
const Direction = PCGManager.Contents.Direction;

const c = @import("commons.zig");
const vec2 = c.vec2;
const vec3 = c.vec3;
const Player = @import("Player.zig");
const Npc = @import("Npc.zig");
const rl = @import("raylib.zig");
const rll = @import("rlights.zig");
const Spotlight = @import("Spotlight.zig");

const glsl_version: i32 = if (builtin.target.cpu.arch.isWasm()) 100 else 330;

var g_world: ?*Self = undefined;

const Self = @This();
const Bullet = struct {
    to_remove: bool,
    pos: rl.Vector2,
    vector: rl.Vector2,
    dmg: i32,
};

const EnemyInstance = struct {
    alive: bool,
    model: rl.Model,
    animation: rl.ModelAnimation,
    angle: f32,
    enemy: Enemy,
    active: bool,
    pos: rl.Vector2,
    health_points: f32,
    radius: f32,
    animation_frame: i32,
    inertia: rl.Vector2,
    shooting_cooldown: f32,
    flyer_move_target: ?rl.Vector2,
};

pub const Animations = struct {
    vec: *rl.ModelAnimation,
    size: usize,
};

const EnemyAnimations = struct {
    run: rl.ModelAnimation,
    idle: rl.ModelAnimation,
    attack: rl.ModelAnimation,
};

const TileInstance = struct {
    tile: Tile,
    pos: rl.Vector2,
};

const Exit = struct {
    pos: rl.Vector2,
    dir: Direction,
};

const window_w = 800;
const window_h = 600;
const max_spots = 3;

level: Level,
tile_models: std.EnumArray(Tile, ?rl.Model),
models: std.ArrayList(rl.Model),
models_animations: std.ArrayList(Animations),
collidable_tiles: std.ArrayList(TileInstance),

camera: rl.Camera3D,
player: Player,
curr_room: ?rl.Rectangle,
exits: std.ArrayList(Exit),

npcs: std.ArrayList(Npc),

enemies: std.ArrayList(EnemyInstance),
enemy_models: std.EnumArray(Enemy.Type, ?rl.Model),
enemy_animations: std.EnumArray(Enemy.Type, ?EnemyAnimations),
bullets: std.ArrayList(Bullet),
bullet_model: rl.Model,

shader: rl.Shader,
light: rll.Light,

spotlight: rl.Shader,
spotlights: [max_spots]Spotlight,
spotlight_open: bool,

doors_open: bool,
door_open: rl.Model,
door_closed: rl.Model,

finished: bool,

pub fn init(allocator: std.mem.Allocator, level: Level) !Self {
    var self: Self = undefined;
    self.level = level;
    self.models = std.ArrayList(rl.Model).init(allocator);
    self.models_animations = .init(allocator);
    self.exits = .init(allocator);
    self.bullets = .init(allocator);
    self.bullet_model = rl.LoadModel("assets/bullet.glb");
    self.npcs = .init(allocator);
    try self.models.append(self.bullet_model);
    self.finished = false;

    self.camera = rl.Camera3D{
        .position = vec3(10.0, 5.0, 10.0),
        .target = to_world_pos(self.player.position),
        .up = vec3(0.0, 1.0, 0.0),
        .fovy = 60.0,
        .projection = rl.CAMERA_PERSPECTIVE,
    };
    self.shader = rl.LoadShader(
        rl.TextFormat("assets/shaders/glsl%i/lighting.vs", glsl_version),
        rl.TextFormat("assets/shaders/glsl%i/lighting.fs", glsl_version),
    );

    self.light = rll.CreateLight(rll.Light.Type.point, rl.Vector3Zero(), rl.Vector3Zero(), rl.WHITE, self.shader);
    const ambientLoc = rl.GetShaderLocation(self.shader, "ambient");
    rl.SetShaderValue(self.shader, ambientLoc, &[4]f32{ 2.0, 2.0, 2.0, 10.0 }, rl.SHADER_UNIFORM_VEC4);

    self.spotlight = rl.LoadShader(null, rl.TextFormat("assets/shaders/glsl%i/spotlight.fs", glsl_version));
    const wloc = rl.GetShaderLocation(self.spotlight, "screenWidth");
    var sw: f32 = @floatFromInt(rl.GetScreenWidth() * 2);
    rl.SetShaderValue(self.spotlight, wloc, &sw, rl.SHADER_UNIFORM_FLOAT);
    for (&self.spotlights, 0..) |*spot, i|
        spot.* = .init(@intCast(i), 0, 0, self.spotlight);
    self.spotlight_open = true;

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
        .size = null,
    });

    for (self.tile_models.values) |model_opt| {
        if (model_opt) |model| {
            try self.models.append(model);
        }
    }

    self.enemy_models = .init(.{
        .slow_chaser = rl.LoadModel("assets/spider.glb"),
        .fast_chaser = rl.LoadModel("assets/spider.glb"),
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
    try load_animation(&self, .fast_chaser, "assets/spider.glb", 0, 2, 4);
    try load_animation(&self, .shooter, "assets/snake.glb", 0, 2, 4);
    try load_animation(&self, .walking_shooter, "assets/snake.glb", 0, 2, 4);
    try load_animation(&self, .flyer, "assets/wasp.glb", 0, 2, 2);

    self.player = try .init(&self.models, &self.models_animations);

    self.collidable_tiles = .init(allocator);
    for (0..self.level.tilemap.height) |y| {
        for (0..self.level.tilemap.width) |x| {
            const tile = self.level.tilemap.get(x, y);
            if (tile.is_collidable())
                try self.collidable_tiles.append(.{ .tile = tile.*, .pos = vec2(@floatFromInt(x), @floatFromInt(y)) });
        }
    }

    self.enemies = .init(allocator);
    for (self.level.placeholders.items) |ph| {
        switch (ph.entity) {
            .enemy => |enemy| {
                try self.enemies.append(EnemyInstance{
                    .alive = true,
                    .model = self.enemy_models.get(enemy.type).?,
                    .animation = self.enemy_animations.get(enemy.type).?.run,
                    .angle = 0.0,
                    .enemy = enemy,
                    .active = true,
                    .health_points = 100 * enemy.health,
                    .pos = vec2(@floatFromInt(ph.position.x), @floatFromInt(ph.position.y)),
                    .radius = 0.3,
                    .animation_frame = 0,
                    .inertia = rl.Vector2Zero(),
                    .shooting_cooldown = 0,
                    .flyer_move_target = null,
                });
            },
            .player => {
                self.player.position = vec2(@floatFromInt(ph.position.x), @floatFromInt(ph.position.y));
                self.camera.target = to_world_pos(self.player.position);
            },
            .exit => |exit| {
                try self.exits.append(.{ .dir = exit, .pos = vec2(@floatFromInt(ph.position.x), @floatFromInt(ph.position.y)) });
            },
            .npc => |npc| {
                try self.npcs.append(try .init(
                    vec2(@floatFromInt(ph.position.x), @floatFromInt(ph.position.y)),
                    npc.dialog,
                    &self.models,
                    &self.models_animations,
                ));
            },
            .item => {},
        }
    }

    for (self.models.items) |model|
        model.materials[1].shader = self.shader;

    return self;
}

pub fn deinit(self: Self) void {
    std.debug.print("DEINIT\n", .{});
    rl.UnloadShader(self.shader);
    rl.UnloadShader(self.spotlight);
    for (self.models.items) |model| rl.UnloadModel(model);
    for (self.models_animations.items) |animations| rl.UnloadModelAnimations(animations.vec, @intCast(animations.size));
    self.models.deinit();
    self.models_animations.deinit();
    self.collidable_tiles.deinit();
    self.enemies.deinit();
    self.bullets.deinit();
    self.exits.deinit();
    self.npcs.deinit();
}

pub fn update(self: *Self) !void {
    set(self);

    self.curr_room = null;
    for (self.level.room_rects.items) |room_rec| {
        const rlrec = rl.Rectangle{ .x = room_rec.x - 0.5, .y = room_rec.y - 0.5, .width = room_rec.w, .height = room_rec.h };
        if (rl.CheckCollisionPointRec(self.player.position, rlrec)) {
            self.curr_room = rl.Rectangle{ .x = room_rec.x, .y = room_rec.y, .width = room_rec.w, .height = room_rec.h };
        }
    }

    var center = self.camera.target;
    if (self.curr_room) |room| {
        center = to_world_pos(vec2(room.x + (room.width / 2) - 0.5, room.y + (room.height / 2)));
    } else if (self.player.exiting_direction == null) {
        center = to_world_pos(self.player.position);
    }

    const dist = rl.Vector3Distance(self.camera.target, center);
    self.camera.target = rl.Vector3MoveTowards(self.camera.target, center, rl.logf(dist + 1.1) * 0.1);
    // self.camera.position = rl.Vector3Add(self.camera.target, vec3(0, 8, 0.5));
    self.camera.position = rl.Vector3Add(self.camera.target, vec3(0, 9, 0.5));
    rl.UpdateCamera(&self.camera, rl.CAMERA_CUSTOM);
    rl.SetShaderValue(
        self.shader,
        self.shader.locs[rl.SHADER_LOC_VECTOR_VIEW],
        &[3]f32{ self.camera.position.x, self.camera.position.y, self.camera.position.z },
        rl.SHADER_UNIFORM_VEC3,
    );
    self.light.position = rl.Vector3Add(self.camera.position, vec3(5, 5, 5));
    rll.UpdateLightValues(self.shader, self.light);

    for (&self.spotlights) |*spot| {
        self.finished = self.player.exiting_direction != null and spot.radius == 0;

        if (self.spotlight_open) {
            spot.radius += 5;
        } else {
            spot.radius -= 5;
        }
        spot.radius = rl.Clamp(spot.radius, 0, (c.window_diagonal / 2) + 50);
        spot.position.x = c.window_w / 2;
        spot.position.y = c.window_h / 2;
        spot.inner = spot.radius - 50;
        spot.update(self.spotlight);
    }

    self.doors_open = true;
    self.tile_models.set(.door, self.door_open);
    for (self.enemies.items) |*e| {
        if (e.alive and self.curr_room != null and rl.CheckCollisionPointRec(e.pos, self.curr_room.?)) {
            self.doors_open = false;
            self.tile_models.set(.door, self.door_closed);
            break;
        }
    }

    //freeze while not focusing on room center
    if (self.curr_room != null and rl.FloatEquals(dist, 0) == 0) {
        return;
    }

    const delta = rl.GetFrameTime();

    self.player.update();
    self.player.position = self.solve_collisions(self.player.position, self.player.radius);

    if (rl.IsKeyPressed(rl.KEY_K)) {
        self.spotlight_open = !self.spotlight_open;
    }

    if (self.curr_room) |curr_room| {
        for (self.enemies.items) |*e| {
            if (!e.alive or !rl.CheckCollisionPointRec(e.pos, curr_room))
                continue;

            if (e.enemy.type == .shooter or e.enemy.type == .walking_shooter) {
                if (e.shooting_cooldown <= 0) {
                    e.shooting_cooldown = 2.3 - (e.enemy.shooting_velocity * 2);
                    try self.bullets.append(.{
                        .to_remove = false,
                        .dmg = @intFromFloat(e.enemy.damage * 50),
                        .pos = e.pos,
                        .vector = rl.Vector2Scale(rl.Vector2Normalize(rl.Vector2Subtract(self.player.position, e.pos)), 0.1),
                    });
                } else {
                    e.shooting_cooldown -= delta;
                }
            }

            if (rl.Vector2Equals(e.inertia, rl.Vector2Zero()) == 0) {
                e.pos = rl.Vector2Add(e.pos, e.inertia);
                e.pos = self.solve_collisions(e.pos, e.radius);
                e.inertia = rl.Vector2Scale(e.inertia, 0.5);
            } else if (rl.CheckCollisionCircles(self.player.position, self.player.radius, e.pos, e.radius)) {
                self.player.take_hit(@intFromFloat(e.enemy.damage * 50));
            } else if (e.enemy.type == .flyer) {
                const previous = e.pos;
                if (e.flyer_move_target == null or rl.Vector2Equals(e.flyer_move_target.?, e.pos) == 1) {
                    var new_target = e.pos;
                    const angle = @as(f32, @floatFromInt(rl.GetRandomValue(0, 360))) * rl.DEG2RAD;
                    new_target = self.solve_collisions_flyer(rl.Vector2MoveTowards(new_target, rl.Vector2Add(new_target, rl.Vector2Rotate(vec2(0, 1), angle)), 0.5), e.radius);
                    new_target = self.solve_collisions_flyer(rl.Vector2MoveTowards(new_target, self.player.position, 0.5), e.radius);
                    e.flyer_move_target = self.solve_collisions_flyer(new_target, e.radius);
                }

                //in case it gets stuck
                e.flyer_move_target = rl.Vector2MoveTowards(e.flyer_move_target.?, e.pos, 0.1 * delta);
                e.pos = rl.Vector2MoveTowards(e.pos, e.flyer_move_target.?, 5 * e.enemy.velocity * delta);
                e.pos = self.solve_collisions_flyer(e.pos, e.radius);
                e.angle = rl.Vector2Angle(vec2(0, 1), rl.Vector2Normalize(rl.Vector2Subtract(e.pos, previous))) * -rl.RAD2DEG;
            } else {
                const previous = e.pos;
                e.pos = rl.Vector2MoveTowards(e.pos, self.player.position, 5 * e.enemy.velocity * delta);
                e.pos = self.solve_collisions(e.pos, e.radius);
                e.angle = rl.Vector2Angle(vec2(0, 1), rl.Vector2Normalize(rl.Vector2Subtract(e.pos, previous))) * -rl.RAD2DEG;
            }

            e.animation_frame += 1;
            rl.UpdateModelAnimation(e.model, e.animation, e.animation_frame);
            if (e.animation_frame >= e.animation.frameCount) e.animation_frame = 0;
        }
    }

    for (self.bullets.items) |*e| {
        e.pos = rl.Vector2Add(e.pos, e.vector);
        if (self.curr_room != null and !rl.CheckCollisionPointRec(e.pos, self.curr_room.?)) {
            e.to_remove = true;
        } else if (rl.CheckCollisionCircles(self.player.position, self.player.radius, e.pos, 0.2)) {
            self.player.take_hit(e.dmg);
            e.to_remove = true;
        }
    }

    var new_bullets: @TypeOf(self.bullets) = .init(self.bullets.allocator);
    for (self.bullets.items) |e| {
        if (!e.to_remove) {
            try new_bullets.append(e);
        }
    }
    self.bullets.deinit();
    self.bullets = new_bullets;

    for (self.npcs.items) |*npc| npc.update();
}

pub fn render(self: Self) void {
    rl.BeginDrawing();
    defer rl.EndDrawing();

    {
        rl.BeginMode3D(self.camera);
        defer rl.EndMode3D();

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
                            rl.DrawModel(model, Self.to_world_pos(vec2(@floatFromInt(x), @as(f32, @floatFromInt(y)) + 0.5)), 1.0, rl.WHITE);
                        }
                    } else {
                        rl.DrawModel(model, Self.to_world_pos(vec2(@floatFromInt(x), @floatFromInt(y))), 1.0, rl.WHITE);
                    }
                }
            }
        }

        for (self.enemies.items) |e| {
            if (!e.alive) continue;
            rl.DrawModelEx(e.model, to_world_pos(e.pos), vec3(0, 1, 0), e.angle, rl.Vector3Scale(rl.Vector3One(), 0.2), rl.WHITE);
        }

        for (self.bullets.items) |e| {
            const angle = rl.Vector2Angle(vec2(0, 1), rl.Vector2Normalize(e.vector)) * -rl.RAD2DEG;
            rl.DrawModelEx(self.bullet_model, to_world_pos(e.pos), vec3(0, 1, 0), angle, rl.Vector3Scale(rl.Vector3One(), 0.3), rl.WHITE);
        }

        self.player.render();

        for (self.npcs.items) |npc| npc.render();

        rl.DrawSphere(self.light.position, 0.15, rl.YELLOW);
    }

    const life: f32 = @as(f32, @floatFromInt(self.player.health)) / @as(f32, @floatFromInt(Player.max_health));
    rl.DrawRectangle(20, 20, 110, 30, rl.BLACK);
    rl.DrawRectangle(25, 25, 100, 20, rl.GRAY);
    rl.DrawRectangle(25, 25, @as(i32, @intFromFloat(life * 100.0)), 20, rl.RED);
    rl.DrawText("HP", 25, 25, 20, rl.WHITE);

    {
        rl.BeginShaderMode(self.spotlight);
        defer rl.EndShaderMode();
        rl.DrawRectangle(0, 0, c.window_w, c.window_h, rl.WHITE);
    }
}

pub fn get() *Self {
    std.debug.assert(g_world != null);
    return g_world.?;
}

fn set(world: *Self) void {
    g_world = world;
}

fn to_world_pos_y(pos: rl.Vector2, y: f32) rl.Vector3 {
    return vec3(pos.x * 0.90, y, pos.y * 0.90);
}

pub fn to_world_pos(pos: rl.Vector2) rl.Vector3 {
    return vec3(pos.x * 0.90, 0, pos.y * 0.90);
}

fn solve_collisions_flyer(self: *Self, circ: rl.Vector2, radius: f32) rl.Vector2 {
    return self.solve_collisions_impl(circ, radius, true);
}

fn solve_collisions(self: *Self, circ: rl.Vector2, radius: f32) rl.Vector2 {
    return self.solve_collisions_impl(circ, radius, false);
}

fn solve_collisions_impl(self: *Self, circ: rl.Vector2, radius: f32, is_flyer: bool) rl.Vector2 {
    const r = radius;
    var res = circ;
    for (self.collidable_tiles.items) |tile| {
        if (self.doors_open and tile.tile == .door) continue;
        if (is_flyer and tile.tile == .ocean) continue;

        const rec = rl.Rectangle{ .x = tile.pos.x - 0.5, .y = tile.pos.y - 0.5, .width = 1, .height = 1 };
        if (rl.CheckCollisionCircleRec(circ, r, rec)) {
            const a = vec2(rec.x, rec.y); //upper coner
            const b = vec2(rec.x + rec.width, rec.y + rec.height); //lower corner

            if (circ.x - r < a.x and circ.y > a.y and circ.y < b.y) {
                res.x = a.x - r;
            } else if (circ.x + r > b.x and circ.y > a.y and circ.y < b.y) {
                res.x = b.x + r;
            }
            if (circ.y - r < a.y and circ.x > a.x and circ.x < b.x) {
                res.y = a.y - r;
            } else if (circ.y + r > b.y and circ.x > a.x and circ.x < b.x) {
                res.y = b.y + r;
            }
        }
    }
    return res;
}

fn load_animation(self: *Self, enemy_type: Enemy.Type, name: []const u8, atk_idx: usize, idle_idx: usize, run_idx: usize) !void {
    var anim_count: i32 = 0;
    const anims = rl.LoadModelAnimations(@ptrCast(name), @ptrCast(&anim_count));
    self.enemy_animations.set(enemy_type, EnemyAnimations{ .attack = anims[atk_idx], .idle = anims[idle_idx], .run = anims[run_idx] });
    try self.models_animations.append(.{ .vec = anims, .size = @intCast(anim_count) });
}
