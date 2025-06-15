const std = @import("std");
const rl = @import("raylib.zig");
const c  = @import("commons.zig");

const Self = @This();

position: rl.Vector2,
inner: f32,
radius: f32,

position_loc: i32,
inner_loc: i32,
radius_loc: i32,

pub fn init(idx: i32, inner: f32, radius: f32, shader: rl.Shader) Self {
    const self = Self{
        .position = c.vec2(1,0),
        .inner = inner,
        .radius = radius,
        .position_loc = rl.GetShaderLocation(shader, rl.TextFormat("spots[%i].pos", idx)),
        .inner_loc = rl.GetShaderLocation(shader, rl.TextFormat("spots[%i].inner", idx)),
        .radius_loc = rl.GetShaderLocation(shader, rl.TextFormat("spots[%i].radius", idx)),
    };
    self.update(shader);
    return self;
}

pub fn update(self: Self, shader: rl.Shader) void {
    rl.SetShaderValue(shader, self.position_loc, &[_]f32{ self.position.x, self.position.y }, rl.SHADER_UNIFORM_VEC2);
    rl.SetShaderValue(shader, self.inner_loc, &[_]f32{self.inner}, rl.SHADER_UNIFORM_FLOAT);
    rl.SetShaderValue(shader, self.radius_loc, &[_]f32{self.radius}, rl.SHADER_UNIFORM_FLOAT);
}
