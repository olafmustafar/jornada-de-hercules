const std = @import("std");
const Generator = @import("Generator.zig").Generator;
const Context = @import("../Context.zig");
const Enemy = @import("../contents.zig").Enemy;
const EnemiesPerDifficulty = @import("../contents.zig").EnemiesPerDifficulty;

const InstructionTag = enum { generate };

pub const Instruction = union(InstructionTag) {
    generate: struct { dummy: i32 = 0 },
};

fn generate(ctx: *Context, instruction: Instruction) EnemiesPerDifficulty {
    switch (instruction) {
        .generate => |_| {
            return get_random_enemies(ctx, ctx.difficulty_classes) catch {
                unreachable;
            };
        },
    }
}

fn get_random_enemies(ctx: *Context, classes: usize) !EnemiesPerDifficulty {
    var enemies: EnemiesPerDifficulty = .init(ctx.gpa);

    for (0..classes) |i| {
        try enemies.append(.initUndefined());

        const frac: f32 = (@as(f32, @floatFromInt(i)) + 1) / @as(f32, @floatFromInt(classes));
        const multiplier = ease_in_out_quad(frac);

        const fast_chaser = Enemy{
            .type = .fast_chaser,
            .damage = multiplier * 0.5,
            .health = multiplier * 0.4,
            .velocity = multiplier,
            .shooting_velocity = 0,
        };

        const cornering_chaser = Enemy{
            .type = .cornering_chaser,
            .damage = multiplier * 0.5,
            .health = multiplier * 0.4,
            .velocity = multiplier * 0.9,
            .shooting_velocity = 0,
        };

        const slow_chaser = Enemy{
            .type = .slow_chaser,
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

        const predict_shooter = Enemy{
            .type = .predict_shooter,
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

        const boss = Enemy{
            .type = .boss,
            .damage = multiplier * 0.8,
            .health = multiplier * 1.8,
            .velocity = multiplier * 0.8,
            .shooting_velocity = 0,
        };

        const last = &enemies.items[enemies.items.len - 1];
        last.set(.fast_chaser, fast_chaser);
        last.set(.slow_chaser, slow_chaser);
        last.set(.cornering_chaser, cornering_chaser);
        last.set(.shooter, shooter);
        last.set(.predict_shooter, predict_shooter);
        last.set(.walking_shooter, walking_shooter);
        last.set(.flyer, flyer);
        last.set(.boss, boss);
    }

    return enemies;
}

fn ease_in_out_quad(x: f32) f32 {
    return if (x < 0.5) 2 * x * x else 1 - (std.math.pow(f32, -2 * x + 2, 2) / 2);
}

pub const EnemiesGenerator = Generator(Instruction, EnemiesPerDifficulty, generate);
