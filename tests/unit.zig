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

test "parser recognizes HTML void elements case-insensitively and preserves their syntax" {
    const names = .{
        "area",  "base", "br",   "col",   "embed",  "hr",    "img",
        "input", "link", "meta", "param", "source", "track", "wbr",
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    inline for (names, 0..) |name, index| {
        const source = if (index % 2 == 0)
            try std.fmt.allocPrint(allocator, "<{s}>", .{name})
        else
            try std.fmt.allocPrint(allocator, "<{s}/>", .{name});
        const result = try parser.parse(allocator, source);
        const document = switch (result) {
            .success => |value| value,
            .failure => return error.UnexpectedParseFailure,
        };
        const element = document.nodes[0].data.element;
        try std.testing.expect(element.is_void);
        try std.testing.expectEqual(@as(usize, 0), element.children.len);
        try std.testing.expectEqualStrings(source, element.opening_tag);
    }

    const uppercase = try parser.parse(allocator, "<BR/>");
    const uppercase_document = switch (uppercase) {
        .success => |value| value,
        .failure => return error.UnexpectedParseFailure,
    };
    try std.testing.expect(uppercase_document.nodes[0].data.element.is_void);
}

test "parser represents comments and the HTML doctype as static markup" {
    const source = "<!dOcTyPe   hTmL ><!-- {{ literal }} -->";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parser.parse(arena.allocator(), source);
    const document = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedParseFailure,
    };

    try std.testing.expectEqual(@as(usize, 2), document.nodes.len);
    const doctype = document.nodes[0];
    try std.testing.expectEqual(parser.StaticMarkup.Kind.doctype, doctype.data.static_markup.kind);
    try std.testing.expectEqualStrings("<!dOcTyPe   hTmL >", doctype.data.static_markup.serialized);
    try std.testing.expectEqual(@as(zeft.SourceSpan, .{ .start = 0, .end = 18 }), doctype.span);

    const comment = document.nodes[1];
    try std.testing.expectEqual(parser.StaticMarkup.Kind.comment, comment.data.static_markup.kind);
    try std.testing.expectEqualStrings("<!-- {{ literal }} -->", comment.data.static_markup.serialized);
    try std.testing.expectEqual(@as(zeft.SourceSpan, .{ .start = 18, .end = source.len }), comment.span);
}

test "parser rejects unsupported declarations and unterminated comments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const invalid_sources = [_][]const u8{
        "<!DOCTYPE html PUBLIC 'public'>",
        "<?xml version='1.0'?>",
        "<![CDATA[text]]>",
        "<!-- unterminated",
    };
    for (invalid_sources) |source| {
        const result = try parser.parse(allocator, source);
        switch (result) {
            .success => return error.ExpectedDiagnostic,
            .failure => |diagnostic| try std.testing.expectEqual(zeft.CompileErrorKind.invalid_markup, diagnostic.kind),
        }
    }
}

test "XML parsing preserves declarations and CDATA and applies XML element rules" {
    const source = "<?xml version=\"1.0\" encoding='UTF-8' standalone=\"yes\"?><Root Attr=\"value&amp;&#65;&#x1F600;\"><Child/>text<![CDATA[ {{ literal }} & < ]]></Root>";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parser.parseWithFormat(arena.allocator(), source, .xml);
    const document = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedParseFailure,
    };

    try std.testing.expectEqual(@as(usize, 2), document.nodes.len);
    try std.testing.expectEqual(parser.StaticMarkup.Kind.xml_declaration, document.nodes[0].data.static_markup.kind);
    try std.testing.expectEqualStrings("<?xml version=\"1.0\" encoding='UTF-8' standalone=\"yes\"?>", document.nodes[0].data.static_markup.serialized);
    const root = document.nodes[1].data.element;
    try std.testing.expectEqualStrings("Root", root.name);
    try std.testing.expect(!root.is_void and !root.self_closing);
    try std.testing.expectEqualStrings("value&amp;&#65;&#x1F600;", root.attributes[0].value.?.segments[0].data.text);
    try std.testing.expectEqual(@as(usize, 3), root.children.len);
    const child = root.children[0].data.element;
    try std.testing.expectEqualStrings("Child", child.name);
    try std.testing.expect(child.self_closing);
    try std.testing.expectEqual(parser.StaticMarkup.Kind.cdata, root.children[2].data.static_markup.kind);
    try std.testing.expectEqualStrings("<![CDATA[ {{ literal }} & < ]]>", root.children[2].data.static_markup.serialized);
}

