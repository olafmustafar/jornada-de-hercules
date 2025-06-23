const std = @import("std");
const c = @import("commons.zig");
const rl = @import("raylib.zig");

const Self = @This();

const intro_text =
    \\Dizem que Hércules foi o mais forte dos homens.
    \\Dizem que era filho de Zeus, senhor dos céus.
    \\Mas o que raramente se diz… é o preço que ele pagou 
    \\ por carregar esse sangue divino.
    \\
    \\Desde o nascimento, Hera, esposa de Zeus, o odiava.
    \\Não por algo que ele tivesse feito, mas por aquilo 
    \\ que representava: a traição de seu pai.
    \\E foi por essa raiva dos deuses que o destino de 
    \\ Hércules se partiu.
    \\
    \\Um dia, tomado por uma loucura enviada por Hera, 
    \\ ele perdeu o controle.
    \\Não foi uma batalha. Não foi um inimigo.
    \\Foi dentro de sua própria casa que ele cometeu o 
    \\ mais terrível dos crimes.
    \\Matou sua esposa. Seus filhos. Com suas próprias
    \\ mãos.
    \\
    \\
    \\Quando a razão voltou, o mundo já estava destruído 
    \\ ao seu redor.
    \\E o peso daquela tragédia o esmagava mais do que 
    \\ qualquer montanha.
    \\
    \\Buscando perdão — ou pelo menos, alívio —, Hércules 
    \\ foi até o oráculo de Delfos.
    \\E ali recebeu sua sentença:
    \\Deveria servir a Euristeu, rei de Micenas.
    \\Não como guerreiro, mas como servo. E cumprir doze 
    \\ trabalhos impossíveis ...
;
const State = enum { menu, intro_text };

start: bool = false,
state: State,

image: rl.Image,
texture: rl.Texture,
title_rotation: f32,

start_btn: rl.Rectangle,

sound_enabled: bool,
sound_btn: rl.Rectangle,
intro_text_offset: f32,
intro_text_linecount: i32,

pub fn init() Self {
    var self: Self = undefined;
    self.image = rl.LoadImage("assets/title.png");
    self.texture = rl.LoadTextureFromImage(self.image);
    self.title_rotation = 0;
    self.start_btn = rl.Rectangle{ .width = 200, .height = 50, .x = (c.window_w - 200) / 2, .y = c.window_h - 160 };
    self.sound_btn = rl.Rectangle{ .width = 200, .height = 50, .x = (c.window_w - 200) / 2, .y = c.window_h - 100 };
    self.sound_enabled = true;
    self.state = .menu;
    self.start = false;
    self.intro_text_offset = c.window_h;
    self.intro_text_linecount = blk: {
        var count: i32 = 0;
        for (intro_text) |char| {
            if (char == '\n') count += 1;
        }
        break :blk count;
    };

    return self;
}

pub fn deinit(self: Self) void {
    rl.UnloadTexture(self.texture);
    rl.UnloadImage(self.image);
}

pub fn process(self: *Self) void {
    const delta = rl.GetFrameTime();
    const wf = @as(f32, @floatFromInt(self.texture.width));
    const hf = @as(f32, @floatFromInt(self.texture.height));
    switch (self.state) {
        .menu => {
            self.title_rotation += 2 * delta;
            self.title_rotation = @mod(self.title_rotation, std.math.pi * 2);
            const mouse_pos = rl.GetMousePosition();
            if (rl.IsMouseButtonPressed(0)) {
                if (rl.CheckCollisionPointRec(mouse_pos, self.start_btn)) {
                    self.state = .intro_text;
                } else if (rl.CheckCollisionPointRec(mouse_pos, self.sound_btn)) {
                    self.sound_enabled = !self.sound_enabled;
                }
            }
        },
        .intro_text => {
            self.intro_text_offset -= 20 * delta;

            if (@as(i32, @intFromFloat(self.intro_text_offset)) <= self.intro_text_linecount * -23) {
            }
        },
    }
    rl.BeginDrawing();
    defer rl.EndDrawing();

    rl.ClearBackground(rl.LIME);

    switch (self.state) {
        .menu => {
            rl.DrawTexturePro(
                self.texture,
                rl.Rectangle{ .width = wf, .height = hf, .x = 0, .y = 0 },
                rl.Rectangle{ .width = wf, .height = hf, .x = @divFloor(wf, 2), .y = @divFloor(hf, 2) },
                c.vec2(@divFloor(wf, 2), @divFloor(hf, 2)),
                @cos(self.title_rotation) * 2,
                rl.WHITE,
            );

            draw_button("Começar!", self.start_btn);
            if (self.sound_enabled) {
                draw_button("Desativar Som", self.sound_btn);
            } else {
                draw_button("Ativar Som", self.sound_btn);
            }
        },
        .intro_text => {
            rl.DrawRectangle(100, 0, c.window_w - 200, c.window_h, rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xaa });
            rl.DrawText(intro_text, 110, @intFromFloat(self.intro_text_offset), 20, rl.WHITE);
        },
    }
}

fn draw_button(text: [*c]const u8, rec: rl.Rectangle) void {
    const mouse_pos = rl.GetMousePosition();

    var color = rl.Color{ .r = 0xff, .g = 0x52, .b = 0x00, .a = 0xff };
    if (rl.CheckCollisionPointRec(mouse_pos, rec)) {
        color = rl.ColorBrightness(color, 1.25);
    }

    rl.DrawRectangleRec(rec, color);
    rl.DrawRectangleRec(rl.Rectangle{
        .width = rec.width - 10,
        .height = rec.height - 10,
        .x = rec.x + 5,
        .y = rec.y + 5,
    }, rl.Color{ .r = 0xff, .g = 0xb5, .b = 0x91, .a = 0xff });
    const len = @as(f32, @floatFromInt(rl.MeasureText(text, 20)));
    rl.DrawText(text, @intFromFloat(rec.x + ((rec.width - len) / 2)), @intFromFloat(rec.y + (rec.height / 2) - 10), 20, rl.BLACK);
}
