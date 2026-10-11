//! Byte-exact public API markup fixtures (ZEP-076).
const fixtures = @import("fixture_runner.zig");
const markup_cases = @import("fixtures/markup.zig");

test "markup fixtures preserve exact output and escape dynamic values" {
    for (markup_cases.success_cases) |case| try fixtures.expectSuccess(case.fixture, &case.params);
}

test "markup fixtures reject invalid source with precise diagnostics" {
    for (markup_cases.compile_failure_cases) |case| try fixtures.expectCompileFailure(case);
}
