const std = @import("std");
const rl = @import("raylib.zig");
const World = @import("World.zig");
const c = @import("commons.zig");

const Self = @This();
pub const max_health = 100;

alive: bool,
position: rl.Vector2,
radius: f32,
angle: f32,
speed: f32,
is_attacking: bool,
model: rl.Model,
current_animation: rl.ModelAnimation,
sprint_animation: rl.ModelAnimation,
idle_animation: rl.ModelAnimation,
attack_animation: rl.ModelAnimation,
die_animation: rl.ModelAnimation,
animation_counter: i32,
health: i32,
immunity_frames: f32,
exiting_direction: ?rl.Vector2,

pub fn init(models: *std.ArrayList(rl.Model), model_animations: *std.ArrayList(World.Animations)) !Self {
    var animation_count: usize = 0;
    const player_animations = rl.LoadModelAnimations("assets/player.glb", @ptrCast(&animation_count));
    const self = Self{
        .alive = true,
        .model = rl.LoadModel("assets/player.glb"),
        .sprint_animation = player_animations[38],
        .idle_animation = player_animations[9],
        .attack_animation = player_animations[41],
        .current_animation = player_animations[9],
        .die_animation = player_animations[4],
        .animation_counter = 0,
        .position = c.vec2(0, 0),
        .radius = 0.2,
        .angle = 0.00,
        .speed = 3.00,
        .health = max_health,
        .is_attacking = false,
        .immunity_frames = 0.0,
        .exiting_direction = null,
    };

    try models.append(self.model);
    try model_animations.append(.{ .vec = player_animations, .size = @intCast(animation_count) });

    return self;
}

pub fn update(self: *Self) void {
    const delta = rl.GetFrameTime();
    const world = World.get();

    if (!self.alive) {
        if (self.animation_counter < self.current_animation.frameCount - 1) {
            self.animation_counter += 1;
            rl.UpdateModelAnimation(self.model, self.current_animation, self.animation_counter);
        }
        return;
    }
    if (self.immunity_frames > 0) self.immunity_frames -= delta;

    for (world.exits.items) |exit| {
        const rec = rl.Rectangle{ .x = exit.pos.x - 0.5, .y = exit.pos.y - 0.5, .width = 1, .height = 1 };
        if (rl.CheckCollisionCircleRec(self.position, self.radius, rec)) {
            self.exiting_direction = c.dir_to_vec2(exit.dir);
        }
    }

    if (self.exiting_direction) |exiting_direction| {
        const movement = rl.Vector2Normalize(exiting_direction);
        self.position = rl.Vector2Add(self.position, rl.Vector2Scale(movement, delta * self.speed));
        self.angle = rl.Vector2Angle(c.vec2(0, 1), movement) * -rl.RAD2DEG;
        self.current_animation = self.sprint_animation;
        world.spotlight_open = false;
    } else if (!self.is_attacking) {
        var movement = rl.Vector2Zero();
        if (rl.IsKeyDown(rl.KEY_D) or rl.IsKeyDown(rl.KEY_RIGHT)) {
            movement = rl.Vector2Add(movement, c.vec2(1, 0));
        }
        if (rl.IsKeyDown(rl.KEY_A) or rl.IsKeyDown(rl.KEY_LEFT)) {
            movement = rl.Vector2Add(movement, c.vec2(-1, 0));
        }
        if (rl.IsKeyDown(rl.KEY_W) or rl.IsKeyDown(rl.KEY_UP)) {
            movement = rl.Vector2Add(movement, c.vec2(0, -1));
        }
        if (rl.IsKeyDown(rl.KEY_S) or rl.IsKeyDown(rl.KEY_DOWN)) {
            movement = rl.Vector2Add(movement, c.vec2(0, 1));
        }
        if ((rl.Vector2Equals(movement, rl.Vector2Zero())) == 0) {
            movement = rl.Vector2Normalize(movement);
            self.position = rl.Vector2Add(self.position, rl.Vector2Scale(movement, delta * self.speed));
            self.angle = rl.Vector2Angle(c.vec2(0, 1), movement) * -rl.RAD2DEG;
            self.current_animation = self.sprint_animation;
        } else {
            self.current_animation = self.idle_animation;
        }

        if (rl.IsKeyPressed(rl.KEY_J)) {
            self.is_attacking = true;
            self.animation_counter = 0;
            self.current_animation = self.attack_animation;
        }
    }

    if (self.is_attacking) {
        self.animation_counter += 2;
        if (self.animation_counter == 12) {
            self.attack();
        }
        rl.UpdateModelAnimation(self.model, self.current_animation, self.animation_counter);
        if (self.animation_counter >= self.current_animation.frameCount) {
            self.is_attacking = false;
            self.animation_counter = 0;
        }
    } else {
        self.animation_counter += 1;
        rl.UpdateModelAnimation(self.model, self.current_animation, self.animation_counter);
        if (self.animation_counter >= self.current_animation.frameCount) {
            self.animation_counter = 0;
        }
    }
}

fn attack(self: *Self) void {
    const angl = (self.angle - 90) * -rl.DEG2RAD;
    const hit_radius = 0.3;
    const hit_circle = rl.Vector2Add(self.position, rl.Vector2Scale(c.vec2(rl.cosf(angl), rl.sinf(angl)), 0.5));

    const world = World.get();
    for (world.enemies.items) |*e| {
        if (rl.CheckCollisionCircles(hit_circle, hit_radius, e.pos, e.radius) or
            rl.CheckCollisionCircles(self.position, hit_radius, e.pos, e.radius))
        {
            e.health_points -= 10;
            if (e.health_points <= 0) {
                e.alive = false;
            } else {
                e.inertia = rl.Vector2Scale(c.vec2(rl.cosf(angl), rl.sinf(angl)), 0.8);
            }
        }
    }
}

pub fn take_hit(self: *Self, dmg: i32) void {
    if (self.alive and self.immunity_frames <= 0) {
        self.health = self.health - dmg;
        if (self.health <= 0) {
            self.alive = false;
            self.animation_counter = 0;
            self.current_animation = self.die_animation;
        }
        self.immunity_frames = 2;
    }
}
