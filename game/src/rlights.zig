const rl = @import("raylib.zig");
const std = @import("std");

pub const MAX_LIGHTS = 4;

pub const Light = struct {
    pub const Type = enum(i32) {
        directional = 0,
        point = 1,
    };

    type: Type,
    enabled: bool,
    position: rl.Vector3,
    target: rl.Vector3,
    color: rl.Color,
    attenuation: f32,

    // Shader locations
    enabledLoc: i32,
    typeLoc: i32,
    positionLoc: i32,
    targetLoc: i32,
    colorLoc: i32,
    attenuationLoc: i32,
};

var lightsCount: i32 = 0;

pub fn CreateLight(ltype: Light.Type, position: rl.Vector3, target: rl.Vector3, color: rl.Color, shader: rl.Shader) Light {
    var light: Light = undefined;

    if (lightsCount < MAX_LIGHTS) {
        light.enabled = true;
        light.type = ltype;
        light.position = position;
        light.target = target;
        light.color = color;

        // NOTE: Lighting shader naming must be the provided ones
        light.enabledLoc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].enabled", lightsCount));
        light.typeLoc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].type", lightsCount));
        light.positionLoc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].position", lightsCount));
        light.targetLoc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].target", lightsCount));
        light.colorLoc = rl.GetShaderLocation(shader, rl.TextFormat("lights[%i].color", lightsCount));

        UpdateLightValues(shader, light);

        lightsCount = lightsCount + 1;
    }

    return light;
}

pub fn UpdateLightValues(shader: rl.Shader, light: Light) void {
    rl.SetShaderValue(shader, light.enabledLoc, &[_]i32{@intFromBool(light.enabled)}, rl.SHADER_UNIFORM_INT);
    rl.SetShaderValue(shader, light.typeLoc, &[_]i32{@intFromEnum(light.type)}, rl.SHADER_UNIFORM_INT);

    const position = [_]f32{ light.position.x, light.position.y, light.position.z };
    rl.SetShaderValue(shader, light.positionLoc, &position, rl.SHADER_UNIFORM_VEC3);

    const target = [_]f32{ light.target.x, light.target.y, light.target.z };
    rl.SetShaderValue(shader, light.targetLoc, &target, rl.SHADER_UNIFORM_VEC3);

    const color = [_]f32{
        @as(f32, @floatFromInt(light.color.r)) / 255.0,
        @as(f32, @floatFromInt(light.color.g)) / 255.0,
        @as(f32, @floatFromInt(light.color.b)) / 255.0,
        @as(f32, @floatFromInt(light.color.a)) / 255.0,
    };

    rl.SetShaderValue(shader, light.colorLoc, &color, rl.SHADER_UNIFORM_VEC4);
}
