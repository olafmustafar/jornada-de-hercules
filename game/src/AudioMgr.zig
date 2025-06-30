const rl = @import("raylib.zig");

const Self = @This();

var g_sounds: ?Self = null;

enemy_die: rl.Sound,
hit: rl.Sound,
swoosh: rl.Sound,

pub fn get() Self {
    return g_sounds.?;
}

fn set(world: ?Self) void {
    g_sounds = world;
}

pub fn init() Self {
    const self = Self{
        .enemy_die = rl.LoadSound("assets/enemy_die.wav"),
        .hit = rl.LoadSound("assets/hit.wav"),
        .swoosh = rl.LoadSound("assets/swoosh.wav"),
    };
    set(self);
    return self;
}

pub fn deinit(self: Self) void {
    rl.UnloadSound(self.enemy_die);
    rl.UnloadSound(self.hit);
    rl.UnloadSound(self.swoosh);
    set(null);
}
