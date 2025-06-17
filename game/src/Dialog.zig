const std = @import("std");
const rl = @import("raylib.zig");
const c = @import("commons.zig");

const Self = @This();
const txt_speed = 25;
const font_size = 20;

finished: bool,
show: bool,
offset: f32,
name: []const u8,
dialog: []const []const u8,
idx: usize,
box_text_header: [0x100]u8,
box_text: [0x100]u8,
box_progress: f32,
dialog_box: rl.Texture2D,

pub fn init(name: []const u8, dialogs: []const []const u8) Self {
    const dialog_box_img = rl.LoadImage("assets/dialog_box.png");
    defer rl.UnloadImage(dialog_box_img);
    const dialog_box = rl.LoadTextureFromImage(dialog_box_img);

    var self = Self{
        .name = name,
        .dialog = dialogs,
        .idx = 0,
        .box_progress = 0,
        .box_text_header = undefined,
        .box_text = undefined,
        .show = true,
        .finished = false,
        .offset = 0.0,
        .dialog_box = dialog_box,
    };

    std.mem.copyForwards(u8, &self.box_text_header, self.name);
    self.box_text_header[self.name.len] = ':';
    self.box_text_header[self.name.len + 1] = 0;

    return self;
}

pub fn deinit(self: Self) void {
    rl.UnloadTexture(self.dialog_box);
}

pub fn update(self: *Self) void {
    const delta = rl.GetFrameTime();

    if (self.show) {
        self.offset = @min(self.offset + delta, 1);
    } else {
        self.offset = @max(self.offset - delta, 0);
        if (self.offset == 0) {
            self.finished = true;
        }
    }

    self.box_progress = @min(self.box_progress + (txt_speed * delta), @as(f32, @floatFromInt(self.dialog[self.idx].len)));

    if (rl.IsKeyPressed(rl.KEY_J)) {
        if (self.box_progress < @as(f32, @floatFromInt(self.dialog[self.idx].len))) {
            self.box_progress = @as(f32, @floatFromInt(self.dialog[self.idx].len));
        } else if (self.idx < self.dialog.len - 1) {
            self.box_progress = 0;
            self.idx += 1;
        } else {
            self.show = false;
        }
    }

    std.mem.copyForwards(u8, &self.box_text, self.dialog[self.idx][0..@intFromFloat(self.box_progress)]);
    self.box_text[@intFromFloat(self.box_progress)] = 0;
}

pub fn render(self: Self) void {
    const width = self.dialog_box.width;
    const height = self.dialog_box.height;
    const eased_offset = height - @as(i32, @intFromFloat(c.ease_out_elastic(self.offset) * @as(f32, @floatFromInt(height))));

    rl.DrawTexture(
        self.dialog_box,
        @divFloor(c.window_w - width, 2),
        (c.window_h - height) + eased_offset,
        rl.WHITE,
    );

    rl.DrawText(
        @ptrCast(&self.box_text_header),
        @divFloor(c.window_w - width, 2) + 40,
        (c.window_h - height) + eased_offset + 40,
        font_size,
        rl.BLACK,
    );
    rl.DrawText(
        @ptrCast(&self.box_text),
        @divFloor(c.window_w - width, 2) + 40,
        (c.window_h - height) + eased_offset + 40 + 30,
        font_size,
        rl.BLACK,
    );
}
