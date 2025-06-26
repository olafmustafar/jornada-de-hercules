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
const Dialog = @import("Dialog.zig");
const EnemyInstance = @import("EnemyInstance.zig");

const glsl_version: i32 = if (builtin.target.cpu.arch.isWasm()) 100 else 330;

var g_world: ?*Self = undefined;

const Self = @This();

pub const Stats = struct {
    bullets_shot: i32 = 0,
    bullets_hit: i32 = 0,
    enemies_activated: i32 = 0,
    enemies_hit_player: i32 = 0,
};

pub const BossType = enum {
    lion,
    hydra,
    stag,
};

const Bullet = struct {
    alive: bool,
    pos: rl.Vector2,
    vector: rl.Vector2,
    dmg: i32,
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
level_tint: rl.Color,
tile_models: std.EnumArray(Tile, ?rl.Model),
models: std.ArrayList(rl.Model),
models_animations: std.ArrayList(Animations),
collidable_tiles: std.ArrayList(TileInstance),

camera: rl.Camera3D,
player: Player,
curr_room: ?rl.Rectangle,
exits: std.ArrayList(Exit),

stats: Stats,

npcs: std.ArrayList(Npc),

boss_type: BossType,
enemies: std.ArrayList(EnemyInstance),
enemy_models: std.EnumArray(Enemy.Type, ?rl.Model),
enemy_animations: std.EnumArray(Enemy.Type, ?EnemyAnimations),
bullets: std.ArrayList(Bullet),
bullet_model: rl.Model,
hydra_body: ?rl.Model,

shader: rl.Shader,
light: rll.Light,

spotlight: rl.Shader,
spotlights: [max_spots]Spotlight,
spotlight_open: bool,

doors_open: bool,
door_open: rl.Model,
door_closed: rl.Model,

dialog: ?Dialog,
display_debug: bool = false,

arrows_controls_texture: rl.Texture2D,
attack_controls_texture: rl.Texture2D,

finished: bool,

pub fn init(
    allocator: std.mem.Allocator,
    level: Level,
    boss_type: BossType,
    level_tint: rl.Color,
    tile_models: std.EnumArray(Tile, ?[]const u8),
) !Self {
    var self: Self = undefined;
    self.level = level;
    self.level_tint = level_tint;
    self.boss_type = boss_type;
    self.models = std.ArrayList(rl.Model).init(allocator);
    self.models_animations = .init(allocator);
    self.exits = .init(allocator);
    self.bullets = .init(allocator);
    self.bullet_model = rl.LoadModel("assets/bullet.glb");
    self.npcs = .init(allocator);
    self.dialog = null;
    self.stats = Stats{};
    try self.models.append(self.bullet_model);
    self.finished = false;

    const arrow_ctrl_img = rl.LoadImage("assets/arrow_controls.png");
    defer rl.UnloadImage(arrow_ctrl_img);
    self.arrows_controls_texture = rl.LoadTextureFromImage(arrow_ctrl_img);

    const attack_ctrl_img = rl.LoadImage("assets/attack_controls.png");
    defer rl.UnloadImage(attack_ctrl_img);
    self.attack_controls_texture = rl.LoadTextureFromImage(attack_ctrl_img);

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
    const ambientLoc = rl.GetShaderLocation(self.shader, "ambient");
    rl.SetShaderValue(self.shader, ambientLoc, &[4]f32{ 2.0, 2.0, 2.0, 10.0 }, rl.SHADER_UNIFORM_VEC4);
    self.light = rll.CreateLight(rll.Light.Type.point, rl.Vector3Zero(), rl.Vector3Zero(), rl.WHITE, self.shader);

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
        .empty = if (tile_models.get(.empty) != null) rl.LoadModel(@ptrCast(tile_models.get(.empty).?)) else null,
        .plane = if (tile_models.get(.plane) != null) rl.LoadModel(@ptrCast(tile_models.get(.plane).?)) else null,
        .mountain = if (tile_models.get(.mountain) != null) rl.LoadModel(@ptrCast(tile_models.get(.mountain).?)) else null,
        .sand = if (tile_models.get(.sand) != null) rl.LoadModel(@ptrCast(tile_models.get(.sand).?)) else null,
        .trees = if (tile_models.get(.trees) != null) rl.LoadModel(@ptrCast(tile_models.get(.trees).?)) else null,
        .ocean = if (tile_models.get(.ocean) != null) rl.LoadModel(@ptrCast(tile_models.get(.ocean).?)) else null,
        .wall = if (tile_models.get(.wall) != null) rl.LoadModel(@ptrCast(tile_models.get(.wall).?)) else null,
        .door = if (tile_models.get(.door) != null) rl.LoadModel(@ptrCast(tile_models.get(.door).?)) else null,
        .size = if (tile_models.get(.size) != null) rl.LoadModel(@ptrCast(tile_models.get(.size).?)) else null,
    });

    for (self.tile_models.values) |model_opt| {
        if (model_opt) |model| {
            try self.models.append(model);
        }
    }

    self.enemy_models = .init(.{
        .slow_chaser = rl.LoadModel("assets/spider.glb"),
        .fast_chaser = rl.LoadModel("assets/spider.glb"),
        .cornering_chaser = rl.LoadModel("assets/spider.glb"),
        .shooter = rl.LoadModel("assets/snake.glb"),
        .predict_shooter = rl.LoadModel("assets/snake.glb"),
        .walking_shooter = rl.LoadModel("assets/snake.glb"),
        .flyer = rl.LoadModel("assets/wasp.glb"),
        .boss = switch (boss_type) {
            .lion => rl.LoadModel("assets/lion.glb"),
            .hydra => rl.LoadModel("assets/hydra_head.glb"),
            .stag => rl.LoadModel("assets/stag.glb"),
        },
    });
    if (boss_type == .hydra) {
        self.hydra_body = rl.LoadModel("assets/hydra_body.glb");
        try self.models.append(self.hydra_body.?);
    }

    for (self.enemy_models.values) |model_opt| {
        if (model_opt) |model| {
            try self.models.append(model);
        }
    }

    self.enemy_animations = .initUndefined();
    try load_animation(&self, .slow_chaser, "assets/spider.glb", 0, 2, 4);
    try load_animation(&self, .fast_chaser, "assets/spider.glb", 0, 2, 4);
    try load_animation(&self, .cornering_chaser, "assets/spider.glb", 0, 2, 4);
    try load_animation(&self, .shooter, "assets/snake.glb", 0, 2, 4);
    try load_animation(&self, .walking_shooter, "assets/snake.glb", 0, 2, 4);
    try load_animation(&self, .predict_shooter, "assets/snake.glb", 0, 2, 4);
    try load_animation(&self, .flyer, "assets/wasp.glb", 0, 2, 2);
    switch (boss_type) {
        .lion => try load_animation(&self, .boss, "assets/lion.glb", 3, 3, 3),
        .hydra => try load_animation(&self, .boss, "assets/hydra_head.glb", 0, 2, 4),
        .stag => try load_animation(&self, .boss, "assets/stag.glb", 4, 4, 4),
    }

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
                try self.enemies.append(.init(
                    &self,
                    vec2(@floatFromInt(ph.position.x), @floatFromInt(ph.position.y)),
                    enemy,
                ));
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
                    npc.name,
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
    if (self.dialog) |*dialog| dialog.deinit();
    rl.UnloadTexture(self.arrows_controls_texture);
    rl.UnloadTexture(self.attack_controls_texture);
}

