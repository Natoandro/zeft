const std = @import("std");
const zeft = @import("zeft");
const runner = @import("fixture_runner.zig");
const Item = struct { name: []const u8, enabled: bool };
const Group = struct { name: []const u8, items: []const Item };
pub const Context = struct { show: bool = true, inner: bool = true, item: []const u8 = "root", items: []const Item = &.{}, groups: []const Group = &.{} };
const items = [_]Item{ .{ .name = "A", .enabled = true }, .{ .name = "B", .enabled = false }, .{ .name = "C", .enabled = true } };
const groups = [_]Group{ .{ .name = "outer1", .items = &items }, .{ .name = "outer2", .items = &.{} } };
pub const Case = struct { fixture: runner.Success, context: Context };

pub const success_cases = [_]Case{
    .{ .fixture = .{ .id = "F/branch-tt", .path = "fixtures/control-flow/branch-tt.tmpl", .expected_path = "fixtures/control-flow/branch-tt.out", .source = @embedFile("fixtures/control-flow/branch-tt.tmpl"), .expected = @embedFile("fixtures/control-flow/branch-tt.out") }, .context = .{ .show = true, .inner = true } },
    .{ .fixture = .{ .id = "F/branch-tf", .path = "fixtures/control-flow/branch-tf.tmpl", .expected_path = "fixtures/control-flow/branch-tf.out", .source = @embedFile("fixtures/control-flow/branch-tf.tmpl"), .expected = @embedFile("fixtures/control-flow/branch-tf.out") }, .context = .{ .show = true, .inner = false } },
    .{ .fixture = .{ .id = "F/branch-ft", .path = "fixtures/control-flow/branch-ft.tmpl", .expected_path = "fixtures/control-flow/branch-ft.out", .source = @embedFile("fixtures/control-flow/branch-ft.tmpl"), .expected = @embedFile("fixtures/control-flow/branch-ft.out") }, .context = .{ .show = false, .inner = true } },
    .{ .fixture = .{ .id = "F/branch-ff", .path = "fixtures/control-flow/branch-ff.tmpl", .expected_path = "fixtures/control-flow/branch-ff.out", .source = @embedFile("fixtures/control-flow/branch-ff.tmpl"), .expected = @embedFile("fixtures/control-flow/branch-ff.out") }, .context = .{ .show = false, .inner = false } },
    .{ .fixture = .{ .id = "F/loop-empty", .path = "fixtures/control-flow/loop-empty.tmpl", .expected_path = "fixtures/control-flow/loop-empty.out", .source = @embedFile("fixtures/control-flow/loop-empty.tmpl"), .expected = @embedFile("fixtures/control-flow/loop-empty.out") }, .context = .{} },
    .{ .fixture = .{ .id = "F/loop-single", .path = "fixtures/control-flow/loop-single.tmpl", .expected_path = "fixtures/control-flow/loop-single.out", .source = @embedFile("fixtures/control-flow/loop-single.tmpl"), .expected = @embedFile("fixtures/control-flow/loop-single.out") }, .context = .{ .items = items[0..1] } },
    .{ .fixture = .{ .id = "F/loop-multiple", .path = "fixtures/control-flow/loop-multiple.tmpl", .expected_path = "fixtures/control-flow/loop-multiple.out", .source = @embedFile("fixtures/control-flow/loop-multiple.tmpl"), .expected = @embedFile("fixtures/control-flow/loop-multiple.out") }, .context = .{ .items = &items } },
    .{ .fixture = .{ .id = "F/nested-shadow", .path = "fixtures/control-flow/nested-shadow.tmpl", .expected_path = "fixtures/control-flow/nested-shadow.out", .source = @embedFile("fixtures/control-flow/nested-shadow.tmpl"), .expected = @embedFile("fixtures/control-flow/nested-shadow.out") }, .context = .{ .groups = &groups } },
    .{ .fixture = .{ .id = "F/nested-independent", .path = "fixtures/control-flow/nested-independent.tmpl", .expected_path = "fixtures/control-flow/nested-independent.out", .source = @embedFile("fixtures/control-flow/nested-independent.tmpl"), .expected = @embedFile("fixtures/control-flow/nested-independent.out") }, .context = .{ .groups = &groups } },
    .{ .fixture = .{ .id = "F/continue-in-branch", .path = "fixtures/control-flow/continue-in-branch.tmpl", .expected_path = "fixtures/control-flow/continue-in-branch.out", .source = @embedFile("fixtures/control-flow/continue-in-branch.tmpl"), .expected = @embedFile("fixtures/control-flow/continue-in-branch.out") }, .context = .{ .items = &items } },
    .{ .fixture = .{ .id = "F/break-in-branch", .path = "fixtures/control-flow/break-in-branch.tmpl", .expected_path = "fixtures/control-flow/break-in-branch.out", .source = @embedFile("fixtures/control-flow/break-in-branch.tmpl"), .expected = @embedFile("fixtures/control-flow/break-in-branch.out") }, .context = .{ .items = &items } },
    .{ .fixture = .{ .id = "F/nested-break", .path = "fixtures/control-flow/nested-break.tmpl", .expected_path = "fixtures/control-flow/nested-break.out", .source = @embedFile("fixtures/control-flow/nested-break.tmpl"), .expected = @embedFile("fixtures/control-flow/nested-break.out") }, .context = .{ .groups = &groups } },
    .{ .fixture = .{ .id = "F/nested-continue", .path = "fixtures/control-flow/nested-continue.tmpl", .expected_path = "fixtures/control-flow/nested-continue.out", .source = @embedFile("fixtures/control-flow/nested-continue.tmpl"), .expected = @embedFile("fixtures/control-flow/nested-continue.out") }, .context = .{ .groups = &groups } },
    .{ .fixture = .{ .id = "F/branch-loop-skips-error", .path = "fixtures/control-flow/branch-loop-skips-error.tmpl", .expected_path = "fixtures/control-flow/branch-loop-skips-error.out", .source = @embedFile("fixtures/control-flow/branch-loop-skips-error.tmpl"), .expected = @embedFile("fixtures/control-flow/branch-loop-skips-error.out") }, .context = .{ .items = &items } },
    .{ .fixture = .{ .id = "F/empty-loop-skips-error", .path = "fixtures/control-flow/empty-loop-skips-error.tmpl", .expected_path = "fixtures/control-flow/empty-loop-skips-error.out", .source = @embedFile("fixtures/control-flow/empty-loop-skips-error.tmpl"), .expected = @embedFile("fixtures/control-flow/empty-loop-skips-error.out") }, .context = .{} },
    .{ .fixture = .{ .id = "F/local-index", .path = "fixtures/control-flow/local-index.tmpl", .expected_path = "fixtures/control-flow/local-index.out", .source = @embedFile("fixtures/control-flow/local-index.tmpl"), .expected = @embedFile("fixtures/control-flow/local-index.out") }, .context = .{ .groups = &groups } },
};
pub const failure_cases = [_]runner.RenderFailure{
    .{ .id = "F/condition-type", .path = "fixtures/control-flow/condition-type.tmpl", .source = @embedFile("fixtures/control-flow/condition-type.tmpl"), .diagnostic = .{ .kind = .invalid_operand, .span = .{ .start = 6, .end = 10 } } },
    .{ .id = "F/iterable-type", .path = "fixtures/control-flow/iterable-type.tmpl", .source = @embedFile("fixtures/control-flow/iterable-type.tmpl"), .diagnostic = .{ .kind = .non_iterable, .span = .{ .start = 15, .end = 20 } } },
};
pub const harness_ids = [_][]const u8{"F/reuse-failure-recovery"};

