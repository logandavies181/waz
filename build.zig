const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const miniaudio_translate = b.addTranslateC(.{
        .root_source_file = b.path("vendor/miniaudio.h"),
        .target = target,
        .optimize = optimize,
    });
    miniaudio_translate.addIncludePath(b.path("."));
    const miniaudio_mod = miniaudio_translate.createModule();

    // Create the executable and compile miniaudio's implementation as C.
    const exe = b.addExecutable(.{
        .name = "waz",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("miniaudio", miniaudio_mod);
    exe.root_module.addIncludePath(b.path("."));
    exe.root_module.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{"miniaudio.c"},
    });

    // Link system dependencies as required by your target OS
    exe.root_module.link_libc = true;
    const target_os = target.result.os.tag;
    switch (target_os) {
        .linux => {
            exe.root_module.linkSystemLibrary("pthread", .{});
            exe.root_module.linkSystemLibrary("m", .{});
            exe.root_module.linkSystemLibrary("dl", .{});
        },
        .macos => {
            exe.root_module.linkFramework("CoreAudio", .{});
            exe.root_module.linkFramework("AudioToolbox", .{});
        },
        .windows => {
            exe.root_module.linkSystemLibrary("winmm", .{});
        },
        else => {},
    }

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Zig 0.17 replaces the older `if (b.args) |args| run_cmd.addArgs(args);`
    // with this cleaner alternative:
    run_cmd.addPassthruArgs();

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
