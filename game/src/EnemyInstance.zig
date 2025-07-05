const std = @import("std");
const rl = @import("raylib.zig");
const Enemy = @import("pcgmanager").Contents.Enemy;
const World = @import("World.zig");
const c = @import("commons.zig");

const Self = @This();

alive: bool,
model: rl.Model,
animation: ?rl.ModelAnimation,
angle: f32,
enemy: Enemy,
active: bool,
pos: rl.Vector2,
health_points: f32,
radius: f32,
animation_frame: i32,
inertia: rl.Vector2,
shooting_cooldown: f32,
move_target: ?rl.Vector2,
move_target_timer: f32,

activated: bool,
player_hit: bool,

pub fn init(world: *World, pos: rl.Vector2, enemy: Enemy) Self {
    var self = Self{
        .alive = true,
        .model = world.enemy_models.get(enemy.type).?,
        .animation = null,
        .angle = 0.0,
        .enemy = enemy,
        .active = true,
        .health_points = 100 * enemy.health,
        .pos = pos,
        .radius = 0.3,
        .animation_frame = 0,
        .inertia = rl.Vector2Zero(),
        .shooting_cooldown = 0,
        .move_target = null,
        .move_target_timer = 0.00,
        .activated = false,
        .player_hit = false,
    };

    if (world.enemy_animations.get(enemy.type)) |anim| {
        self.animation = anim.run;
    }
    if (enemy.type == .boss) {
        switch (world.boss_type) {
            .lion => {},
            .hydra => {
                self.radius = 0.5;
                self.enemy.velocity *= 0.5;
                self.enemy.health = 40;
                self.health_points = 40;
            },
            .stag => {
                self.enemy.velocity *= 1.5;
            },
        }
    }

    return self;
}

