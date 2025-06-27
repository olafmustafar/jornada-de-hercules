const std = @import("std");
const rl = @import("raylib.zig");
const Direction = @import("pcgmanager").Contents.Direction;

pub const window_w = 800;
pub const window_h = 600;
pub const window_diagonal = std.math.sqrt((window_w * window_w) + (window_h * window_h));

pub fn as_f32(i: anytype) f32 {
    return @floatFromInt(i);
}

pub fn vec3(x: f32, y: f32, z: f32) rl.Vector3 {
    return rl.Vector3{ .x = x, .y = y, .z = z };
}

pub fn vec3up() rl.Vector3 {
    return vec3(0, 1, 0);
}

pub fn vec3xyz(v: f32) rl.Vector3 {
    return vec3(v, v, v);
}

pub fn vec2(x: f32, y: f32) rl.Vector2 {
    return rl.Vector2{ .x = x, .y = y };
}

pub fn look_target_rad(origin: rl.Vector2, target: rl.Vector2) f32 {
    return rl.Vector2Angle(vec2(0, 1), rl.Vector2Normalize(rl.Vector2Subtract(target, origin)));
}

pub fn dir_to_vec2(dir: Direction) rl.Vector2 {
    return switch (dir) {
        .up => vec2(0, -1),
        .down => vec2(0, 1),
        .left => vec2(-1, 0),
        .right => vec2(1, 0),
    };
}

pub fn ease_out_elastic(x: f32) f32 {
    const c4: f32 = (2 * std.math.pi) / 3.0;
    if (x == 0) {
        return 0;
    } else if (x == 1) {
        return 1;
    } else {
        return std.math.pow(f32, 2, -10 * x) * std.math.sin((x * 10 - 0.75) * c4) + 1;
    }
}

pub fn matrix_look_at(source: rl.Vector3 , target: rl.Vector3 , up: rl.Vector3 ) rl.Matrix {
    const forward = rl.Vector3Normalize(rl.Vector3Subtract(target, source));
    const right = rl.Vector3Normalize(rl.Vector3CrossProduct(up, forward));
    const realUp = rl.Vector3CrossProduct(forward, right);

    return rl.Matrix{
        .m0 = right.x,    .m1 = right.y,    .m2 = right.z,    .m3 = 0.0,
        .m4 = realUp.x,   .m5 = realUp.y,   .m6 = realUp.z,   .m7 = 0.0,
        .m8 = forward.x,  .m9 = forward.y,  .m10 = forward.z,  .m11 = 0.0,
        .m12 = 0.0,       .m13 = 0.0,       .m14 = 0.0,       .m15 = 1.0,
    };
}