pub fn update(self: *Self) !void {
    set(self);
    if (rl.IsKeyPressed(rl.KEY_PERIOD)) {
        self.display_debug = !self.display_debug;
    }

    self.curr_room = null;
    for (self.level.room_rects.items) |room_rec| {
        const rlrec = rl.Rectangle{ .x = room_rec.x - 0.5, .y = room_rec.y - 0.5, .width = room_rec.w, .height = room_rec.h };
        if (rl.CheckCollisionPointRec(self.player.position, rlrec)) {
            self.curr_room = rl.Rectangle{ .x = room_rec.x, .y = room_rec.y, .width = room_rec.w, .height = room_rec.h };
        }
    }

    var center = self.camera.target;
    if (self.curr_room) |room| {
        center = rl.Vector3Add(to_world_pos(vec2(room.x + (room.width / 2) - 0.5, room.y + (room.height / 2))), vec3(0, 0, -1));
    } else if (self.player.exiting_direction == null) {
        center = to_world_pos(self.player.position);
    }

    const dist = rl.Vector3Distance(self.camera.target, center);
    self.camera.target = rl.Vector3MoveTowards(self.camera.target, center, rl.logf(dist + 1.1) * 0.1);
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
        self.finished = (self.player.exiting_direction != null or !self.player.alive) and spot.radius == 0;

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

    self.player.update();
    self.player.position = self.solve_collisions(self.player.position, self.player.radius);

    if (self.curr_room) |curr_room| {
        for (self.enemies.items) |*e| {
            try e.update(curr_room);
        }
    }

    for (self.bullets.items) |*e| {
        if (!e.alive) continue;
        e.pos = rl.Vector2Add(e.pos, e.vector);
        if (self.curr_room != null and !rl.CheckCollisionPointRec(e.pos, self.curr_room.?)) {
            e.alive = false;
        } else if (rl.CheckCollisionCircles(self.player.position, self.player.radius, e.pos, 0.2)) {
            self.player.take_hit(e.dmg);
            self.stats.bullets_hit += 1;
            e.alive = false;
        }
    }

    for (self.npcs.items) |*npc| npc.update();

    if (self.dialog) |*dialog| {
        dialog.update();
        if (dialog.finished) {
            dialog.deinit();
            self.dialog = null;
        }
    }
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
            e.render();
        }

        for (self.bullets.items) |e| {
            if (!e.alive) continue;
            const angle = rl.Vector2Angle(vec2(0, 1), rl.Vector2Normalize(e.vector)) * -rl.RAD2DEG;
            rl.DrawModelEx(self.bullet_model, to_world_pos(e.pos), vec3(0, 1, 0), angle, rl.Vector3Scale(rl.Vector3One(), 0.3), rl.WHITE);
        }

        self.player.render();

        for (self.npcs.items) |npc| npc.render();

        rl.DrawSphere(self.light.position, 0.15, rl.YELLOW);
    }

    rl.DrawRectangle(0, 0, c.window_w, 70, rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xaa });

    const life: f32 = c.as_f32(self.player.health) / c.as_f32(Player.max_health);

    rl.DrawRectangle(20, 20, 110, 30, rl.BLACK);
    rl.DrawRectangle(25, 25, 100, 20, rl.GRAY);
    rl.DrawRectangle(25, 25, @as(i32, @intFromFloat(life * 100.0)), 20, rl.RED);
    rl.DrawText("HP", 25, 25, 20, rl.WHITE);
    const y = 15;
    var x: i32 = window_w - 20;
    const txt_mover = "Mover :";
    const txt_atacar = "Atacar :";
    const scale = 0.4;

    x -= @intFromFloat(c.as_f32(self.attack_controls_texture.width) * scale);
    rl.DrawTextureEx(self.attack_controls_texture, vec2(c.as_f32(x), y), 0.0, scale, rl.WHITE);

    x -= rl.MeasureText(txt_atacar, 20);
    x -= 10;
    rl.DrawText(txt_atacar, x, y + 5, 20, rl.WHITE);

    x -= @intFromFloat(c.as_f32(self.arrows_controls_texture.width) * scale);
    x -= 20;
    rl.DrawTextureEx(self.arrows_controls_texture, vec2(c.as_f32(x), y), 0.0, scale, rl.WHITE);

    x -= rl.MeasureText(txt_mover, 20);
    x -= 10;
    rl.DrawText(txt_mover, x, y + 5, 20, rl.WHITE);

    if (self.dialog) |dialog| dialog.render();

    if (self.display_debug) {
        rl.DrawRectangle(20, 50, 150, 100, rl.BLACK);
        rl.DrawText(rl.TextFormat(
            \\ bullets_shot: %i
            \\ bullets_hit: %i
            \\ enemies_activated: %i
            \\ enemies_hit_player: %i
        , self.stats.bullets_shot, self.stats.bullets_hit, self.stats.enemies_activated, self.stats.enemies_hit_player), 22, 52, 10, rl.WHITE);
    }

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

pub fn to_world_pos_y(pos: rl.Vector2, y: f32) rl.Vector3 {
    return vec3(pos.x * 0.90, y, pos.y * 0.90);
}

pub fn to_world_pos(pos: rl.Vector2) rl.Vector3 {
    return vec3(pos.x * 0.90, 0, pos.y * 0.90);
}

pub fn solve_collisions_flyer(self: *Self, circ: rl.Vector2, radius: f32) rl.Vector2 {
    return self.solve_collisions_impl(circ, radius, true);
}

pub fn solve_collisions(self: *Self, circ: rl.Vector2, radius: f32) rl.Vector2 {
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
