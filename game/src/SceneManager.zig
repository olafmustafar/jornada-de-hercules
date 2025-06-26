const std = @import("std");

const contents = @import("pcgmanager").Contents;
const Level = contents.Level;
const Tile = contents.Tile;
const PCGManager = @import("pcgmanager");
const c = @import("commons.zig");

const rl = @import("raylib.zig");
const World = @import("World.zig");

pub const LevelArgs = struct {
    level: contents.Level,
    boss: World.BossType = .lion,
    tint: rl.Color = rl.WHITE,
    tiles: std.EnumArray(contents.Tile, ?[]const u8),
};

const ArchitectureArgs = std.meta.TagPayloadByName(std.meta.TagPayloadByName(PCGManager.Instruction, "architecture"), "generate");

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

const yellow = rl.Color{ .r = 255, .g = 235, .b = 179, .a = 0 };
const green = rl.Color{ .r = 86, .g = 117, .b = 115, .a = 0 };
const light_green = rl.Color{ .r = 227, .g = 255, .b = 163, .a = 0 };

const spawn =
    \\TTTTTTTTT#..#TTTTTTTTT
    \\TTTTTTTTT#..#TTTTTTTTT
    \\TTTTTTTTT#..#TTTTTTTTT
    \\TTTTTTTTT#..#TTTTTTTTT
    \\TTTT######dd######TTTT
    \\TTTT#............#TTTT
    \\TTTT#............#TTTT
    \\TTTT#............#TTTT
    \\TTTT#............#TTTT
    \\TTTT######dd######TTTT
    \\TTT...T.........TTTTTT
    \\TTTTT............TTTTT
    \\TTT.....T.........TTTT
    \\TTTT............T.TTTT
    \\TTTT.TT.......T.TTTTTT
    \\TTT...............TTTT
    \\TTTT................TT
    \\TTT...TT.T....T.TT.TTT
    \\TTTTTTTTTT..TTTTTTTTTT
    \\TTTTTTTTTT.TTTTTTTTTTT
    \\TTTTTTTTTTTTTTTTTTTTTT
    \\TTTTTTTTTTTTTTTTTTTTTT
;

const Self = @This();

pcg: PCGManager,
current: i32,
gpa: std.mem.Allocator,

pub fn init(alloc: std.mem.Allocator) !Self {
    var self = Self{
        .pcg = try PCGManager.init(alloc),
        .current = 0,
        .gpa = alloc,
    };
    self.pcg.context.enemy_hit_rate = 0.8;
    self.pcg.context.rate_bullets_hit = 0.8;
    return self;
}

pub fn deinit(self: *Self) void {
    self.pcg.deinit();
}

pub fn next(self: *Self) bool {
    if (self.current == 5) return false;

    self.current += 1;
    return true;
}

pub fn update_stats(self: *Self, stats: World.Stats) void {
    if (std.mem.containsAtLeastScalar(i32, &[_]i32{ 1, 3, 4 }, 1, self.current)) {
        self.pcg.context.rate_bullets_hit = c.as_f32(stats.bullets_hit) / c.as_f32(stats.bullets_shot);
        self.pcg.context.enemy_hit_rate = c.as_f32(stats.enemies_hit_player) / c.as_f32(stats.enemies_activated);
    }
}

pub fn get_current(self: *Self) !LevelArgs {
    return switch (self.current) {
        0 => initial_scene(self.gpa),
        1 => .{
            .level = try generate_level(&self.pcg, 4, .{
                .diameter = 3,
                .max_corridor_length = 3,
                .branch_chance = 0.25,
                .min_branch_diameter = 2,
                .max_branch_diameter = 5,
                .change_direction_chance = 0.25,
            }),
            .tint = yellow,
            .tiles = normal_tiles,
            .boss = .lion,
        },
        2 => second_scene(self.gpa),
        3 => .{
            .level = try generate_level(&self.pcg, 4, .{
                .diameter = 5,
                .max_corridor_length = 2,
                .branch_chance = 0.25,
                .min_branch_diameter = 1,
                .max_branch_diameter = 1,
                .change_direction_chance = 0.30,
            }),
            .tint = green,
            .boss = .hydra,
            .tiles = swamp_tiles,
        },
        4 => third_scene(self.gpa),
        5 => .{
            .level = try generate_level(&self.pcg, 4, .{
                .diameter = 6,
                .max_corridor_length = 3,
                .branch_chance = 0.25,
                .min_branch_diameter = 2,
                .max_branch_diameter = 5,
                .change_direction_chance = 0.25,
            }),
            .tint = light_green,
            .tiles = normal_tiles,
            .boss = .stag,
        },
        else => unreachable,
    };
}
fn generate_level(pcg: *PCGManager, difficulty: usize, architecture: ArchitectureArgs) !Level {
    pcg.context.difficulty_level = difficulty;
    try pcg.generate(.{ .rooms = .{ .generate = .{} } });
    try pcg.generate(.{ .enemies = .{ .generate = .{} } });
    try pcg.generate(.{ .architecture = .{ .generate = architecture } });
    return try pcg.retrieve_level();
}

