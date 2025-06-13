const std = @import("std");
const Level = @import("pcgmanager").Contents.Level;

const spawn = 
\\######@@#######
\\..T..........T..
\\............T...
\\....T...........
\\.............T..
\\..T.......T.....
\\................
\\................

//todo create models

pub fn initial_scene(alloc: std.mem.Allocator) !Level {
    var level = try Level.init(alloc, 10, 10);

    // level.tilemap.set(
    // tilemap: Tilemap,

    room_rects: std.ArrayList(Rect),
    enemies: std.ArrayList(EnemyLocation),
}
