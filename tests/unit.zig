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

test "parser preserves nested mixed markup, quoted attributes, and exact source spans" {
    const source = "<Main id='root'><Child title=\"before {{ name }} after\">left<Inner></Inner>right</Child></Main>";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parser.parse(arena.allocator(), source);
    const document = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedParseFailure,
    };

    const main = document.nodes[0];
    try std.testing.expectEqual(zeft.SourceSpan{ .start = 0, .end = source.len }, main.span);
    const main_element = main.data.element;
    try std.testing.expectEqualStrings("<Main id='root'>", main_element.opening_tag);
    try std.testing.expectEqualStrings("</Main>", main_element.closing_tag);
    try std.testing.expectEqual(@as(usize, 1), main_element.attributes.len);
    try std.testing.expectEqualStrings("id", main_element.attributes[0].name);
    try std.testing.expectEqual(zeft.SourceSpan{
        .start = std.mem.indexOf(u8, source, "id='").?,
        .end = std.mem.indexOf(u8, source, "id='root'").? + "id='root'".len,
    }, main_element.attributes[0].span);
    try std.testing.expectEqual(parser.QuoteStyle.single, main_element.attributes[0].value.?.quote_style);

    const child = main_element.children[0];
    const child_element = child.data.element;
    try std.testing.expectEqualStrings("<Child title=\"before {{ name }} after\">", child_element.opening_tag);
    try std.testing.expectEqualStrings("</Child>", child_element.closing_tag);
    try std.testing.expectEqual(@as(usize, 3), child_element.children.len);
    const value = child_element.attributes[0].value.?;
    try std.testing.expectEqual(parser.QuoteStyle.double, value.quote_style);
    try std.testing.expectEqualStrings("before ", value.segments[0].data.text);
    try std.testing.expectEqualStrings("name", source[value.segments[1].data.expression.start..value.segments[1].data.expression.end]);
    try std.testing.expectEqualStrings(" after", value.segments[2].data.text);
    try std.testing.expectEqualStrings("left", child_element.children[0].data.text);
    try std.testing.expectEqualStrings("Inner", child_element.children[1].data.element.name);
    try std.testing.expectEqualStrings("right", child_element.children[2].data.text);
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
            .conditional => |conditional| {
                try std.testing.expect(conditional.condition.isValid(source_len));
                try expectNodeSpansValid(conditional.then_nodes, source_len);
                try expectNodeSpansValid(conditional.else_nodes, source_len);
            },
            .loop => |loop| {
                try std.testing.expect(loop.name_span.isValid(source_len));
                try std.testing.expect(loop.expression.isValid(source_len));
                try expectNodeSpansValid(loop.children, source_len);
            },
            .text, .static_markup, .expression, .break_, .continue_, .include => {},
        }
    }
}