fn initial_scene(alloc: std.mem.Allocator) !LevelArgs {
    return .{
        .level = blk: {
            var level = try Level.from_string(alloc, spawn);
            try level.placeholders.append(.{ .position = .init(10, 14), .entity = .{ .player = {} } });
            try level.placeholders.append(.{ .position = .init(8, 5), .entity = .{ .npc = .{
                .name = "Rei Euristeu",
                .dialog = &[_][]const u8{
                    \\
                    \\Hércules!
                    ,
                    \\Esse será 
                    \\teu primeiro trabalho:
                    \\Enfrenta o Leão de Nemeia!
                    ,
                    \\Um leão, dizem os camponeses
                    \\Não é criatura de carne comum,
                    \\Suas garras dilaceram ferro.
                    \\Sua pele… impenetrável
                    ,
                    \\Vai, Hércules!
                    \\O tempo dos deuses
                    \\já não te protege
                },
            } } });

            try level.placeholders.append(.{ .position = .init(13, 5), .entity = .{ .item = {} } });
            try level.placeholders.append(.{ .position = .init(10, 4), .entity = .{ .exit = .up } });
            try level.placeholders.append(.{ .position = .init(11, 4), .entity = .{ .exit = .up } });
            try level.room_rects.append(.{ .x = 4, .y = 4, .w = 14, .h = 6 });
            try level.room_rects.append(.{ .x = 4, .y = 10, .w = 14, .h = 8 });
            break :blk level;
        },
        .tint = yellow,
        .tiles = normal_tiles,
        .boss = .lion,
    };
}

fn second_scene(alloc: std.mem.Allocator) !LevelArgs {
    return LevelArgs{
        .level = blk: {
            var level = try Level.from_string(alloc, spawn);
            try level.placeholders.append(.{ .position = .init(10, 14), .entity = .{ .player = {} } });
            try level.placeholders.append(.{ .position = .init(8, 5), .entity = .{ .npc = .{
                .name = "Rei Euristeu",
                .dialog = &[_][]const u8{
                    \\Cumpriste com suor e 
                    \\sangue o primeiro fardo,
                    \\domando o Leão de Neméia.
                    \\
                    \\Mas tua pena não se encerra
                    \\ - não ainda
                    ,
                    \\teu segundo trabalho se ergue 
                    \\das águas infectas de Lerna.
                    \\Lá, sob o lodo pestilento 
                    \\e os juncos envenenados,
                    \\rasteja a Hidra
                    ,
                    \\Vai, portanto, ao pântano 
                    \\ amaldiçoado. 
                    \\Que teus passos não vacilem 
                    \\ no charco traiçoeiro!
                },
            } } });

            try level.placeholders.append(.{ .position = .init(13, 5), .entity = .{ .item = {} } });
            try level.placeholders.append(.{ .position = .init(10, 4), .entity = .{ .exit = .up } });
            try level.placeholders.append(.{ .position = .init(11, 4), .entity = .{ .exit = .up } });
            try level.room_rects.append(.{ .x = 4, .y = 4, .w = 14, .h = 6 });
            try level.room_rects.append(.{ .x = 4, .y = 10, .w = 14, .h = 8 });
            break :blk level;
        },
        .boss = .hydra,
        .tint = green,
        .tiles = swamp_tiles,
    };
}

fn third_scene(alloc: std.mem.Allocator) !LevelArgs {
    return .{
        .level = blk: {
            var level = try Level.from_string(alloc, spawn);
            try level.placeholders.append(.{ .position = .init(10, 14), .entity = .{ .player = {} } });
            try level.placeholders.append(.{ .position = .init(8, 5), .entity = .{ .npc = .{
                .name = "Rei Euristeu",
                .dialog = &[_][]const u8{
                    \\tua jornada não se 
                    \\ encerra com a morte 
                    \\nem do leão, nem da serpente
                    ,
                    \\Ao norte da Arcádia, 
                    \\sob as sombras dos 
                    \\ pinheiros eternos, 
                    \\vagueia um ser que 
                    \\ nenhum caçador jamais tocou 
                    \\a Corça de Cerínia.
                    ,

                    \\Não a mates. Não a firas. 
                    \\Captura-a viva. 
                    \\ Sem trapaça, sem crueldade. 
                    \\Tua força não te bastará.
                    ,
                    \\Vai... e que tuas pegadas 
                    \\não desapareçam na floresta
                    \\ antes de teu retorno
                },
            } } });
            try level.placeholders.append(.{ .position = .init(13, 5), .entity = .{ .item = {} } });
            try level.placeholders.append(.{ .position = .init(10, 4), .entity = .{ .exit = .up } });
            try level.placeholders.append(.{ .position = .init(11, 4), .entity = .{ .exit = .up } });
            try level.room_rects.append(.{ .x = 4, .y = 4, .w = 14, .h = 6 });
            try level.room_rects.append(.{ .x = 4, .y = 10, .w = 14, .h = 8 });
            break :blk level;
        },
        .tint = light_green,
        .tiles = normal_tiles,
        .boss = .stag,
    };
}

pub fn test_scene(alloc: std.mem.Allocator) !Level {
    const empty =
        \\##############
        \\#............#
        \\#............#
        \\#............#
        \\#............#
        \\#............#
        \\#............#
        \\#............#
        \\#............#
        \\##############
    ;

    var level = try Level.from_string(alloc, empty);
    try level.room_rects.append(.{ .x = 0, .y = 0, .w = 14, .h = 10 });
    try level.placeholders.append(.{ .position = .init(6, 4), .entity = .{ .player = {} } });
    try level.placeholders.append(.{ .position = .init(6, 2), .entity = .{ .enemy = .{
        .type = .boss,
        .health = 0.1,
        .damage = 0.1,
        .velocity = 0.1,
        .shooting_velocity = 0.1,
    } } });

    return level;
}
