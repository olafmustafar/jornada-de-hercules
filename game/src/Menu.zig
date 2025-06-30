const std = @import("std");
const c = @import("commons.zig");
const rl = @import("raylib.zig");
const rll = @import("rlights.zig");
const builtin = @import("builtin");

const Self = @This();
const glsl_version: i32 = if (builtin.target.cpu.arch.isWasm()) 100 else 330;
const intro_text =
    \\Dizem que Hércules foi o mais forte dos homens.
    \\Dizem que era filho de Zeus, senhor dos céus.
    \\Mas o que raramente se diz, é o preço que ele pagou 
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
    \\Buscando perdão - ou pelo menos, alívio -, Hércules 
    \\ foi até o oráculo de Delfos.
    \\E ali recebeu sua sentença:
    \\Deveria servir a Euristeu, rei de Micenas.
    \\Não como guerreiro, mas como servo. E cumprir doze 
    \\ trabalhos impossíveis ...
;
const ending_text =
    \\Outra vez, passos firmes sobre um chão que treme
    \\ diante do seu nome.
    \\Hércules — filho do trovão, moldado na dor, forjado
    \\ na sombra dos deuses.
    \\
    \\Mas não é força o que o espera.
    \\Não é glória.
    \\O que o aguarda é o silêncio entre as batalhas,
    \\O vazio entre os gritos,
    \\A lenta corrosão que consome até os maiores.
    \\
    \\Porque não há repouso para os escolhidos.
    \\Nem paz para os que carregam o fardo da lenda.
    \\
    \\E, no entanto, ele caminha.
    \\Não por ambição.
    \\Mas por um tipo de necessidade que nem os deuses
    \\ compreendem
    \\Uma busca por redenção, talvez...
    \\Ou apenas por sentido.
    \\
    \\Cada passo o leva mais longe dos mortais
    \\E mais perto de algo que nenhum mortal jamais tocou:
    \\A eternidade... ou o esquecimento.
    \\
    \\Que os ventos o levem com respeito.
    \\Que os céus se calem ao vê-lo passar.
    \\Pois não há tarefa maior do que carregar o próprio 
    \\ nome
    \\Como se fosse um fardo.
;

const credits =
    \\Créditos: 
    \\Música por Maththew-pablo
    \\opengameart.org/users/matthew-pablo
    \\
    \\Modelos dos animais por Quaternius
    \\quaternius.com
    \\
    \\Código por Arthur R. P. So
;

fn line_count(comptime text: []const u8) i32 {
    var count: i32 = 0;
    for (text) |char| {
        if (char == '\n') count += 1;
    }
    return count;
}

const State = enum { menu, intro_text, black_screen, finish_text, play_again };

finished: bool = false,
sound_enabled: bool,
state: State,

background: rl.Model,
animation: struct { [*c]rl.ModelAnimation, i32 },
frame: i32,
camera: rl.Camera,
image: rl.Image,
texture: rl.Texture,
title_rotation: f32,

shader: rl.Shader,
light: rll.Light,

start_btn: rl.Rectangle,

sound_btn: rl.Rectangle,
text_offset: f32,
black_screen_alpha: f32,

play_again_btn: rl.Rectangle,

pub fn init() Self {
    var self: Self = undefined;

    self.camera = .{
        .fovy = 60,
        .position = c.vec3(7, 5, 4),
        .target = rl.Vector3Zero(),
        .projection = rl.CAMERA_PERSPECTIVE,
        .up = c.vec3up(),
    };

    self.shader = rl.LoadShader(
        rl.TextFormat("assets/shaders/glsl%i/lighting.vs", glsl_version),
        rl.TextFormat("assets/shaders/glsl%i/lighting.fs", glsl_version),
    );
    const ambientLoc = rl.GetShaderLocation(self.shader, "ambient");
    rl.SetShaderValue(self.shader, ambientLoc, &[4]f32{ 3.0, 3.0, 3.0, 10.0 }, rl.SHADER_UNIFORM_VEC4);
    self.light = rll.CreateLight(rll.Light.Type.point, rl.Vector3Zero(), rl.Vector3Zero(), rl.WHITE, self.shader);

    self.background = rl.LoadModel("assets/menu.glb");
    self.background.materials[1].shader = self.shader;
    self.background.materials[2].shader = self.shader;
    self.background.materials[3].shader = self.shader;
    var animation_count: i32 = 0;
    const animation = rl.LoadModelAnimations("assets/menu.glb", &animation_count);
    self.animation = .{ animation, animation_count };
    self.frame = 0;

    self.finished = false;
    self.sound_enabled = false;
    self.state = .menu;
    self.image = rl.LoadImage("assets/title.png");
    self.texture = rl.LoadTextureFromImage(self.image);
    self.title_rotation = 0;
    self.start_btn = rl.Rectangle{ .width = 200, .height = 50, .x = (c.window_w - 200) / 2, .y = c.window_h - 160 };
    self.sound_btn = rl.Rectangle{ .width = 200, .height = 50, .x = (c.window_w - 200) / 2, .y = c.window_h - 100 };
    self.play_again_btn = rl.Rectangle{ .width = 300.0, .height = 75.0, .x = (c.window_w - 300) / 2, .y = c.window_h - 160 };
    self.text_offset = c.window_h;
    self.black_screen_alpha = 0;

    return self;
}

