const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const pcgmanager = b.dependency("pcgmanager", .{});
    exe_mod.addImport("pcgmanager", pcgmanager.module("root"));
    exe_mod.linkLibrary(pcgmanager.artifact("pcgmanager"));

    const ray = b.dependency("raylib", .{});
    exe_mod.linkLibrary(ray.artifact("raylib"));

    const exe = b.addExecutable(.{
        .name = "game",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    exe.linkLibC();

    const assets = b.addInstallDirectory(.{
        .install_dir = .bin,
        .install_subdir = "assets",
        .source_dir = b.path("assets"),
    });

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    run_cmd.step.dependOn(&assets.step);

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
