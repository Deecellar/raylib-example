const std = @import("std");
const raylib = @import("raylib");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const raygui_dep = b.dependency("raygui", .{});
    const raylib_dep = b.dependency("raylib", .{});

    const exe = b.addExecutable(.{
        .name = "raylib-example",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    const raylib_lib = raylib.addRaylib(b, target, optimize, .{}) catch @panic("AAAH! Raylib failed to build!");
    var gen_step = b.addWriteFiles();
    raylib_lib.step.dependOn(&gen_step.step);

    const raygui_c_path = gen_step.add("raygui.c", "#define RAYGUI_IMPLEMENTATION\n#include \"raygui.h\"\n");
    const lib = b.addStaticLibrary(.{
        .link_libc = true,
        .name = "raygui",
        .target = target,
        .optimize = optimize,
    });
    lib.addCSourceFile(.{ .file = raygui_c_path, .flags = &.{
        "-std=gnu99",
        "-D_GNU_SOURCE",
        "-DGL_SILENCE_DEPRECATION=199309L",
        "-fno-sanitize=undefined",
        "-fPIC",
        "-DBUILD_LIBTYPE_SHARED",
    } });
    lib.addIncludePath(raylib_dep.path("src"));
    lib.linkLibrary(raylib_lib);
    lib.addIncludePath(raygui_dep.path("src"));

    exe.linkLibrary(lib);
    exe.addIncludePath(raylib_dep.path("src"));
    exe.addIncludePath(raygui_dep.path("src"));
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
