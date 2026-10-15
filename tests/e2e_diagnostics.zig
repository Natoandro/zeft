//! Exact compile/render diagnostic fixtures (ZEP-080).
const std = @import("std");
const zeft = @import("zeft");
const fixtures = @import("fixture_runner.zig");

const diagnostic_cases = @import("fixtures/diagnostics.zig");

test "compile diagnostics identify category and exact byte span" {
    try fixtures.expectCompileFailureCases(diagnostic_cases.compile_failure_cases);
}

test "render diagnostics identify category and exact byte span" {
    try fixtures.expectRenderFailureCases(diagnostic_cases.render_failure_cases);
}

test "source identities and line locations are exposed on diagnostics" {
    const identity = "templates/é.page";
    const compile_result = try zeft.compile(
        std.testing.allocator,
        "<p>é\n{{ value }}</p>",
        .{ .source_identity = identity },
    );
    var template = switch (compile_result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    var output: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, .{});
    try std.testing.expect(rendered == .failure);
    try std.testing.expectEqualStrings(identity, rendered.failure.source_identity.?);
    const span = rendered.failure.span.?;
    const location = zeft.sourceLocation("<p>é\n{{ value }}</p>", span.start).?;
    try std.testing.expectEqual(@as(usize, 2), location.line);
    try std.testing.expectEqual(@as(usize, 4), location.column);

    const invalid_result = try zeft.compile(
        std.testing.allocator,
        "{{ value + }}",
        .{ .source_identity = identity },
    );
    switch (invalid_result) {
        .success => |value| {
            var owned = value;
            owned.deinit();
            return error.ExpectedCompileDiagnostic;
        },
        .failure => |diagnostic| try std.testing.expectEqualStrings(
            identity,
            diagnostic.source_identity.?,
        ),
    }
}
