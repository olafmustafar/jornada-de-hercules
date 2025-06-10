const std = @import("std");
const builtin = @import("builtin");

pub fn compile_for_desktop(b: *std.Build) void {
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

pub fn compile_for_wasm(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    if (b.sysroot == null) {
        @panic("Pass '--sysroot \"[path to emsdk installation]/upstream/emscripten\"'");
    }
    const wasm_target = b.resolveTargetQuery(.{
        .cpu_arch = .wasm32,
        .os_tag = .emscripten,
        .cpu_model = .{ .explicit = &std.Target.wasm.cpu.mvp },
        .cpu_features_add = std.Target.wasm.featureSet(&.{
            .atomics,
            .bulk_memory,
        }),
    });

    const exe_lib = b.addStaticLibrary(.{
        .name = "game",
        .root_source_file = b.path("src/main.zig"),
        .target = wasm_target,
        .optimize = optimize,
        .link_libc = true,
    });
    exe_lib.shared_memory = false;
    exe_lib.root_module.single_threaded = false;

    const raylib_dep = b.dependency("raylib", .{
        .target = wasm_target,
        .optimize = optimize,
        .rmodels = false,
    });
    const raylib_artifact = raylib_dep.artifact("raylib");
    exe_lib.linkLibrary(raylib_artifact);
    exe_lib.addIncludePath(raylib_dep.path("src"));

    const sysroot_include = b.pathJoin(&.{ b.sysroot.?, "cache", "sysroot", "include" });
    var dir = std.fs.openDirAbsolute(sysroot_include, std.fs.Dir.OpenDirOptions{ .access_sub_paths = true, .no_follow = true }) catch @panic("No emscripten cache. Generate it!");
    dir.close();

    exe_lib.addIncludePath(.{ .cwd_relative = sysroot_include });
    addAssets(b, exe_lib);

    const emcc_exe_path = b.pathJoin(&.{ b.sysroot.?, "emcc" });
    const emcc_command = b.addSystemCommand(&[_][]const u8{emcc_exe_path});
    emcc_command.addArgs(&[_][]const u8{
        "-o",
        "zig-out/web/index.html",
        "-sFULL-ES3=1",
        "-sUSE_GLFW=3",
        "-O3",

        // "-sAUDIO_WORKLET=1",
        // "-sWASM_WORKERS=1",

        "-sASYNCIFY",
        // TODO currently deactivated because it seems as if it doesn't work with local hosting debug workflow
        // "-pthread",
        // "-sPTHREAD_POOL_SIZE=4",

        "-sINITIAL_MEMORY=167772160",
        //"-sEXPORTED_FUNCTIONS=_main,__builtin_return_address",

        // USE_OFFSET_CONVERTER required for @returnAddress used in
        // std.mem.Allocator interface
        "-sUSE_OFFSET_CONVERTER",
        "--shell-file",
        b.path("src/shell.html").getPath(b),
    });

    const link_items: []const *std.Build.Step.Compile = &.{
        raylib_artifact,
        exe_lib,
    };
    for (link_items) |item| {
        emcc_command.addFileArg(item.getEmittedBin());
        emcc_command.step.dependOn(&item.step);
    }

    const install = emcc_command;
    b.default_step.dependOn(&install.step);
}
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    if (target.result.cpu.arch == .wasm32) {
        compile_for_wasm(b);
    } else {
        compile_for_desktop(b);
    }
}
