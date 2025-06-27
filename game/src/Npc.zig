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

dialog_icon: rl.Texture2D,
dialog_icon_mesh: rl.Mesh,
dialog_icon_material: rl.Material,
dialog_icon_y: f32,

pub fn init(pos: rl.Vector2, name: []const u8, dialog: []const []const u8, models: *std.ArrayList(rl.Model), models_animations: *std.ArrayList(World.Animations)) !Self {
    var animation_count: usize = 0;
    const animations = rl.LoadModelAnimations("assets/euristeu.glb", @ptrCast(&animation_count));

    const dialog_icon_png = rl.LoadImage("assets/attack_controls.png");
    defer rl.UnloadImage(dialog_icon_png);

    var self = Self{
        .model = rl.LoadModel("assets/euristeu.glb"),
        .animation = animations[9],
        .animation_counter = 0,
        .name = name,
        .dialog = dialog,
        .position = pos,
        .angle = 0,
        .dialog_icon = rl.LoadTextureFromImage(dialog_icon_png),
        .dialog_icon_mesh = rl.GenMeshPlane(@floatFromInt(1), @floatFromInt(1), 1, 1),
        .dialog_icon_material = rl.LoadMaterialDefault(),
        .dialog_icon_y = 1,
    };
    try models.append(self.model);
    try models_animations.append(.{ .vec = animations, .size = @intCast(animation_count) });
    self.dialog_icon_material.maps[rl.MATERIAL_MAP_DIFFUSE].texture = self.dialog_icon;

    return self;
}

pub fn deinit(self: Self) void {
    rl.UnloadTexture(self.dialog_icon);
    rl.UnloadMaterial(self.dialog_icon_material);
    rl.UnloadMesh(self.dialog_icon_mesh);
}

pub fn update(self: *Self) void {
    if (World.get().dialog == null) {
        self.angle = 0;
    }
    self.dialog_icon_y = @mod(self.dialog_icon_y + (4 * rl.GetFrameTime()), rl.PI * 2);
    self.animation_counter = @mod(self.animation_counter + 1, self.animation.frameCount);
    rl.UpdateModelAnimation(self.model, self.animation, self.animation_counter);
}

pub fn render(self: Self) void {
    const world = World.get();
    rl.DrawModelEx(self.model, World.to_world_pos(self.position), c.vec3up(), self.angle * -rl.RAD2DEG, c.vec3xyz(0.5), rl.WHITE);

    if (world.dialog == null) {
        var pos = World.to_world_pos(self.position);
        pos.y = 1.5;
        pos.z -= 0.5 + rl.sinf(self.dialog_icon_y) * 0.02;
        var matrix = rl.MatrixRotateX(90 * rl.DEG2RAD);
        matrix = rl.MatrixMultiply(matrix, rl.MatrixScale(0.5, 0.5, 0.5));
        var aux = pos;
        aux.x = world.camera.position.x;
        matrix = rl.MatrixMultiply(matrix, c.matrix_look_at(aux, world.camera.position, c.vec3(0, 1, 0)));
        matrix = rl.MatrixMultiply(matrix, rl.MatrixTranslate(pos.x, pos.y, pos.z));
        rl.DrawMesh(self.dialog_icon_mesh, self.dialog_icon_material, matrix);
    }
}

pub fn begin_dialog(self: *Self) void {
    var world = World.get();
    if (world.dialog == null) {
        world.dialog = .init(self.name, self.dialog);
        self.angle = c.look_target_rad(self.position, world.player.position);
    }
}
