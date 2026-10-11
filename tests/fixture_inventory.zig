//! Cross-suite fixture registration checks.
const fixtures = @import("fixture_runner.zig");
const cache = @import("fixtures/cache.zig");
const control_flow = @import("fixtures/control_flow.zig");
const diagnostics = @import("fixtures/diagnostics.zig");
const expressions = @import("fixtures/expressions.zig");
const legacy = @import("fixtures/legacy.zig");
const lifecycle = @import("fixtures/lifecycle.zig");
const markup = @import("fixtures/markup.zig");
const whitespace = @import("fixtures/whitespace.zig");

test "fixture execution IDs are unique across suites" {
    try fixtures.expectUniqueIds(.{
        cache.harness_ids,
        control_flow.success_cases,
        control_flow.failure_cases,
        control_flow.harness_ids,
        diagnostics.compile_failure_cases,
        diagnostics.render_failure_cases,
        expressions.success_cases,
        legacy.ids,
        lifecycle.harness_ids,
        markup.success_cases,
        markup.compile_failure_cases,
        whitespace.success_cases,
    });
}
