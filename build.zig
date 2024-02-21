const std = @import("std");

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

    const raylib_module = b.dependency("raylib", .{ .optimize = optimize, .target = target });
    const raylib_artifact = raylib_module.artifact("raylib");

    // We generate the implementation for raygui.h in raygui.c
    const generate_file_step_raylib_c = b.addWriteFiles();
    const generated_file = generate_file_step_raylib_c.add("raygui/src/raygui.c", "#define RAYGUI_IMPLEMENTATION\n#include <raygui.h>");

    // Raylib raygui.c supposes that raygui is in a nearby directory, this is not true using the package manager
    // So we need to not depend on the raygui.c provided by raylib_module, but instead generate our own
    // Workaround be like
    const lib = b.addStaticLibrary(.{
        .name = "raygui",
        .root_source_file = null,
        .link_libc = true,
        .optimize = optimize,
        .target = target,
    });
    lib.addCSourceFile(.{.file = generated_file});
    
    lib.addIncludePath(.{ .path = "src/" });
    lib.step.dependOn(&generate_file_step_raylib_c.step);
    lib.linkLibrary(raylib_artifact); // raygui depends on raylib this should be linked in the artifact but sure

    const exe = b.addExecutable(.{
        .name = "raylib-example",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.linkLibrary(lib);
    exe.linkLibrary(raylib_artifact);

    exe.addIncludePath(.{ .path = "src/" }); // for raygui.h in cInclude

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
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