pub fn start_ending(self: *Self) void {
    self.finished = false;
    self.black_screen_alpha = 1;
    self.text_offset = c.window_h;
    self.state = .finish_text;
}

pub fn deinit(self: Self) void {
    rl.UnloadModel(self.background);
    rl.UnloadModelAnimations(self.animation.@"0", self.animation.@"1");
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
                    self.text_offset = c.window_h;
                    self.state = .intro_text;
                } else if (rl.CheckCollisionPointRec(mouse_pos, self.sound_btn)) {
                    self.sound_enabled = !self.sound_enabled;
                }
            }
        },
        .intro_text => {
            if (rl.IsMouseButtonDown(0)) {
                self.text_offset -= 230 * delta;
            } else {
                self.text_offset -= 25 * delta;
            }
            if (@as(i32, @intFromFloat(self.text_offset)) <= line_count(intro_text) * -23) {
                self.state = .black_screen;
            }
        },
        .black_screen => {
            self.black_screen_alpha = @min(self.black_screen_alpha + (0.5 * delta), 1);
            if (self.black_screen_alpha >= 1) {
                self.finished = true;
            }
        },
        .finish_text => {
            self.black_screen_alpha = @max(self.black_screen_alpha - (0.5 * delta), 0);
            if (rl.IsMouseButtonDown(0)) {
                self.text_offset -= 230 * delta;
            } else {
                self.text_offset -= 25 * delta;
            }

            if (@as(i32, @intFromFloat(self.text_offset)) <= line_count(ending_text) * -23) {
                self.state = .play_again;
            }
        },
        .play_again => {
            if (rl.IsMouseButtonPressed(0) and rl.CheckCollisionPointRec(rl.GetMousePosition(), self.play_again_btn)) {
                self.state = .menu;
            }
        },
    }

    self.light.position = rl.Vector3Add(self.camera.position, c.vec3(5, 5, 5));
    rll.UpdateLightValues(self.shader, self.light);

    self.frame = @mod(self.frame + 1, self.animation.@"0"[9].frameCount);
    rl.UpdateModelAnimation(self.background, self.animation.@"0"[9], self.frame);

    rl.BeginDrawing();
    defer rl.EndDrawing();

    rl.ClearBackground(rl.SKYBLUE);

    {
        rl.BeginMode3D(self.camera);
        defer rl.EndMode3D();
        rl.UpdateCamera(&self.camera, rl.CAMERA_CUSTOM);
        rl.DrawModel(self.background, rl.Vector3Zero(), 1.0, rl.WHITE);
    }
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
            rl.DrawText(intro_text, 110, @intFromFloat(self.text_offset), 20, rl.WHITE);
        },
        .black_screen => {
            const alpha: u8 = @intFromFloat(self.black_screen_alpha * 0xff);
            rl.DrawRectangle(100, 0, c.window_w - 200, c.window_h, rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xaa });
            rl.DrawRectangle(0, 0, c.window_w, c.window_h, rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = alpha });
        },
        .finish_text => {
            const alpha: u8 = @intFromFloat(self.black_screen_alpha * 0xff);
            rl.DrawRectangle(0, 0, c.window_w, c.window_h, rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = alpha });
            rl.DrawRectangle(100, 0, c.window_w - 200, c.window_h, rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xaa });
            rl.DrawText(ending_text, 110, @intFromFloat(self.text_offset), 20, rl.WHITE);
        },
        .play_again => {
            rl.DrawRectangle(100, 0, c.window_w - 200, c.window_h, rl.Color{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xaa });
            rl.DrawText("Obrigado Por Jogar!", 110, 40, 30, rl.YELLOW);
            rl.DrawText(credits, 110, 80, 20, rl.WHITE);
            draw_button("Recomeçar", self.play_again_btn);
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
