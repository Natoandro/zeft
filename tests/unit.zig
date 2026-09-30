const std = @import("std");
const zeft = @import("zeft");
const parser = @import("zeft_parser");
const expression = @import("zeft_expression");
const analysis = @import("zeft_analysis");
const ir = @import("zeft_ir");
const lower = @import("zeft_lower");

test "public module is importable" {
    _ = std.testing.refAllDecls(zeft);
    _ = std.testing.refAllDecls(expression);
    _ = std.testing.refAllDecls(analysis);
    _ = std.testing.refAllDecls(ir);
    _ = std.testing.refAllDecls(lower);
}

test "compile options default to HTML with preserved whitespace" {
    const options: zeft.CompileOptions = .{};
    try std.testing.expectEqual(zeft.OutputFormat.html, options.format);
    try std.testing.expectEqual(zeft.WhitespacePolicy.preserve, options.whitespace);
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

test "parser represents boolean and quoted attributes with source spans" {
    const source = "<button disabled data-kind='primary' title=\"{{ value }}\"></button>";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parser.parse(arena.allocator(), source);
    const document = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedParseFailure,
    };

    const element = document.nodes[0].data.element;
    try std.testing.expectEqual(@as(usize, 3), element.attributes.len);
    try std.testing.expectEqualStrings("disabled", element.attributes[0].name);
    try std.testing.expect(element.attributes[0].value == null);

    const single_quoted = element.attributes[1].value.?;
    try std.testing.expectEqual(parser.QuoteStyle.single, single_quoted.quote_style);
    try std.testing.expectEqual(@as(usize, 1), single_quoted.segments.len);
    try std.testing.expectEqualStrings("primary", single_quoted.segments[0].data.text);

    const double_quoted = element.attributes[2].value.?;
    try std.testing.expectEqual(parser.QuoteStyle.double, double_quoted.quote_style);
    try std.testing.expectEqual(@as(usize, 1), double_quoted.segments.len);
    try std.testing.expectEqualStrings("value", source[double_quoted.segments[0].data.expression.start..double_quoted.segments[0].data.expression.end]);
    try std.testing.expectEqualStrings("<button disabled data-kind='primary' title=\"{{ value }}\">", element.opening_tag);
    try std.testing.expect(element.attributes[0].span.isValid(source.len));
    try std.testing.expect(double_quoted.span.isValid(source.len));
    try std.testing.expect(double_quoted.segments[0].span.isValid(source.len));
}

test "attribute values preserve static and interpolated segments in source order" {
    const source = "<a title='before {{ first }} middle {{ second }} after'></a>";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const parsed = try parser.parse(arena.allocator(), source);
    const document = switch (parsed) {
        .success => |value| value,
        .failure => return error.UnexpectedParseFailure,
    };
    const segments = document.nodes[0].data.element.attributes[0].value.?.segments;
    try std.testing.expectEqual(@as(usize, 5), segments.len);
    try std.testing.expectEqualStrings("before ", segments[0].data.text);
    try std.testing.expectEqualStrings("first", source[segments[1].data.expression.start..segments[1].data.expression.end]);
    try std.testing.expectEqualStrings(" middle ", segments[2].data.text);
    try std.testing.expectEqualStrings("second", source[segments[3].data.expression.start..segments[3].data.expression.end]);
    try std.testing.expectEqualStrings(" after", segments[4].data.text);
}

test "parser rejects unquoted attribute values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parser.parse(arena.allocator(), "<input type=text></input>");
    switch (result) {
        .success => return error.ExpectedDiagnostic,
        .failure => |diagnostic| try std.testing.expectEqual(zeft.CompileErrorKind.invalid_markup, diagnostic.kind),
    }
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
