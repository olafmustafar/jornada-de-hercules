const std = @import("std");
const rl = @import("raylib.zig");
const World = @import("World.zig");
const c = @import("commons.zig");
const AudioMgr = @import("AudioMgr.zig");

const Self = @This();
pub const max_health = 100;
const right_hand_bone_idx = 29;

alive: bool,
position: rl.Vector2,
radius: f32,
angle: f32,
speed: f32,
is_attacking: bool,
show_sword: bool,
model: rl.Model,
sword: rl.Model,
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
        .sword = rl.LoadModel("assets/sword.glb"),
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
        .show_sword = true,
        .immunity_frames = 0.0,
        .exiting_direction = null,
    };

    try models.append(self.model);
    try models.append(self.sword);
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
        } else {
            World.get().spotlight_open = false;
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

    var movement = rl.Vector2Zero();
    if (world.dialog == null) {
        if (self.exiting_direction) |exiting_direction| {
            movement = rl.Vector2Normalize(exiting_direction);
            self.angle = rl.Vector2Angle(c.vec2(0, 1), movement) * -rl.RAD2DEG;
            self.current_animation = self.sprint_animation;
            world.spotlight_open = false;
        } else if (!self.is_attacking) {
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
            if (rl.IsKeyPressed(rl.KEY_J)) {
                var npc_hit = false;
                for (world.npcs.items) |*e| {
                    if (self.check_hit_collision(e.position, 1)) {
                        e.begin_dialog();
                        self.angle = c.look_target_rad(self.position, e.position) * -rl.RAD2DEG;
                        npc_hit = true;
                        break;
                    }
                }

                if (!npc_hit) {
                    self.is_attacking = true;
                    self.animation_counter = 0;
                }
            }
        }
    }

    if (self.is_attacking) {
        self.current_animation = self.attack_animation;
    } else if ((rl.Vector2Equals(movement, rl.Vector2Zero())) == 0) {
        movement = rl.Vector2Normalize(movement);
        self.position = rl.Vector2Add(self.position, rl.Vector2Scale(movement, delta * self.speed));
        self.angle = rl.Vector2Angle(c.vec2(0, 1), movement) * -rl.RAD2DEG;
        self.current_animation = self.sprint_animation;
    } else {
        self.current_animation = self.idle_animation;
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
    const world = World.get();
    rl.PlaySound(AudioMgr.get().swoosh);
    for (world.enemies.items) |*e| {
        if (e.alive and self.check_hit_collision(e.pos, e.radius)) {
            e.health_points -= 10;
            if (e.enemy.type == .boss and world.boss_type == .stag) {
                e.alive = false;
                world.particles.start(World.to_world_pos(e.pos));
                world.dialog = .init("Hércules", &[_][]const u8{"Corça capturada!"});
            }
            if (e.health_points <= 0) {
                rl.PlaySound(AudioMgr.get().enemy_die);
                world.particles.start(World.to_world_pos(e.pos));
                e.alive = false;
            } else {
                rl.PlaySound(AudioMgr.get().hit);
                const angl = self.look_angle();
                e.inertia = rl.Vector2Scale(c.vec2(rl.cosf(angl), rl.sinf(angl)), 0.8);
            }
        }
    }
}

fn check_hit_collision(self: Self, other: rl.Vector2, other_radius: f32) bool {
    const angl = self.look_angle();
    const hit_radius = 0.5;
    const hit_circle = rl.Vector2Add(self.position, rl.Vector2Scale(c.vec2(rl.cosf(angl), rl.sinf(angl)), 0.5));
    return (rl.CheckCollisionCircles(hit_circle, hit_radius, other, other_radius) or
        rl.CheckCollisionCircles(self.position, hit_radius, other, other_radius));
}

fn look_angle(self: Self) f32 {
    return (self.angle - 90) * -rl.DEG2RAD;
}

pub fn take_hit(self: *Self, dmg: i32) void {
    if (self.alive and self.immunity_frames <= 0) {
        rl.PlaySound(AudioMgr.get().hit);
        self.health = self.health - dmg;
        if (self.health <= 0) {
            self.alive = false;
            self.animation_counter = 0;
            self.current_animation = self.die_animation;
        }
        self.immunity_frames = 2;
    }
}

pub fn render(self: Self) void {
    const player_pos = World.to_world_pos(self.position);
    const player_scale = rl.Vector3Scale(rl.Vector3One(), 0.5);
    rl.DrawModelEx(
        self.model,
        player_pos,
        c.vec3(0, 1, 0),
        self.angle,
        player_scale,
        if (@mod(self.immunity_frames, 0.5) > 0.25 or self.immunity_frames <= 0) rl.WHITE else rl.RED,
    );

    if (self.show_sword) {
        //draw the sword on player hand
        const bone_trans = self.current_animation.framePoses[@intCast(self.animation_counter)][right_hand_bone_idx];
        const in_rotation = self.model.bindPose[right_hand_bone_idx].rotation;
        const rotate = rl.QuaternionMultiply(bone_trans.rotation, rl.QuaternionInvert(in_rotation));
        var mat_trans = rl.MatrixIdentity();
        mat_trans = rl.MatrixMultiply(mat_trans, rl.MatrixScale(0.15, 0.15, 0.15));
        mat_trans = rl.MatrixMultiply(mat_trans, rl.MatrixRotateXYZ(c.vec3(90, 0, 0)));
        mat_trans = rl.MatrixMultiply(mat_trans, rl.QuaternionToMatrix(rotate));
        mat_trans = rl.MatrixMultiply(mat_trans, rl.MatrixTranslate(bone_trans.translation.x, bone_trans.translation.y, bone_trans.translation.z));
        mat_trans = rl.MatrixMultiply(mat_trans, self.model.transform);
        mat_trans = rl.MatrixMultiply(mat_trans, rl.MatrixRotateY(self.angle * rl.DEG2RAD));
        mat_trans = rl.MatrixMultiply(mat_trans, rl.MatrixScale(player_scale.x, player_scale.y, player_scale.z));
        mat_trans = rl.MatrixMultiply(mat_trans, rl.MatrixTranslate(player_pos.x, player_pos.y, player_pos.z));
        rl.DrawMesh(self.sword.meshes[0], self.sword.materials[1], mat_trans);
    }
}