test "named control-flow golden cases" {
    for (success_cases) |case| try runner.expectSuccess(case.fixture, &case.context);
    const BadCondition = struct { show: []const u8 };
    try runner.expectRenderFailure(failure_cases[0], &BadCondition{ .show = "wrong" });
    const BadIterable = struct { items: bool };
    try runner.expectRenderFailure(failure_cases[1], &BadIterable{ .items = true });
}

test "control-flow compiled template resets state after success and failure" {
    var template = switch (try zeft.compile(std.testing.allocator, @embedFile("fixtures/control-flow/reuse.tmpl"), .{})) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    var buffer: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectEqual(zeft.RenderResult.success, try template.render(&writer, &Context{ .items = &items }));
    try std.testing.expectEqualStrings(@embedFile("fixtures/control-flow/reuse-full.out"), writer.buffered());
    writer = .fixed(&buffer);
    const BadItem = struct { other: []const u8 };
    const BadContext = struct { items: []const BadItem, item: []const u8 };
    const bad_context = BadContext{ .items = &[_]BadItem{.{ .other = "x" }}, .item = "root" };
    const failed = try template.render(&writer, &bad_context);
    switch (failed) {
        .success => return error.ExpectedRenderFailure,
        .failure => |diagnostic| try std.testing.expectEqualDeep(zeft.RenderDiagnostic{ .kind = .invalid_property_access, .span = .{ .start = 30, .end = 35 } }, diagnostic),
    }
    writer = .fixed(&buffer);
    try std.testing.expectEqual(zeft.RenderResult.success, try template.render(&writer, &Context{}));
    try std.testing.expectEqualStrings(@embedFile("fixtures/control-flow/reuse-empty.out"), writer.buffered());
    writer = .fixed(&buffer);
    try std.testing.expectEqual(zeft.RenderResult.success, try template.render(&writer, &Context{ .items = items[0..1] }));
    try std.testing.expectEqualStrings("A:root", writer.buffered());
}
