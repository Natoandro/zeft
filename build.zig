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

    const runtime = b.addModule("zeft_runtime", .{
        .root_source_file = b.path("src/runtime.zig"),
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
            .{ .name = "zeft_runtime", .module = runtime },
        },
    });

    const library = b.addLibrary(.{
        .name = "zeft",
        .root_module = zeft,
        .linkage = .static,
    });
    b.installArtifact(library);

    const python_include = b.option([]const u8, "python-include", "CPython include directory");
    const python_library_dir = b.option(
        []const u8,
        "python-library-dir",
        "CPython library directory",
    );
    const python_library = b.option(
        []const u8,
        "python-library",
        "CPython import library name",
    );
    if (python_include) |include_dir| {
        const python_module = b.createModule(.{
            .root_source_file = b.path("bindings/python/native/module.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .imports = &.{.{ .name = "zeft", .module = zeft }},
        });
        if (python_library_dir) |library_dir| {
            python_module.addLibraryPath(.{ .cwd_relative = library_dir });
        }
        if (python_library) |python_lib| {
            python_module.linkSystemLibrary(python_lib, .{});
        }
        const python_include_parent = std.fs.path.dirname(include_dir) orelse include_dir;
        python_module.addCSourceFile(.{
            .file = b.path("bindings/python/native/module.c"),
            .flags = &.{
                "-std=c11",
                b.fmt("-DZEFT_ZIG_BUILD_MODE=\"{s}\"", .{@tagName(optimize)}),
                b.fmt("-I{s}", .{include_dir}),
                b.fmt("-I{s}", .{python_include_parent}),
            },
        });
        const extension = b.addLibrary(.{
            .name = "_native",
            .root_module = python_module,
            .linkage = .dynamic,
        });
        extension.linker_allow_shlib_undefined = target.result.os.tag == .macos;
        b.installArtifact(extension);
    }
    const python_extension_step = b.step(
        "python-extension",
        "Build the CPython extension (pass -Dpython-include from Python sysconfig)",
    );
    if (python_include) |include_dir| {
        _ = include_dir;
        python_extension_step.dependOn(b.getInstallStep());
    } else {
        const missing_include = b.addFail(
            "python-extension requires -Dpython-include=<CPython include directory>",
        );
        python_extension_step.dependOn(&missing_include.step);
    }

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

    const compiler_test_modules = [_]*std.Build.Module{
        core,
        parser,
        expression,
        analysis,
        lower,
        optimize_module,
        runtime,
        zeft,
    };
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

    const bench_module = b.createModule(.{
        .root_source_file = b.path("bench/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
        .imports = &.{.{ .name = "zeft", .module = zeft }},
    });
    const bench = b.addExecutable(.{ .name = "zeft-bench", .root_module = bench_module });
    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run reproducible compiler and renderer benchmarks");
    bench_step.dependOn(&run_bench.step);
}
