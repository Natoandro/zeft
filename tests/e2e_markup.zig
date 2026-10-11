//! Byte-exact public API markup fixtures (ZEP-076).
const fixtures = @import("fixture_runner.zig");
const markup_cases = @import("fixtures/markup.zig");

test "markup fixtures preserve exact output and escape dynamic values" {
    try fixtures.expectSuccessCases(markup_cases.success_cases);
}

test "markup fixtures reject invalid source with precise diagnostics" {
    try fixtures.expectCompileFailureCases(markup_cases.compile_failure_cases);
}
