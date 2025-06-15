const rl = @import("raylib.zig");
const Direction = @import("pcgmanager").Contents.Direction;

pub fn vec3(x: f32, y: f32, z: f32) rl.Vector3 {
    return rl.Vector3{ .x = x, .y = y, .z = z };
}

pub fn vec2(x: f32, y: f32) rl.Vector2 {
    return rl.Vector2{ .x = x, .y = y };
}

pub fn dir_to_vec2(dir: Direction) rl.Vector2 {
    return switch (dir) {
        .up => vec2(0, -1),
        .down => vec2(0, 1),
        .left => vec2(-1, 0),
        .right => vec2(1, 0),
    };
}
