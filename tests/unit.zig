const std = @import("std");
const zeft = @import("zeft");
const parser = @import("zeft_parser");

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

test "lexer tracks raw spans and decodes text delimiter escapes" {
    const source = "a\\{{b}}\\\\{{ name }}";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parser.lex(arena.allocator(), source);
    const tokens = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedLexFailure,
    };

    try std.testing.expectEqual(@as(usize, 2), tokens.len);
    try std.testing.expectEqualStrings("a{{b}}\\", tokens[0].data.text);
    try std.testing.expectEqual(@as(zeft.SourceSpan, .{ .start = 0, .end = 9 }), tokens[0].span);
    try std.testing.expectEqual(@as(zeft.SourceSpan, .{ .start = 9, .end = source.len }), tokens[1].span);
    try std.testing.expectEqualStrings("name", source[tokens[1].data.expression.start..tokens[1].data.expression.end]);
}

test "parser builds nested elements with text and interpolation spans" {
    const source = "<p>Hello, {{ name }}!<b>ok</b></p>";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parser.parse(arena.allocator(), source);
    const document = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedParseFailure,
    };

    try std.testing.expectEqual(@as(usize, 1), document.nodes.len);
    const paragraph = document.nodes[0];
    try std.testing.expectEqual(@as(zeft.SourceSpan, .{ .start = 0, .end = source.len }), paragraph.span);
    const p = paragraph.data.element;
    try std.testing.expectEqualStrings("p", p.name);
    try std.testing.expectEqual(@as(usize, 4), p.children.len);
    try std.testing.expectEqualStrings("Hello, ", p.children[0].data.text);
    try std.testing.expectEqualStrings("name", source[p.children[1].data.expression.source_span.start..p.children[1].data.expression.source_span.end]);
    try std.testing.expectEqualStrings("!", p.children[2].data.text);
    try std.testing.expectEqualStrings("b", p.children[3].data.element.name);
    try std.testing.expectEqual(
        @as(zeft.SourceSpan, .{ .start = 21, .end = 30 }),
        p.children[3].span,
    );
    try expectNodeSpansValid(document.nodes, source.len);
}

test "closing interpolation delimiter outside an expression remains text" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parser.lex(arena.allocator(), "left }} right {{name}}");
    const tokens = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedLexFailure,
    };

    try std.testing.expectEqual(@as(usize, 2), tokens.len);
    try std.testing.expectEqualStrings("left }} right ", tokens[0].data.text);
}

test "parser rejects malformed delimiters and unbalanced elements with spans" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const bad_expression = try parser.parse(allocator, "{{ name");
    switch (bad_expression) {
        .success => return error.ExpectedDiagnostic,
        .failure => |diagnostic| {
            try std.testing.expectEqual(zeft.CompileErrorKind.invalid_expression, diagnostic.kind);
            try std.testing.expectEqual(@as(?zeft.SourceSpan, .{ .start = 0, .end = 7 }), diagnostic.span);
        },
    }

    const bad_nesting = try parser.parse(allocator, "<p><b></p></b>");
    switch (bad_nesting) {
        .success => return error.ExpectedDiagnostic,
        .failure => |diagnostic| {
            try std.testing.expectEqual(zeft.CompileErrorKind.invalid_markup, diagnostic.kind);
            try std.testing.expectEqual(@as(?zeft.SourceSpan, .{ .start = 6, .end = 10 }), diagnostic.span);
        },
    }
}

fn expectNodeSpansValid(nodes: []const parser.Node, source_len: usize) !void {
    for (nodes) |node| {
        try std.testing.expect(node.span.isValid(source_len));
        switch (node.data) {
            .element => |element| try expectNodeSpansValid(element.children, source_len),
            .text, .expression => {},
        }
    }
}
