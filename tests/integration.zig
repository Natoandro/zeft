const std = @import("std");
const zeft = @import("zeft");

test "compile and render the end-to-end HTML text escaping case repeatedly" {
    _ = std.testing.refAllDecls(zeft);
    const result = try zeft.compile(std.testing.allocator, "<p>Hello, {{ name }}!</p>", .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();

    var first_output: [64]u8 = undefined;
    var first_writer = std.Io.Writer.fixed(&first_output);
    const first = try template.render(&first_writer, .{ .name = "<Ada>" });
    try std.testing.expectEqual(zeft.RenderResult.success, first);
    try std.testing.expectEqualStrings("<p>Hello, &lt;Ada&gt;!</p>", std.Io.Writer.buffered(&first_writer));

    var second_output: [64]u8 = undefined;
    var second_writer = std.Io.Writer.fixed(&second_output);
    const second = try template.render(&second_writer, .{ .name = "Grace & Hopper" });
    try std.testing.expectEqual(zeft.RenderResult.success, second);
    try std.testing.expectEqualStrings("<p>Hello, Grace &amp; Hopper!</p>", std.Io.Writer.buffered(&second_writer));
}

test "compile syntax failures are returned before execution" {
    const source = "<p>{{ name";
    const result = try zeft.compile(std.testing.allocator, source, .{});
    switch (result) {
        .success => |value| {
            var template = value;
            template.deinit();
        },
        .failure => |diagnostic| {
            try std.testing.expectEqual(zeft.CompileErrorKind.invalid_expression, diagnostic.kind);
            try std.testing.expectEqual(@as(?zeft.SourceSpan, .{ .start = 3, .end = source.len }), diagnostic.span);
        },
    }
}
