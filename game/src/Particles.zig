const std = @import("std");
const rl = @import("raylib.zig");
const c = @import("commons.zig");

const Self = @This();

model: rl.Model,
individuals: [5]rl.Vector3,
progress: f32,

pub fn init(model: rl.Model) Self {
    return .{
        .model = model,
        .individuals = [_]rl.Vector3{rl.Vector3Zero()} ** 5,
        .progress = 0,
    };
}

pub fn start(self: *Self, pos: rl.Vector3) void {
    for (&self.individuals) |*ind| {
        ind.* = rl.Vector3Add(pos, c.vec3(
            (c.as_f32(rl.GetRandomValue(0, 3)) * 0.1) - 0.3,
            (c.as_f32(rl.GetRandomValue(0, 3)) * 0.1) - 0.3,
            (c.as_f32(rl.GetRandomValue(0, 3)) * 0.1) - 0.3,
        ));
    }
    self.progress = 0;
}

pub fn update(self: *Self) void {
    const delta = rl.GetFrameTime();
    self.progress = @min(self.progress + 4 * delta, 1);
}

pub fn render(self: Self) void {
    for (self.individuals) |ind| {
        rl.DrawModel(
            self.model,
            rl.Vector3Add(ind, c.vec3(0, self.progress, 0)),
            self.progress,
            rl.ColorAlpha(
                rl.LIGHTGRAY,
                1 - self.progress,
            ),
        );
    }
}
