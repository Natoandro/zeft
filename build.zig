const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const core = b.addModule("zeft_core", .{
        .root_source_file = b.path("src/core.zig"),
        .target = target,
        .optimize = optimize,
    });

    const parser = b.addModule("zeft_parser", .{
        .root_source_file = b.path("src/compiler/parser.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zeft_core", .module = core }},
    });

    const expression = b.addModule("zeft_expression", .{
        .root_source_file = b.path("src/compiler/expression.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zeft_core", .module = core }},
    });

    const analysis = b.addModule("zeft_analysis", .{
        .root_source_file = b.path("src/compiler/analysis.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zeft_core", .module = core },
            .{ .name = "zeft_parser", .module = parser },
            .{ .name = "zeft_expression", .module = expression },
        },
    });

    const ir = b.addModule("zeft_ir", .{
        .root_source_file = b.path("src/compiler/ir.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zeft_core", .module = core },
            .{ .name = "zeft_analysis", .module = analysis },
        },
    });

    const lower = b.addModule("zeft_lower", .{
        .root_source_file = b.path("src/compiler/lower.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zeft_core", .module = core },
            .{ .name = "zeft_parser", .module = parser },
            .{ .name = "zeft_analysis", .module = analysis },
            .{ .name = "zeft_ir", .module = ir },
        },
    });

    const optimize_module = b.addModule("zeft_optimize", .{
        .root_source_file = b.path("src/compiler/optimize.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zeft_core", .module = core },
            .{ .name = "zeft_ir", .module = ir },
        },
    });

    const zeft = b.addModule("zeft", .{
        .root_source_file = b.path("src/zeft.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "zeft_core", .module = core },
            .{ .name = "zeft_parser", .module = parser },
            .{ .name = "zeft_analysis", .module = analysis },
            .{ .name = "zeft_lower", .module = lower },
            .{ .name = "zeft_ir", .module = ir },
            .{ .name = "zeft_optimize", .module = optimize_module },
        },
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
            .imports = &.{
                .{ .name = "zeft", .module = zeft },
                .{ .name = "zeft_core", .module = core },
                .{ .name = "zeft_parser", .module = parser },
                .{ .name = "zeft_expression", .module = expression },
                .{ .name = "zeft_analysis", .module = analysis },
                .{ .name = "zeft_ir", .module = ir },
                .{ .name = "zeft_lower", .module = lower },
                .{ .name = "zeft_optimize", .module = optimize_module },
            },
        }),
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const compiler_test_modules = [_]*std.Build.Module{ core, parser, expression, analysis, lower, optimize_module, zeft };
    var compiler_test_runs: [compiler_test_modules.len]*std.Build.Step.Run = undefined;
    for (compiler_test_modules, 0..) |module, index| {
        const module_tests = b.addTest(.{ .root_module = module });
        compiler_test_runs[index] = b.addRunArtifact(module_tests);
    }

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
    for (compiler_test_runs) |run| test_step.dependOn(&run.step);
    test_step.dependOn(&run_integration_tests.step);
}