pub fn update(self: *Self, curr_room: rl.Rectangle) !void {
    var world = World.get();
    const delta = rl.GetFrameTime();

    if (!self.alive or !rl.CheckCollisionPointRec(self.pos, curr_room))
        return;

    if (!self.activated) {
        world.stats.enemies_activated += 1;
        self.activated = true;
    }

    const bullet_vel = 4.5 * delta;
    if (self.enemy.type == .shooter or self.enemy.type == .walking_shooter or self.enemy.type == .predict_shooter) {
        if (self.shooting_cooldown <= 0) {
            self.shooting_cooldown = 2.3 - (self.enemy.shooting_velocity * 2);
            world.stats.bullets_shot += 1;

            const target = if (self.enemy.type == .predict_shooter)
                rl.Vector2Add(world.player.position, rl.Vector2Rotate(c.vec2(0, 1), world.player.angle * -rl.DEG2RAD))
            else
                world.player.position;

            try world.bullets.append(.{
                .alive = true,
                .dmg = @intFromFloat(self.enemy.damage * 50),
                .pos = self.pos,
                .vector = rl.Vector2Scale(rl.Vector2Normalize(rl.Vector2Subtract(target, self.pos)), bullet_vel),
                .collide_with_walls = false,
            });
        } else {
            self.shooting_cooldown -= delta;
        }
    } else if (self.enemy.type == .boss and world.boss_type == .hydra) {
        if (self.shooting_cooldown <= 0) {
            self.shooting_cooldown = 2.3 - (self.enemy.shooting_velocity * 2);

            world.stats.bullets_shot += 1;
            const target_rad = c.look_target_rad(self.pos, world.player.position);

            try world.bullets.append(.{
                .alive = true,
                .dmg = @intFromFloat(self.enemy.damage * 50),
                .pos = self.pos,
                .vector = rl.Vector2Scale(rl.Vector2Rotate(c.vec2(0, 1), target_rad - (30 * rl.DEG2RAD)), bullet_vel),
                .collide_with_walls = true,
            });
            try world.bullets.append(.{
                .alive = true,
                .dmg = @intFromFloat(self.enemy.damage * 50),
                .pos = self.pos,
                .vector = rl.Vector2Scale(rl.Vector2Rotate(c.vec2(0, 1), target_rad), bullet_vel),
                .collide_with_walls = true,
            });
            try world.bullets.append(.{
                .alive = true,
                .dmg = @intFromFloat(self.enemy.damage * 50),
                .pos = self.pos,
                .vector = rl.Vector2Scale(rl.Vector2Rotate(c.vec2(0, 1), target_rad + (30 * rl.DEG2RAD)), bullet_vel),
                .collide_with_walls = true,
            });
        } else {
            self.shooting_cooldown -= delta;
        }
    }

    const step = 5 * self.enemy.velocity * delta;
    if (rl.Vector2Equals(self.inertia, rl.Vector2Zero()) == 0) {
        self.pos = rl.Vector2Add(self.pos, self.inertia);
        self.pos = world.solve_collisions(self.pos, self.radius);
        self.inertia = rl.Vector2Scale(self.inertia, 0.5);
    } else if (rl.CheckCollisionCircles(world.player.position, world.player.radius, self.pos, self.radius)) {
        if (!self.player_hit) {
            self.player_hit = true;
            world.stats.enemies_hit_player += 1;
        }
        world.player.take_hit(@intFromFloat(self.enemy.damage * 50));
    } else if (self.enemy.type == .flyer) {
        const previous = self.pos;
        if (self.move_target_timer > 0) {
            self.move_target_timer -= delta;
        } else {
            const angle = @as(f32, @floatFromInt(rl.GetRandomValue(0, 360))) * rl.DEG2RAD;
            self.move_target = rl.Vector2Add(rl.Vector2Rotate(c.vec2(0, 1), angle), self.pos);
            self.move_target = rl.Vector2MoveTowards(self.move_target.?, world.player.position, 0.8);
            self.move_target = rl.Vector2Subtract(self.move_target.?, self.pos);
            self.move_target_timer = 0.10;
        }
        self.pos = rl.Vector2MoveTowards(self.pos, rl.Vector2Add(self.pos, self.move_target.?), step);
        self.pos = world.solve_collisions_flyer(self.pos, self.radius);
        self.angle = rl.Vector2Angle(c.vec2(0, 1), rl.Vector2Normalize(rl.Vector2Subtract(self.pos, previous))) * -rl.RAD2DEG;
    } else if (self.enemy.type == .boss and world.boss_type == .hydra) {
        const previous = self.pos;
        const room = world.curr_room.?;
        self.pos = rl.Vector2MoveTowards(self.pos, c.vec2(room.x + (room.width / 2) - 0.5, room.y + (room.height / 2)), step);
        self.pos = world.solve_collisions(self.pos, self.radius);
        self.angle = rl.Vector2Angle(c.vec2(0, 1), rl.Vector2Normalize(rl.Vector2Subtract(self.pos, previous))) * -rl.RAD2DEG;
    } else if (self.enemy.type == .boss and world.boss_type == .stag) {
        const running_triggers: [4]struct { area: rl.Rectangle, to: rl.Vector2 } = .{
            .{ .area = .{ .x = 0, .y = 0, .width = 6, .height = 4 }, .to = c.vec2(9, 1) },
            .{ .area = .{ .x = 6, .y = 0, .width = 6, .height = 4 }, .to = c.vec2(9, 6) },
            .{ .area = .{ .x = 6, .y = 4, .width = 6, .height = 4 }, .to = c.vec2(2, 6) },
            .{ .area = .{ .x = 0, .y = 4, .width = 6, .height = 4 }, .to = c.vec2(2, 1) },
        };
        const central = rl.Rectangle{ .x = 5 + world.curr_room.?.x, .y = 3 + world.curr_room.?.y, .width = 2, .height = 2 };
        const previous = self.pos;
        if (!rl.CheckCollisionPointRec(world.player.position, central)) {
            for (running_triggers) |trigger| {
                if (rl.CheckCollisionPointRec(world.player.position, rl.Rectangle{
                    .x = trigger.area.x + world.curr_room.?.x,
                    .y = trigger.area.y + world.curr_room.?.y,
                    .width = trigger.area.width,
                    .height = trigger.area.height,
                })) {
                    self.move_target = (c.vec2(
                        trigger.to.x + world.curr_room.?.x + 0.5,
                        trigger.to.y + world.curr_room.?.y + 0.5,
                    ));
                }
            }
        }
        if (self.move_target) |target| self.pos = rl.Vector2MoveTowards(self.pos, target, step);
        self.angle = rl.Vector2Angle(c.vec2(0, 1), rl.Vector2Normalize(rl.Vector2Subtract(self.pos, previous))) * -rl.RAD2DEG;
    } else {
        const previous = self.pos;
        if (self.enemy.type == .cornering_chaser) {
            var i: i32 = 0;
            var new = rl.Vector2MoveTowards(previous, world.player.position, step);
            new = world.solve_collisions(new, self.radius);
            while (i <= 10 and rl.FloatEquals(rl.Vector2Distance(previous, new), step) == 0) {
                i += 1;
                const new_target = rl.Vector2Add(previous, rl.Vector2Scale(rl.Vector2Normalize(rl.Vector2Subtract(new, previous)), 1.2));
                new = rl.Vector2MoveTowards(previous, new_target, step);
                new = world.solve_collisions(new, self.radius);
            }
            self.pos = new;
        } else {
            self.pos = rl.Vector2MoveTowards(self.pos, world.player.position, step);
            self.pos = world.solve_collisions(self.pos, self.radius);
        }
        if (self.enemy.type == .shooter or self.enemy.type == .predict_shooter) {
            self.angle = c.look_target_rad(self.pos, world.player.position) * -rl.RAD2DEG;
        } else {
            self.angle = rl.Vector2Angle(c.vec2(0, 1), rl.Vector2Normalize(rl.Vector2Subtract(self.pos, previous))) * -rl.RAD2DEG;
        }
    }

    if (self.animation) |animation| {
        self.animation_frame += 1;
        rl.UpdateModelAnimation(self.model, animation, self.animation_frame);
        if (self.animation_frame >= animation.frameCount) self.animation_frame = 0;
    }
}

