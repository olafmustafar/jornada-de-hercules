const std = @import("std");
const rl = @import("raylib.zig");
const World = @import("World.zig");

const Self = @This();
model: rl.Model,
position: rl.Vector2,
animation: rl.ModelAnimation,
animation_counter: i32,
dialog: []const u8,

pub fn init(pos: rl.Vector2, dialog: []const u8, models: *std.ArrayList(rl.Model), models_animations: *std.ArrayList(World.Animations)) !Self {
    var animation_count: usize = 0;
    const animations = rl.LoadModelAnimations("assets/euristeu.glb", @ptrCast(&animation_count));
    const self = Self{
        .model = rl.LoadModel("assets/euristeu.glb"),
        .animation = animations[9],
        .animation_counter = 0,
        .dialog = dialog,
        .position = pos,
    };
    try models.append(self.model);
    try models_animations.append(.{ .vec = animations, .size = @intCast(animation_count) });
    return self;
}

pub fn update(self: *Self) void {
    self.animation_counter = @mod(self.animation_counter + 1, self.animation.frameCount);
    rl.UpdateModelAnimation(self.model, self.animation, self.animation_counter);
}

pub fn render(self: Self) void {
    rl.DrawModel(self.model, World.to_world_pos(self.position), 0.5, rl.WHITE);
}

pub fn talk() void {}
