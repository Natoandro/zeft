const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zeft = b.addModule("zeft", .{
        .root_source_file = b.path("src/zeft.zig"),
        .target = target,
        .optimize = optimize,
    });

    const library = b.addLibrary(.{
        .name = "zeft",
        .root_module = zeft,
        .linkage = .static,
    });
    b.installArtifact(library);

    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/unit.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zeft", .module = zeft }},
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const integration_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/integration.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "zeft", .module = zeft }},
        }),
    });
    const run_integration_tests = b.addRunArtifact(integration_tests);

    const test_step = b.step("test", "Run unit and integration tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_integration_tests.step);
}
