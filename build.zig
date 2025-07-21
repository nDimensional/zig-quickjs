const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    // const target = b.standardTargetOptions(.{});

    const quickjs_dep = b.dependency("quickjs", .{});
    const quickjs = b.addModule("quickjs", .{ .root_source_file = b.path("src/lib.zig") });
    quickjs.addIncludePath(quickjs_dep.path("."));
    quickjs.addCSourceFiles(.{
        .root = quickjs_dep.path("."),
        .files = &.{
            "quickjs.c",
            "libregexp.c",
            "cutils.c",
            "libunicode.c",
            "xsum.c",
        },
    });

    // Tests
    const tests = b.addTest(.{ .root_source_file = b.path("src/test.zig") });
    tests.root_module.addImport("quickjs", quickjs);
    const test_runner = b.addRunArtifact(tests);

    b.step("test", "Run QuickJS tests").dependOn(&test_runner.step);

    // WASM
    const wasm = b.addExecutable(.{
        .name = "quickjs",
        .root_source_file = b.path("./wasm/lib.zig"),
        .target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi }),
        .optimize = optimize,
        .version = .{ .major = 0, .minor = 0, .patch = 1 },
        .link_libc = true,
    });

    wasm.linkLibC();
    wasm.addIncludePath(quickjs_dep.path("."));
    wasm.addCSourceFiles(.{
        .root = quickjs_dep.path("."),
        // .flags = &.{"-DENABLE_DUMPS"},
        .files = &.{
            "quickjs.c",
            "libregexp.c",
            "cutils.c",
            "libunicode.c",
            "xsum.c",
        },
    });

    wasm.addIncludePath(b.path("wasm"));
    wasm.addCSourceFile(.{
        .file = b.path("wasm/foo.c"),
        // .flags = &.{"-DNDEBUG"},
    });

    // wasm.root_module.addImport("quickjs", quickjs);

    wasm.entry = .disabled;
    wasm.rdynamic = true;
    b.installArtifact(wasm);
}
