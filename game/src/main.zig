const std = @import("std");

const PCGManager = @import("pcgmanager");
const contents = PCGManager.Contents;
const c = @import("commons.zig");
const rl = @import("raylib.zig");
const rll = @import("rlights.zig");
const World = @import("World.zig");
const SceneManager = @import("SceneManager.zig");
const Menu = @import("Menu.zig");
const AudioMgr = @import("AudioMgr.zig");

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

    var scene_mgr = try SceneManager.init(alloc);
    defer scene_mgr.deinit();

    var world = try get_world(alloc, try scene_mgr.get_current());
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
                scene_mgr.update_stats(world.stats);
                if (world.player.alive) {
                    if (!scene_mgr.next()) {
                        break;
                    }
                }
                const bullets_hit = world.stats.bullets_hit;
                const bullets_shot = world.stats.bullets_shot;
                const enemies_hit_player = world.stats.enemies_hit_player;
                const enemies_activated = world.stats.enemies_activated;

                world.deinit();
                world = try get_world(alloc, try scene_mgr.get_current());

                std.debug.print("status updated \n", .{});
                std.debug.print("    bullets_hit {d}\n", .{bullets_hit});
                std.debug.print("    bullets_shot {d}\n", .{bullets_shot});
                std.debug.print("    enemies_hit_player {d}\n", .{enemies_hit_player});
                std.debug.print("    enemies_activated {d}\n", .{enemies_activated});
                std.debug.print("    rate_bullets_hit {d}\n", .{scene_mgr.pcg.context.rate_bullets_hit});
                std.debug.print("    enemY_hit_rate {d}\n", .{scene_mgr.pcg.context.enemy_hit_rate});

                std.debug.print("enemies: \n", .{});
                for (world.enemies.items) |e| {
                    std.debug.print("    {s}\n", .{std.enums.tagName(contents.Enemy.Type, e.enemy.type).?});
                }
            }
        }
    }
}

fn get_world(alloc: std.mem.Allocator, args: SceneManager.LevelArgs) !World {
    return try World.init(alloc, args.level, args.boss, args.tint, args.tiles);
}
