const std = @import("std");

const PCGManager = @import("pcgmanager");
const contents = PCGManager.Contents;
const c = @import("commons.zig");
const rl = @import("raylib.zig");
const rll = @import("rlights.zig");
const World = @import("World.zig");
const scenes = @import("scenes.zig");
const Menu = @import("Menu.zig");
const AudioMgr = @import("AudioMgr.zig");

const LevelArgs = struct {
    level: contents.Level,
    boss: World.BossType = .lion,
    tint: rl.Color = rl.WHITE,
    tiles: std.EnumArray(contents.Tile, ?[]const u8),
};

pub fn main() !void {
    const alloc = std.heap.c_allocator;
    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(c.window_w, c.window_h, "raylib [core] example - basic window");
    rl.SetTargetFPS(60);
    defer rl.CloseWindow();

    rl.InitAudioDevice();
    defer rl.CloseAudioDevice();
    const music = rl.LoadMusicStream("assets/Woodland-Fantasy.wav");
    defer rl.UnloadMusicStream(music);
    var timePlayed: f32 = undefined;
    rl.PlayMusicStream(music);

    const audio_mgr = AudioMgr.init();
    defer audio_mgr.deinit();

    var menu = Menu.init();
    defer menu.deinit();

    const level_args = try generate_levels(alloc);
    defer for (level_args) |lvl| lvl.level.deinit();
    var curr_i: usize = 0;
    var world = try get_world(alloc, level_args[curr_i]);
    defer world.deinit();

    while (!rl.WindowShouldClose()) {
        rl.UpdateMusicStream(music);
        timePlayed = rl.GetMusicTimePlayed(music) / rl.GetMusicTimeLength(music);
        if (timePlayed > 1.0) timePlayed = 1.0;

        if (menu.sound_enabled) {
            rl.ResumeMusicStream(music);
        } else {
            rl.PauseMusicStream(music);
        }

        if (!menu.finished) {
            menu.process();
        } else {
            try world.update();
            world.render();

            if (world.finished) {
                if (world.player.alive) curr_i += 1;

                if (curr_i == level_args.len) break;

                world.deinit();
                world = try get_world(alloc, level_args[curr_i]);
            }
        }
    }
}

fn get_world(alloc: std.mem.Allocator, args: LevelArgs) !World {
    return try World.init(alloc, args.level, args.boss, args.tint, args.tiles);
}

fn generate_levels(alloc: std.mem.Allocator) ![6]LevelArgs {
    const normal_tiles = std.EnumArray(contents.Tile, ?[]const u8).init(.{
        .empty = null,
        .plane = "assets/plane_sqrt.glb",
        .mountain = "assets/mountain_sqr.glb",
        .sand = "assets/sand_sqr.glb",
        .trees = "assets/trees_sqr.glb",
        .ocean = "assets/ocean_sqr.glb",
        .wall = "assets/wall_sqr.glb",
        .door = null,
        .size = null,
    });
    const swamp_tiles = std.EnumArray(contents.Tile, ?[]const u8).init(.{
        .empty = null,
        .plane = "assets/plane_sqrt_swamp.glb",
        .mountain = "assets/mountain_sqrt_swamp.glb",
        .sand = "assets/plane_sqrt_swamp.glb",
        .trees = "assets/trees_sqr_swamp.glb",
        .ocean = "assets/ocean_sqr_swamp.glb",
        .wall = "assets/wall_sqr.glb",
        .door = null,
        .size = null,
    });

    var levels: [6]LevelArgs = undefined;

    var pcg = try PCGManager.init(alloc);
    defer pcg.deinit();

    const yellow = rl.Color{ .r = 255, .g = 235, .b = 179, .a = 0 };
    const green = rl.Color{ .r = 86, .g = 117, .b = 115, .a = 0 };
    const light_green = rl.Color{ .r = 227, .g = 255, .b = 163, .a = 0 };

    levels[0].level = try scenes.initial_scene(alloc);
    levels[0].tint = yellow;
    levels[0].tiles = normal_tiles;

    pcg.context.difficulty_level = 4;
    try pcg.generate(.{ .rooms = .{ .generate = .{} } });
    try pcg.generate(.{ .enemies = .{ .generate = .{} } });
    try pcg.generate(.{ .architecture = .{ .generate = .{
        .diameter = 3,
        .max_corridor_length = 3,
        .branch_chance = 0.25,
        .min_branch_diameter = 2,
        .max_branch_diameter = 5,
        .change_direction_chance = 0.25,
    } } });
    levels[1] = .{
        .level = try pcg.retrieve_level(),
        .tint = yellow,
        .tiles = normal_tiles,
        .boss = .lion,
    };

    levels[2] = .{
        .level = try scenes.second_scene(alloc),
        .tint = green,
        .tiles = swamp_tiles,
    };

    pcg.context.difficulty_level = 4;
    try pcg.generate(.{ .enemies = .{ .generate = .{} } });
    try pcg.generate(.{ .architecture = .{ .generate = .{
        .diameter = 5,
        .max_corridor_length = 2,
        .branch_chance = 0.25,
        .min_branch_diameter = 1,
        .max_branch_diameter = 1,
        .change_direction_chance = 0.30,
    } } });
    levels[3] = .{
        .level = try pcg.retrieve_level(),
        .tint = green,
        .boss = .hydra,
        .tiles = swamp_tiles,
    };

    levels[4] = .{
        .level = try scenes.third_scene(alloc),
        .tint = light_green,
        .tiles = normal_tiles,
        .boss = .stag,
    };

    pcg.context.difficulty_level = 4;
    try pcg.generate(.{ .enemies = .{ .generate = .{} } });
    try pcg.generate(.{ .architecture = .{ .generate = .{
        .diameter = 6,
        .max_corridor_length = 3,
        .branch_chance = 0.25,
        .min_branch_diameter = 2,
        .max_branch_diameter = 5,
        .change_direction_chance = 0.25,
    } } });
    levels[5] = .{
        .level = try pcg.retrieve_level(),
        .tint = light_green,
        .tiles = normal_tiles,
        .boss = .stag,
    };

    return levels;
}

fn _test() void {
    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(c.window_w, c.window_h, "raylib [core] example - basic window");
    rl.SetTargetFPS(60);
    defer rl.CloseWindow();

    var menu = Menu.init();
    while (!rl.WindowShouldClose()) {
        menu.process();
    }
}
