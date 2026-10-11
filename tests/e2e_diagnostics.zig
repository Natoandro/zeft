//! Exact compile/render diagnostic fixtures (ZEP-080).
const std = @import("std");
const zeft = @import("zeft");
const fixtures = @import("fixture_runner.zig");

const diagnostic_cases = @import("fixtures/diagnostics.zig");

test "compile diagnostics identify category and exact byte span" {
    var failures: usize = 0;
    for (diagnostic_cases.compile_failure_cases) |case| {
        fixtures.expectCompileFailure(case) catch {
            failures += 1;
        };
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

test "render diagnostics identify category and exact byte span" {
    var failures: usize = 0;
    for (diagnostic_cases.render_failure_cases) |case| {
        fixtures.expectRenderFailure(case.fixture, &case.params) catch {
            failures += 1;
        };
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}
