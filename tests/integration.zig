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

test "static attributes are preserved exactly during compilation and rendering" {
    const source = "<button disabled checked=\"false\" data-kind='primary' title=\"hello\"></button>";
    const result = try zeft.compile(std.testing.allocator, source, .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();

    var output: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, .{});
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings(source, std.Io.Writer.buffered(&writer));
}

test "HTML void elements preserve their opening spelling without closing tags" {
    const source = "<p>before<BR/>middle<br>after<img src='image.png'></p>";
    const result = try zeft.compile(std.testing.allocator, source, .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();

    var output: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, .{});
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings(source, std.Io.Writer.buffered(&writer));
}

test "HTML comments and doctype serialize verbatim without comment interpolation" {
    const source = "<!DOCTYPE html><p>before<!-- {{ ignored }} -->{{ name }}</p>";
    const result = try zeft.compile(std.testing.allocator, source, .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();

    var output: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, .{ .name = "Ada" });
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings("<!DOCTYPE html><p>before<!-- {{ ignored }} -->Ada</p>", std.Io.Writer.buffered(&writer));
}

test "XML text and attributes use XML-specific escaping" {
    const source = "<?xml version='1.0'?><node value=\"{{ value }}\"><child /><![CDATA[ {{ literal }} & < ]]>{{ value }}</node>";
    const result = try zeft.compile(std.testing.allocator, source, .{ .format = .xml });
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();

    var output: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, .{ .value = "&<>\"'" });
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings("<?xml version='1.0'?><node value=\"&amp;&lt;&gt;&quot;&apos;\"><child /><![CDATA[ {{ literal }} & < ]]>&amp;&lt;&gt;\"'</node>", std.Io.Writer.buffered(&writer));
}

test "HTML and XML markup is serialized before runtime execution" {
    const cases = .{
        .{ .format = zeft.OutputFormat.html, .source = "<Main id='x'>before<Child title=\"static\">middle</cHiLd>after</MAIN>" },
        .{ .format = zeft.OutputFormat.xml, .source = "<?xml version='1.0'?><Root attr=\"a&amp;b\"><Child />text<![CDATA[x<y]]></Root>" },
    };
    inline for (cases) |case| {
        const result = try zeft.compile(std.testing.allocator, case.source, .{ .format = case.format });
        var template = switch (result) {
            .success => |value| value,
            .failure => return error.UnexpectedCompileFailure,
        };
        defer template.deinit();

        var output: [256]u8 = undefined;
        var writer = std.Io.Writer.fixed(&output);
        const rendered = try template.render(&writer, .{});
        try std.testing.expectEqual(zeft.RenderResult.success, rendered);
        try std.testing.expectEqualStrings(case.source, std.Io.Writer.buffered(&writer));
    }
}

test "invalid HTML self-closing syntax and void end tags fail during compilation" {
    const invalid_sources = [_][]const u8{ "<div/>", "</br>", "<p><br></br></p>" };
    for (invalid_sources) |source| {
        const result = try zeft.compile(std.testing.allocator, source, .{});
        switch (result) {
            .success => |value| {
                var template = value;
                template.deinit();
                return error.ExpectedDiagnostic;
            },
            .failure => |diagnostic| try std.testing.expectEqual(zeft.CompileErrorKind.invalid_markup, diagnostic.kind),
        }
    }
}

test "attribute interpolations retain their context and render in source order" {
    const source = "<a title='{{ first }} & {{ second }}'>{{ first }}</a>";
    const result = try zeft.compile(std.testing.allocator, source, .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();

    var output: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, .{ .first = "A&B\"'", .second = "<C>" });
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings("<a title='A&amp;B&quot;&#39; & &lt;C&gt;'>A&amp;B\"'</a>", std.Io.Writer.buffered(&writer));
}

test "property and literal array-index expressions traverse native context values" {
    const Person = struct { name: []const u8 };
    const Profile = struct { label: []const u8 };
    const Context = struct {
        people: [2]Person,
        profile: Profile,
        aliases: []const []const u8,
    };
    const label = try std.testing.allocator.dupe(u8, "Engineer <");
    defer std.testing.allocator.free(label);
    var context: Context = undefined;
    context = .{
        .people = [_]Person{ .{ .name = "Ada" }, .{ .name = "Grace & Hopper" } },
        .profile = .{ .label = label },
        .aliases = &.{ "first", "second" },
    };
    const source = "<p data-name=\"{{ people[0].name }}\">{{ people[1].name }} | {{ profile.label }} | {{ aliases[0] }}</p>";
    const result = try zeft.compile(std.testing.allocator, source, .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();

    var output: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, &context);
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings("<p data-name=\"Ada\">Grace &amp; Hopper | Engineer &lt; | first</p>", std.Io.Writer.buffered(&writer));
}

test "missing properties and out-of-range literal indexes report access spans" {
    const Person = struct { name: []const u8 };
    const name = try std.testing.allocator.dupe(u8, "Ada");
    defer std.testing.allocator.free(name);
    const Context = struct { people: [1]Person };
    var context: Context = undefined;
    context = .{ .people = [_]Person{.{ .name = name }} };
    const Case = struct { source: []const u8, selector: []const u8 };
    const cases = [_]Case{
        .{ .source = "{{ people[0].missing }}", .selector = ".missing" },
        .{ .source = "{{ people[2] }}", .selector = "[2]" },
    };
    for (cases) |case| {
        const result = try zeft.compile(std.testing.allocator, case.source, .{});
        var template = switch (result) {
            .success => |value| value,
            .failure => return error.UnexpectedCompileFailure,
        };
        defer template.deinit();

        var output: [16]u8 = undefined;
        var writer = std.Io.Writer.fixed(&output);
        const rendered = try template.render(&writer, &context);
        switch (rendered) {
            .success => return error.ExpectedDiagnostic,
            .failure => |diagnostic| {
                try std.testing.expectEqual(zeft.RenderErrorKind.invalid_property_access, diagnostic.kind);
                const start = std.mem.indexOf(u8, case.source, case.selector).?;
                try std.testing.expectEqual(@as(?zeft.SourceSpan, .{ .start = start, .end = start + case.selector.len }), diagnostic.span);
            },
        }
    }
}