test "template cache reuses entries and keys source and compile options" {
    var cache = zeft.TemplateCache.init(std.testing.allocator);
    defer cache.deinit();
    var first = switch (try cache.getOrCompile("view", "<p>A</p>", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer first.deinit();
    var hit = switch (try cache.getOrCompile("view", "<p>A</p>", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer hit.deinit();
    try std.testing.expect(first.entry == hit.entry);
    var changed_source = switch (try cache.getOrCompile("view", "<p>B</p>", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer changed_source.deinit();
    try std.testing.expect(first.entry != changed_source.entry);
    var changed_options = switch (try cache.getOrCompile("view", "<p>B</p>", .{ .whitespace = .compact })) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer changed_options.deinit();
    try std.testing.expect(changed_source.entry != changed_options.entry);
    var changed_format = switch (try cache.getOrCompile("view", "<p>B</p>", .{ .format = .xml })) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer changed_format.deinit();
    var changed_indentation = switch (try cache.getOrCompile("view", "<p>B</p>", .{ .whitespace = .pretty, .indentation = "...." })) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer changed_indentation.deinit();
    try std.testing.expect(changed_source.entry != changed_format.entry);
    try std.testing.expect(changed_source.entry != changed_indentation.entry);
}

test "failed cache reload preserves the previous valid template" {
    var cache = zeft.TemplateCache.init(std.testing.allocator);
    defer cache.deinit();
    var valid = switch (try cache.getOrCompile("view", "ready", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer valid.deinit();
    switch (try cache.getOrCompile("view", "{{ broken", .{})) {
        .success => return error.ExpectedCompileFailure,
        .failure => {},
    }
    var bytes: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&bytes);
    try std.testing.expectEqual(zeft.RenderResult.success, try cache.render(std.testing.allocator, "view", &writer, .{}));
    try std.testing.expectEqualStrings("ready", std.Io.Writer.buffered(&writer));
}

test "a replaced cache entry stays alive through its active lease" {
    var cache = zeft.TemplateCache.init(std.testing.allocator);
    defer cache.deinit();
    var old = switch (try cache.getOrCompile("view", "old", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer old.deinit();
    var replacement = switch (try cache.getOrCompile("view", "new", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer replacement.deinit();
    var bytes: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&bytes);
    try std.testing.expectEqual(zeft.RenderResult.success, try old.render(&writer, .{}));
    try std.testing.expectEqualStrings("old", std.Io.Writer.buffered(&writer));
    writer = std.Io.Writer.fixed(&bytes);
    try std.testing.expectEqual(zeft.RenderResult.success, try replacement.render(&writer, .{}));
    try std.testing.expectEqualStrings("new", std.Io.Writer.buffered(&writer));
    cache.evict("view");
    writer = std.Io.Writer.fixed(&bytes);
    try std.testing.expectEqual(zeft.RenderResult.success, try replacement.render(&writer, .{}));
    try std.testing.expectEqualStrings("new", std.Io.Writer.buffered(&writer));
    writer = std.Io.Writer.fixed(&bytes);
    const evicted = try cache.render(std.testing.allocator, "view", &writer, .{});
    try std.testing.expectEqual(zeft.RenderErrorKind.missing_template, evicted.failure.kind);
}

test "cache renders independently compiled includes and reports include errors" {
    var cache = zeft.TemplateCache.init(std.testing.allocator);
    defer cache.deinit();
    var root = switch (try cache.getOrCompile("root", "A{% include \"child\" %}Z", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer root.deinit();
    var child = switch (try cache.getOrCompile("child", "one", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer child.deinit();
    var bytes: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&bytes);
    try std.testing.expectEqual(zeft.RenderResult.success, try cache.render(std.testing.allocator, "root", &writer, .{}));
    try std.testing.expectEqualStrings("AoneZ", std.Io.Writer.buffered(&writer));
    var replacement = switch (try cache.getOrCompile("child", "two", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer replacement.deinit();
    writer = std.Io.Writer.fixed(&bytes);
    try std.testing.expectEqual(zeft.RenderResult.success, try cache.render(std.testing.allocator, "root", &writer, .{}));
    try std.testing.expectEqualStrings("AtwoZ", std.Io.Writer.buffered(&writer));
    writer = std.Io.Writer.fixed(&bytes);
    const missing = try cache.render(std.testing.allocator, "absent", &writer, .{});
    try std.testing.expectEqual(zeft.RenderErrorKind.missing_template, missing.failure.kind);
}

test "include cycles return a runtime diagnostic with the include span" {
    var cache = zeft.TemplateCache.init(std.testing.allocator);
    defer cache.deinit();
    var a = switch (try cache.getOrCompile("a", "{% include \"b\" %}", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer a.deinit();
    var b = switch (try cache.getOrCompile("b", "{% include \"a\" %}", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer b.deinit();
    var bytes: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&bytes);
    const result = try cache.render(std.testing.allocator, "a", &writer, .{});
    try std.testing.expectEqual(zeft.RenderErrorKind.include_cycle, result.failure.kind);
    try std.testing.expectEqualStrings("a", result.failure.include_identity.?);
    try std.testing.expectEqualStrings("b", result.failure.include_parent_identity.?);
    try std.testing.expectEqual(@as(usize, 0), result.failure.span.?.start);
}

test "missing and invalid included templates identify the dependency edge" {
    var cache = zeft.TemplateCache.init(std.testing.allocator);
    defer cache.deinit();
    var missing_parent = switch (try cache.getOrCompile("missing-parent", "{% include \"not-loaded\" %}", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer missing_parent.deinit();
    var invalid_parent = switch (try cache.getOrCompile("invalid-parent", "{% include \"bad-child\" %}", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer invalid_parent.deinit();
    switch (try cache.getOrCompile("bad-child", "{{ unclosed", .{})) {
        .success => return error.ExpectedCompileFailure,
        .failure => {},
    }
    var bytes: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&bytes);
    const missing = try cache.render(std.testing.allocator, "missing-parent", &writer, .{});
    try std.testing.expectEqual(zeft.RenderErrorKind.missing_include, missing.failure.kind);
    try std.testing.expectEqualStrings("not-loaded", missing.failure.include_identity.?);
    try std.testing.expectEqual(@as(usize, 0), missing.failure.span.?.start);
    writer = std.Io.Writer.fixed(&bytes);
    const invalid = try cache.render(std.testing.allocator, "invalid-parent", &writer, .{});
    try std.testing.expectEqual(zeft.RenderErrorKind.include_compile_failure, invalid.failure.kind);
    try std.testing.expectEqualStrings("bad-child", invalid.failure.include_identity.?);
    try std.testing.expectEqualStrings("invalid-parent", invalid.failure.include_parent_identity.?);
    try std.testing.expectEqual(@as(usize, 0), invalid.failure.span.?.start);
    try std.testing.expectEqual(zeft.CompileErrorKind.invalid_expression, invalid.failure.include_compile_diagnostic.?.kind);
    try std.testing.expect(invalid.failure.include_compile_diagnostic.?.span != null);
}

test "cache include diagnostics survive entry eviction" {
    var cache = zeft.TemplateCache.init(std.testing.allocator);
    defer cache.deinit();
    var root = switch (try cache.getOrCompile("root", "{% include \"absent\" %}", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    root.deinit();

    var bytes: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&bytes);
    const result = try cache.render(std.testing.allocator, "root", &writer, .{});
    try std.testing.expectEqual(zeft.RenderErrorKind.missing_include, result.failure.kind);
    cache.evict("root");
    try std.testing.expectEqualStrings("absent", result.failure.include_identity.?);
    try std.testing.expectEqualStrings("root", result.failure.include_parent_identity.?);
}

test "template cache supports concurrent lookup and rendering" {
    var cache = zeft.TemplateCache.init(std.heap.page_allocator);
    defer cache.deinit();
    var initial = switch (try cache.getOrCompile("shared", "cached", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer initial.deinit();
    var workers = [_]CacheWorker{ .{ .cache = &cache }, .{ .cache = &cache }, .{ .cache = &cache }, .{ .cache = &cache } };
    var threads: [workers.len]std.Thread = undefined;
    for (&workers, 0..) |*worker, index| threads[index] = try std.Thread.spawn(.{}, cacheWorker, .{worker});
    for (threads) |thread| thread.join();
    for (workers) |worker| try std.testing.expect(!worker.failed);
}

test "replacement keeps a template alive during an active render" {
    var cache = zeft.TemplateCache.init(std.heap.page_allocator);
    defer cache.deinit();
    var original = switch (try cache.getOrCompile("active", "{{ hold() }}", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer original.deinit();
    var state = ActiveRenderState{};
    var render = ActiveCacheRender{ .cache = &cache, .state = &state };
    const thread = try std.Thread.spawn(.{}, renderWhileHeld, .{&render});
    while (!state.entered.load(.acquire)) std.atomic.spinLoopHint();
    var replacement = switch (try cache.getOrCompile("active", "new", .{})) {
        .success => |lease| lease,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer replacement.deinit();
    state.proceed.store(true, .release);
    thread.join();
    try std.testing.expect(!render.failed);
    try std.testing.expectEqualStrings("active", render.output[0..render.output_len]);
}

test "cache get-or-compile cleans partial allocations on allocation failure" {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, exerciseCacheAllocations, .{});
}

fn exerciseCacheAllocations(allocator: std.mem.Allocator) !void {
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    var lease = switch (try cache.getOrCompile("allocation", "<p>{{ value }}</p>", .{})) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer lease.deinit();
}

const CacheWorker = struct { cache: *zeft.TemplateCache, failed: bool = false };

fn cacheWorker(worker: *CacheWorker) void {
    for (0..25) |_| {
        const lease = worker.cache.getOrCompile("shared", "cached", .{}) catch {
            worker.failed = true;
            return;
        };
        var template = switch (lease) {
            .success => |value| value,
            .failure => {
                worker.failed = true;
                return;
            },
        };
        var bytes: [16]u8 = undefined;
        var writer = std.Io.Writer.fixed(&bytes);
        const result = template.render(&writer, .{}) catch {
            worker.failed = true;
            template.deinit();
            return;
        };
        if (result != .success or !std.mem.eql(u8, std.Io.Writer.buffered(&writer), "cached")) worker.failed = true;
        template.deinit();
        if (worker.failed) return;
    }
}

const ActiveRenderState = struct {
    entered: std.atomic.Value(bool) = .init(false),
    proceed: std.atomic.Value(bool) = .init(false),
};

const ActiveCacheRender = struct {
    cache: *zeft.TemplateCache,
    state: *ActiveRenderState,
    output: [32]u8 = undefined,
    output_len: usize = 0,
    failed: bool = false,
};

fn renderWhileHeld(render: *ActiveCacheRender) void {
    var writer = std.Io.Writer.fixed(&render.output);
    const functions = [_]zeft.Registration{.{ .name = "hold", .callback = holdRenderCallback, .user_data = render.state }};
    const options: zeft.RenderOptions = .{ .allocator = std.heap.page_allocator, .functions = &functions };
    const result = render.cache.renderWithOptions(std.heap.page_allocator, "active", &writer, .{}, options) catch {
        render.failed = true;
        return;
    };
    if (result != .success) {
        render.failed = true;
        return;
    }
    render.output_len = std.Io.Writer.buffered(&writer).len;
}

fn holdRenderCallback(_: std.mem.Allocator, raw: ?*const anyopaque, _: []const zeft.Value) anyerror!zeft.Value {
    const state: *ActiveRenderState = @ptrCast(@alignCast(@constCast(raw.?)));
    state.entered.store(true, .release);
    while (!state.proceed.load(.acquire)) std.atomic.spinLoopHint();
    return .{ .string = "active" };
}