test "XML names are case-sensitive and XML attributes require quoted values" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const invalid_sources = [_][]const u8{
        "<Node></node>",
        "<node>unclosed",
        "<node enabled/>",
        "<!DOCTYPE html>",
        "<node><?target data?></node>",
        "<?xml version=\"2.0\"?>",
        "text<?xml version=\"1.0\"?>",
        "<?xml version=\"1.0\" standalone=\"yes\" encoding=\"UTF-8\"?>",
        "<node>bare & ampersand</node>",
        "<node>&unknown;</node>",
        "<node>&#0;</node>",
        "<node>&#xD800;</node>",
        "<node>&#x110000;</node>",
        "<node attr=\"raw < less-than\"/>",
        "<node>bad ]]> sequence</node>",
        "<node><!-- bad -- comment --></node>",
    };
    for (invalid_sources) |source| {
        const result = try parser.parseWithFormat(allocator, source, .xml);
        switch (result) {
            .success => return error.ExpectedDiagnostic,
            .failure => |diagnostic| try std.testing.expectEqual(zeft.CompileErrorKind.invalid_markup, diagnostic.kind),
        }
    }
}

test "XML 1.1 accepts valid control-character references" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parser.parseWithFormat(arena.allocator(), "<?xml version='1.1'?><node>&#1;</node>", .xml);
    switch (result) {
        .failure => return error.UnexpectedParseFailure,
        .success => |document| try std.testing.expectEqual(@as(usize, 2), document.nodes.len),
    }
}

test "parser rejects self-closing non-void elements and void end tags" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const invalid_sources = [_][]const u8{ "<div/>", "</br>", "<p><br></br></p>" };
    for (invalid_sources) |source| {
        const result = try parser.parse(allocator, source);
        switch (result) {
            .success => return error.ExpectedDiagnostic,
            .failure => |diagnostic| try std.testing.expectEqual(zeft.CompileErrorKind.invalid_markup, diagnostic.kind),
        }
    }
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

test "malformed markup diagnostics point to the relevant source token" {
    const DiagnosticCase = struct {
        source: []const u8,
        expected_span: zeft.SourceSpan,
    };
    const cases = [_]DiagnosticCase{
        .{ .source = "</p>", .expected_span = .{ .start = 0, .end = 4 } },
        .{ .source = "<a></b>", .expected_span = .{ .start = 3, .end = 7 } },
        .{ .source = "<a>", .expected_span = .{ .start = 0, .end = 3 } },
        .{ .source = "<a><b>", .expected_span = .{ .start = 3, .end = 6 } },
        .{ .source = "<a attr=>", .expected_span = .{ .start = 0, .end = 9 } },
        .{ .source = "</a", .expected_span = .{ .start = 0, .end = 3 } },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    for (cases) |case| {
        const result = try parser.parse(arena.allocator(), case.source);
        switch (result) {
            .success => return error.ExpectedDiagnostic,
            .failure => |diagnostic| {
                try std.testing.expectEqual(zeft.CompileErrorKind.invalid_markup, diagnostic.kind);
                try std.testing.expectEqual(case.expected_span, diagnostic.span.?);
                try std.testing.expect(diagnostic.span.?.isValid(case.source.len));
            },
        }
    }
}

fn expectNodeSpansValid(nodes: []const parser.Node, source_len: usize) !void {
    for (nodes) |node| {
        try std.testing.expect(node.span.isValid(source_len));
        switch (node.data) {
            .element => |element| try expectNodeSpansValid(element.children, source_len),
            .text, .static_markup, .expression => {},
        }
    }
}