test "finalized access expressions do not retain the template source" {
    const Context = struct { user: struct { name: []const u8 } };
    const source = try std.testing.allocator.dupe(u8, "{{ user.name }}");
    const result = try zeft.compile(std.testing.allocator, source, .{});
    std.testing.allocator.free(source);
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();

    const name = try std.testing.allocator.dupe(u8, "Ada");
    defer std.testing.allocator.free(name);
    var context: Context = undefined;
    context = .{ .user = .{ .name = name } };
    var output: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, &context);
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings("Ada", std.Io.Writer.buffered(&writer));
}

test "expression operators honor precedence and render literals" {
    const result = try zeft.compile(std.testing.allocator, "{{ 1 + 2 * 3 }}|{{ (8 - 2) / 3 }}|{{ !false }}|{{ 'a\\n' }}", .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    var output: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, .{});
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings("7|2|true|a\n", std.Io.Writer.buffered(&writer));
}

test "logical operators short circuit missing property access" {
    const result = try zeft.compile(std.testing.allocator, "{{ false && missing.value }}|{{ true || missing.value }}", .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    var output: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, .{});
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings("false|true", std.Io.Writer.buffered(&writer));
}

fn registeredSuffix(allocator: std.mem.Allocator, _: ?*const anyopaque, args: []const zeft.Value) anyerror!zeft.Value {
    if (args.len != 1 and args.len != 2) return error.InvalidArguments;
    const value = switch (args[0]) {
        .string => |string| string,
        else => return error.InvalidArguments,
    };
    const suffix = if (args.len == 1) "!" else switch (args[1]) {
        .string => |string| string,
        else => return error.InvalidArguments,
    };
    const joined = try std.mem.concat(allocator, u8, &.{ value, suffix });
    return .{ .string = joined };
}

fn failingCallable(_: std.mem.Allocator, _: ?*const anyopaque, _: []const zeft.Value) anyerror!zeft.Value {
    return error.DeliberateFailure;
}

test "built-in functions and filters evaluate through expression IR" {
    const result = try zeft.compile(std.testing.allocator, "{{ length(items) }}|{{ name | upper }}|{{ blank | default('fallback') | trim }}", .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();

    var output: [96]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const Context = struct { items: []const []const u8, name: []const u8, blank: []const u8 };
    var context: Context = .{ .items = &.{ "a", "b", "c" }, .name = "ada", .blank = "" };
    const rendered = try template.render(&writer, &context);
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings("3|ADA|fallback", std.Io.Writer.buffered(&writer));
}

test "registered functions and filters override built-ins and receive scratch allocation" {
    const result = try zeft.compile(std.testing.allocator, "{{ name | upper }}|{{ name | suffix('!') }}", .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();

    const registrations = [_]zeft.Registration{
        .{ .name = "upper", .callback = registeredSuffix },
        .{ .name = "suffix", .callback = registeredSuffix },
    };
    var output: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.renderWithOptions(&writer, .{ .name = "Ada" }, .{
        .allocator = std.testing.allocator,
        .filters = &registrations,
    });
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings("Ada!|Ada!", std.Io.Writer.buffered(&writer));
}

test "callable failures and invalid operands retain originating source spans" {
    const cases = [_]struct { source: []const u8, kind: zeft.RenderErrorKind }{
        .{ .source = "{{ fail() }}", .kind = .function_failure },
        .{ .source = "{{ value | fail }}", .kind = .filter_failure },
        .{ .source = "{{ 'a' - 1 }}", .kind = .invalid_operand },
    };
    const failing_functions = [_]zeft.Registration{.{ .name = "fail", .callback = failingCallable }};
    const failing_filters = [_]zeft.Registration{.{ .name = "fail", .callback = failingCallable }};
    for (cases) |case| {
        const result = try zeft.compile(std.testing.allocator, case.source, .{});
        var template = switch (result) {
            .success => |value| value,
            .failure => return error.UnexpectedCompileFailure,
        };
        defer template.deinit();
        var output: [16]u8 = undefined;
        var writer = std.Io.Writer.fixed(&output);
        const rendered = try template.renderWithOptions(&writer, .{ .value = "ok" }, .{
            .functions = &failing_functions,
            .filters = &failing_filters,
        });
        switch (rendered) {
            .success => return error.ExpectedDiagnostic,
            .failure => |diagnostic| {
                try std.testing.expectEqual(case.kind, diagnostic.kind);
                const expected = if (std.mem.indexOf(u8, case.source, "fail") != null) blk: {
                    const start = std.mem.indexOf(u8, case.source, "fail").?;
                    break :blk zeft.SourceSpan{ .start = start, .end = if (std.mem.indexOf(u8, case.source, "fail()") != null) start + 6 else start + 4 };
                } else blk: {
                    const start = std.mem.indexOf(u8, case.source, "-").?;
                    break :blk zeft.SourceSpan{ .start = start, .end = start + 1 };
                };
                try std.testing.expectEqual(@as(?zeft.SourceSpan, expected), diagnostic.span);
            },
        }
    }
}
