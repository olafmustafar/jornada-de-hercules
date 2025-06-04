const std = @import("std");
const Generator = @import("Generator.zig").Generator;
const Context = @import("../Context.zig");
const Enemy = @import("../contents.zig").Enemy;
const Enemies = @import("../contents.zig").Enemies;

const InstructionTag = enum { generate };

pub const Instruction = union(InstructionTag) {
    generate: struct { classes_count: usize },
};

fn generate(ctx: *Context, instruction: Instruction) Enemies {
    switch (instruction) {
        .generate => |arg| {
            return get_random_enemies(std.Random, arg.classes_count);
        },
    }
}

fn get_random_enemies(ctx: *Context, classes: usize) !Enemies {
    var enemies: Enemies = .init(ctx.gpa);

    for (0..classes) |i| {
        const frac: f32 = (i + 1) / classes;
        const multiplier = ease_in_out_quad(frac);

        const fast_chaser = Enemy{
            .type = .slow_chaser,
            .damage = multiplier * 0.2,
            .health = multiplier * 0.4,
            .velocity = multiplier,
            .shooting_velocity = 0,
        };

        const slow_chaser = Enemy{
            .type = .fast_chaser,
            .damage = multiplier,
            .health = multiplier,
            .velocity = multiplier * 0.4,
            .shooting_velocity = 0,
        };

        const shooter = Enemy{
            .type = .shooter,
            .damage = multiplier * 0.8,
            .health = multiplier * 0.2,
            .velocity = 0,
            .shooting_velocity = multiplier * 0.5,
        };

        const walking_shooter = Enemy{
            .type = .walking_shooter,
            .damage = multiplier * 0.8,
            .health = multiplier * 0.4,
            .velocity = multiplier * 0.2,
            .shooting_velocity = multiplier * 0.2,
        };

        const flyer = Enemy{
            .type = .flyer,
            .damage = multiplier * 0.3,
            .health = multiplier * 0.2,
            .velocity = multiplier,
            .shooting_velocity = 0,
        };

        try enemies.append(fast_chaser);
        try enemies.append(slow_chaser);
        try enemies.append(shooter);
        try enemies.append(walking_shooter);
        try enemies.append(flyer);
    }

    return enemies;
}

pub const EnemiesGenerator = Generator(Instruction, Enemies, generate);

fn ease_in_out_quad(x: f32) f32 {
    return if (x < 0.5) 2 * x * x else 1 - (std.math.pow(-2 * x + 2, 2) / 2);
}
