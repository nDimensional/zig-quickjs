const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

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

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("src/test.zig"),
        }),
    });

    tests.root_module.addImport("quickjs", quickjs);
    tests.linkLibC();

    const test_runner = b.addRunArtifact(tests);

    b.step("test", "Run QuickJS tests").dependOn(&test_runner.step);
}
