const std = @import("std");
const zeft = @import("zeft");

test "public module is importable" {
    _ = std.testing.refAllDecls(zeft);
}

test "compile options default to HTML with preserved whitespace" {
    const options: zeft.CompileOptions = .{};
    try std.testing.expectEqual(zeft.OutputFormat.html, options.format);
    try std.testing.expectEqual(zeft.WhitespacePolicy.preserve, options.whitespace);
}

test "source spans are half-open and bounded by source length" {
    const span: zeft.SourceSpan = .{ .start = 2, .end = 5 };
    try std.testing.expect(span.isValid(5));
    try std.testing.expect(!span.isValid(4));
    try std.testing.expect((zeft.SourceSpan{ .start = 3, .end = 2 }).isValid(4) == false);
}

test "compiled template releases owned storage" {
    const allocator = std.testing.allocator;
    var template: zeft.CompiledTemplate = .{
        .allocator = allocator,
        .owned_storage = try allocator.dupe(u8, "compiled bytes"),
    };
    template.deinit();
}
