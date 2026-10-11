//! Exact compile/render diagnostic fixtures (ZEP-080).
const fixtures = @import("fixture_runner.zig");

const diagnostic_cases = @import("fixtures/diagnostics.zig");

test "compile diagnostics identify category and exact byte span" {
    try fixtures.expectCompileFailureCases(diagnostic_cases.compile_failure_cases);
}

test "render diagnostics identify category and exact byte span" {
    try fixtures.expectRenderFailureCases(diagnostic_cases.render_failure_cases);
}
