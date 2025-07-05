const std = @import("std");

const PCGManager = @import("pcgmanager");
const contents = PCGManager.Contents;
const c = @import("commons.zig");
const rl = @import("raylib.zig");
const World = @import("World.zig");
const SceneManager = @import("SceneManager.zig");
const Menu = @import("Menu.zig");
const AudioMgr = @import("AudioMgr.zig");

pub fn main() !void {
    const alloc = std.heap.c_allocator;
    rl.SetConfigFlags(rl.FLAG_MSAA_4X_HINT);
    rl.InitWindow(c.window_w, c.window_h, "A Jornada de Hércules");
    rl.SetTargetFPS(60);
    defer rl.CloseWindow();

    rl.InitAudioDevice();
    defer rl.CloseAudioDevice();
    const music = rl.LoadMusicStream("assets/Woodland-Fantasy.wav");
    defer rl.UnloadMusicStream(music);
    rl.PlayMusicStream(music);

    const audio_mgr = AudioMgr.init();
    defer audio_mgr.deinit();

    var menu = Menu.init();
    defer menu.deinit();

    var scene_mgr = try SceneManager.init(alloc);
    defer scene_mgr.deinit();

    var world = try get_world(alloc, try scene_mgr.get_current());
    defer world.deinit();

    var state: enum { inicio, meio, fim } = .inicio;
    while (!rl.WindowShouldClose()) {
        rl.UpdateMusicStream(music);
        _ = rl.GetMusicTimePlayed(music) / rl.GetMusicTimeLength(music);

        if (menu.sound_enabled) {
            rl.ResumeMusicStream(music);
        } else {
            rl.PauseMusicStream(music);
        }

        switch (state) {
            .inicio => {
                menu.process();
                if (menu.finished) {
                    state = .meio;
                }
            },
            .meio => {
                try world.update();
                world.render();

                if (world.finished) {
                    scene_mgr.update_stats(world.stats);
                    if (world.player.alive) {
                        if (!scene_mgr.next()) {
                            state = .fim;
                            scene_mgr.current = 0;
                        }
                    } else {
                        scene_mgr.set_reduce_difficulty();
                    }

                    world.deinit();
                    world = try get_world(alloc, try scene_mgr.get_current());
                }
            },
            .fim => {
                menu.start_ending();
                state = .inicio;
            },
        }
    }
}

fn get_world(alloc: std.mem.Allocator, args: SceneManager.LevelArgs) !World {
    return try World.init(alloc, args.level, args.boss, args.tint, args.tiles, args.level_name); 
}