pub fn render(self: Self) void {
    if (!self.alive) return;
    const world = World.get();

    const tint = switch (self.enemy.type) {
        .cornering_chaser => rl.RED,
        .predict_shooter => rl.RED,
        .fast_chaser => rl.GREEN,
        else => rl.WHITE,
    };

    if (self.enemy.type == .boss and world.boss_type == .hydra) {
        rl.DrawModelEx(world.hydra_body.?, World.to_world_pos(self.pos), c.vec3(0, 1, 0), self.angle, rl.Vector3Scale(rl.Vector3One(), 0.2), tint);
        rl.DrawModelEx(self.model, World.to_world_pos(rl.Vector2Add((self.pos), c.vec2(-0.3, 0))), c.vec3(0, 1, 0), self.angle - 30, rl.Vector3Scale(rl.Vector3One(), 0.2), tint);
        rl.DrawModelEx(self.model, World.to_world_pos(self.pos), c.vec3(0, 1, 0), self.angle, rl.Vector3Scale(rl.Vector3One(), 0.2), tint);
        rl.DrawModelEx(self.model, World.to_world_pos(rl.Vector2Add((self.pos), c.vec2(0.3, 0))), c.vec3(0, 1, 0), self.angle + 30, rl.Vector3Scale(rl.Vector3One(), 0.2), tint);
    } else {
        rl.DrawModelEx(self.model, World.to_world_pos(self.pos), c.vec3(0, 1, 0), self.angle, rl.Vector3Scale(rl.Vector3One(), 0.2), tint);
    }
}
