const std = @import("std");
const zcc = @import("compile_commands");

pub const FmtMode = enum {
    Bundled,
    StdFormat,
    FetchedWithZig,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spdlog = b.addStaticLibrary(.{
        .target = target,
        .optimize = optimize,
        .name = "spdlog",
    });

    const fmt_mode = b.option(FmtMode, "fmt_mode", "how to get the symbols needed for formatting strings") orelse .FetchedWithZig;
    const exceptions = b.option(bool, "exceptions", "whether to compile with exceptions or -fno-exceptions. Calls abort in place of exceptions.") orelse true;

    var flags = std.ArrayList([]const u8).init(b.allocator);
    defer flags.deinit();

    const exceptions_int: i8 = if (exceptions) 0 else 1;

    flags.appendSlice(&.{
        "-std=c++20",
        // options
        // "-DSPDLOG_WCHAR_TO_UTF8_SUPPORT=0", // windows only
        // "-DSPDLOG_WCHAR_FILENAMES=0",
        // "-DSPDLOG_CLOCK_COARSE=0",
        // "-DSPDLOG_PREVENT_CHILD_FD=0",
        // "-DSPDLOG_NO_THREAD_ID=0",
        // "-DSPDLOG_NO_TLS=0",
        // "-DSPDLOG_NO_ATOMIC_LEVELS=0",
        // "-DSPDLOG_DISABLE_DEFAULT_LOGGER=0",
        std.fmt.allocPrint(b.allocator, "-DSPDLOG_NO_EXCEPTIONS={any}", .{exceptions_int}) catch @panic("OOM"),
        // because we're using static lib
        "-DSPDLOG_COMPILED_LIB",
    }) catch @panic("OOM");

    if (!exceptions) {
        flags.append("-fno-exceptions") catch @panic("OOM");
    }

    switch (fmt_mode) {
        .FetchedWithZig => {
            const fmt = b.dependency("fmt", .{});
            spdlog.step.dependOn(fmt.builder.getInstallStep());
            spdlog.addIncludePath(.{
                .path = std.fs.path.join(b.allocator, &.{ fmt.builder.install_path, "include" }) catch @panic("OOM"),
            });
        },
        .Bundled => {
            if (!exceptions) {
                flags.append("-DFMT_EXCEPTIONS=0") catch @panic("OOM");
            }
        },
        .StdFormat => {
            std.log.warn("StdFormat is an unsupported fmt method when compiling with zig", .{});
            flags.append("-DSPDLOG_USE_STD_FORMAT") catch @panic("OOM");
        },
    }

    spdlog.addCSourceFiles(&.{
        "src/spdlog.cpp",
        "src/stdout_sinks.cpp",
        "src/color_sinks.cpp",
        "src/file_sinks.cpp",
        "src/async.cpp",
        "src/cfg.cpp",
    }, flags.items);

    if (fmt_mode == .Bundled) {
        spdlog.addCSourceFiles(&.{"src/bundled_fmtlib_format.cpp"}, flags.items);
    }

    spdlog.addIncludePath(.{ .path = "include" });
    spdlog.linkLibC();
    spdlog.linkLibCpp();

    spdlog.installHeadersDirectory("include/spdlog", "spdlog");

    b.installArtifact(spdlog);

    // TODO: figure out how to do this without allocating... do you have to cast?
    var targets = std.ArrayList(*std.Build.Step.Compile).init(b.allocator);
    targets.append(spdlog) catch @panic("OOM");
    zcc.createStep(b, "cdb", targets.toOwnedSlice() catch @panic("OOM"));
}
