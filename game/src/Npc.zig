const std = @import("std");
const rl = @import("raylib.zig");
const World = @import("World.zig");
const Dialog = @import("Dialog.zig");
const c = @import("commons.zig");

const Self = @This();
model: rl.Model,
position: rl.Vector2,
animation: rl.ModelAnimation,
animation_counter: i32,
angle: f32,
name: []const u8,
dialog: []const []const u8,

pub fn init(pos: rl.Vector2, name: []const u8, dialog: []const []const u8, models: *std.ArrayList(rl.Model), models_animations: *std.ArrayList(World.Animations)) !Self {
    var animation_count: usize = 0;
    const animations = rl.LoadModelAnimations("assets/euristeu.glb", @ptrCast(&animation_count));
    const self = Self{
        .model = rl.LoadModel("assets/euristeu.glb"),
        .animation = animations[9],
        .animation_counter = 0,
        .name = name,
        .dialog = dialog,
        .position = pos,
        .angle = 0,
    };
    try models.append(self.model);
    try models_animations.append(.{ .vec = animations, .size = @intCast(animation_count) });
    return self;
}

pub fn update(self: *Self) void {
    if (World.get().dialog == null) {
        self.angle = 0;
    }
    self.animation_counter = @mod(self.animation_counter + 1, self.animation.frameCount);
    rl.UpdateModelAnimation(self.model, self.animation, self.animation_counter);
}

pub fn render(self: Self) void {
    rl.DrawModelEx(self.model, World.to_world_pos(self.position), c.vec3up(), self.angle * -rl.RAD2DEG, c.vec3xyz(0.5), rl.WHITE);
}

pub fn begin_dialog(self: *Self) void {
    var world = World.get();
    if (world.dialog == null) {
        world.dialog = .init(self.name, self.dialog);
        self.angle = c.look_target_rad(self.position, world.player.position);
    }
}
