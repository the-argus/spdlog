const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spdlog = b.addStaticLibrary(.{
        .target = target,
        .optimize = optimize,
        .name = "spdlog",
    });

    spdlog.addCSourceFiles(&.{
        "src/spdlog.cpp",
        "src/stdout_sinks.cpp",
        "src/color_sinks.cpp",
        "src/file_sinks.cpp",
        "src/async.cpp",
        "src/cfg.cpp",
    }, &.{
        "-std=c++11",
        // options
        // "-DSPDLOG_WCHAR_TO_UTF8_SUPPORT=0", // windows only
        "-DSPDLOG_WCHAR_FILENAMES=0",
        "-DSPDLOG_NO_EXCEPTIONS=0",
        "-DSPDLOG_CLOCK_COARSE=0",
        "-DSPDLOG_PREVENT_CHILD_FD=0",
        "-DSPDLOG_NO_THREAD_ID=0",
        "-DSPDLOG_NO_TLS=0",
        "-DSPDLOG_NO_ATOMIC_LEVELS=0",
        "-DSPDLOG_DISABLE_DEFAULT_LOGGER=0",
        "-DSPDLOG_USE_STD_FORMAT=0",
        // because we're using static lib
        "-DSPDLOG_COMPILED_LIB",
    });

    spdlog.addIncludePath(.{ .path = "include" });
    spdlog.linkLibC();
    spdlog.linkLibCpp();

    spdlog.installHeadersDirectory("include/spdlog", "spdlog");

    b.installArtifact(spdlog);
}
