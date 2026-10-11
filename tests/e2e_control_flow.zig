const std = @import("std");
const zeft = @import("zeft");
const runner = @import("fixture_runner.zig");
const control_flow_cases = @import("fixtures/control_flow.zig");
const Item = struct { name: []const u8, enabled: bool };
const Group = struct { name: []const u8, items: []const Item };
pub const Context = struct {
    show: bool = true,
    inner: bool = true,
    item: []const u8 = "root",
    items: []const Item = &.{},
    groups: []const Group = &.{},
};
const items = [_]Item{
    .{
        .name = "A",
        .enabled = true,
    },
    .{
        .name = "B",
        .enabled = false,
    },
    .{
        .name = "C",
        .enabled = true,
    },
};
const groups = [_]Group{ .{ .name = "outer1", .items = &items }, .{ .name = "outer2", .items = &.{} } };
pub const Case = struct { fixture: runner.Success, context: Context };

test "named control-flow golden cases" {
    for (control_flow_cases.success_cases) |case| {
        try runner.expectSuccess(case.fixture, &case.params);
    }
    for (control_flow_cases.failure_cases) |case| {
        try runner.expectRenderFailure(case.fixture, &case.params);
    }
}

test "control-flow compiled template resets state after success and failure" {
    var template = switch (try zeft.compile(std.testing.allocator, "{#for item in items}{{ item.name }}{/for}:{{ item }}", .{})) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    var buffer: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectEqual(
        zeft.RenderResult.success,
        try template.render(
            &writer,
            &Context{ .items = &items },
        ),
    );
    try std.testing.expectEqualStrings("ABC:root", writer.buffered());
    writer = .fixed(&buffer);
    const BadItem = struct { other: []const u8 };
    const BadContext = struct { items: []const BadItem, item: []const u8 };
    const bad_context = BadContext{ .items = &[_]BadItem{.{ .other = "x" }}, .item = "root" };
    const failed = try template.render(&writer, &bad_context);
    switch (failed) {
        .success => return error.ExpectedRenderFailure,
        .failure => |diagnostic| try std.testing.expectEqualDeep(
            zeft.RenderDiagnostic{
                .kind = .invalid_property_access,
                .span = .{
                    .start = 27,
                    .end = 32,
                },
            },
            diagnostic,
        ),
    }
    writer = .fixed(&buffer);
    try std.testing.expectEqual(
        zeft.RenderResult.success,
        try template.render(
            &writer,
            &Context{},
        ),
    );
    try std.testing.expectEqualStrings(":root", writer.buffered());
    writer = .fixed(&buffer);
    try std.testing.expectEqual(
        zeft.RenderResult.success,
        try template.render(
            &writer,
            &Context{ .items = items[0..1] },
        ),
    );
    try std.testing.expectEqualStrings("A:root", writer.buffered());
}

test "else-if chains evaluate only conditions needed to select a branch" {
    const source = "{#if show}A{:else if inner}B{:else if missing}C{:else}D{/if}";
    var template = switch (try zeft.compile(std.testing.allocator, source, .{})) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    const contexts = [_]struct { show: bool, inner: bool, missing: bool }{
        .{ .show = true, .inner = false, .missing = false },
        .{ .show = false, .inner = true, .missing = false },
        .{ .show = false, .inner = false, .missing = true },
        .{ .show = false, .inner = false, .missing = false },
    };
    for (contexts, "ABCD") |context, expected| {
        var buffer: [32]u8 = undefined;
        var writer = std.Io.Writer.fixed(&buffer);
        try std.testing.expectEqual(
            zeft.RenderResult.success,
            try template.render(
                &writer,
                &context,
            ),
        );
        try std.testing.expectEqualSlices(u8, &.{expected}, writer.buffered());
    }
    var buffer: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const short_context: struct { show: bool, inner: bool } = .{ .show = false, .inner = true };
    try std.testing.expectEqual(
        zeft.RenderResult.success,
        try template.render(
            &writer,
            &short_context,
        ),
    );
    try std.testing.expectEqualStrings("B", writer.buffered());
}

test "loop else restores enclosing bindings and skips after break continue and exhaustion" {
    const cases = .{
        .{ "{#for item in items}{{item.name}}{:else}{{item}}{/for}", "root", "ABC" },
        .{ "{#for item in items}{% break %}{:else}{{item}}{/for}", "root", "" },
        .{ "{#for item in items}{% continue %}{:else}{{item}}{/for}", "root", "" },
        .{ "{#for item in groups}{#for item in item.items}{{item.name}}{:else}{{item.name}}{/for}{/for}", "", "ABCouter2" },
        .{ "{#for item in groups}{#for child in item.items}{% continue %}{:else}{% break %}{/for}X{/for}", "", "X" },
    };
    inline for (cases) |case| {
        var template = switch (try zeft.compile(std.testing.allocator, case[0], .{})) {
            .success => |value| value,
            .failure => return error.UnexpectedCompileFailure,
        };
        defer template.deinit();
        for (
            [_]Context{
                .{},
                .{
                    .items = &items,
                    .groups = &groups,
                },
            },
            [_][]const u8{
                case[1],
                case[2],
            },
        ) |context, expected| {
            var buffer: [128]u8 = undefined;
            var writer = std.Io.Writer.fixed(&buffer);
            try std.testing.expectEqual(
                zeft.RenderResult.success,
                try template.render(
                    &writer,
                    &context,
                ),
            );
            try std.testing.expectEqualStrings(expected, writer.buffered());
        }
    }
}

test "block branches and closing tokens report exact invalid placement spans" {
    const cases = .{
        .{ "{:else if true}", "{:else if true}", zeft.CompileErrorKind.invalid_construct },
        .{ "{#if true}{:else}{:else if true}{/if}", "{:else if true}", zeft.CompileErrorKind.invalid_construct },
        .{ "{#for x in items}{:else if true}{/for}", "{:else if true}", zeft.CompileErrorKind.invalid_construct },
        .{ "{#for x in items}{:else}{:else}{/for}", "{:else}", zeft.CompileErrorKind.invalid_construct },
        .{ "{#if true}{/for}", "{/for}", zeft.CompileErrorKind.invalid_construct },
        .{ "{#if true}{/if true}", "{/if true}", zeft.CompileErrorKind.syntax },
        .{ "{#for x in items}{:else}{% break %}{/for}", "{% break %}", zeft.CompileErrorKind.invalid_construct },
        .{ "{#for x in items}{:else}{% continue %}{/for}", "{% continue %}", zeft.CompileErrorKind.invalid_construct },
        .{ "{#if true", "{#if true", zeft.CompileErrorKind.syntax },
        .{ "{% if true %}", "{% if true %}", zeft.CompileErrorKind.syntax },
        .{ "{% for x in items %}", "{% for x in items %}", zeft.CompileErrorKind.syntax },
        .{ "{% else %}", "{% else %}", zeft.CompileErrorKind.syntax },
        .{ "{% elif true %}", "{% elif true %}", zeft.CompileErrorKind.syntax },
        .{ "{% endif %}", "{% endif %}", zeft.CompileErrorKind.syntax },
        .{ "{% endfor %}", "{% endfor %}", zeft.CompileErrorKind.syntax },
    };
    inline for (cases) |case| {
        const result = try zeft.compile(std.testing.allocator, case[0], .{});
        switch (result) {
            .success => |value| {
                var template = value;
                template.deinit();
                return error.ExpectedCompileFailure;
            },
            .failure => |diagnostic| {
                const start = std.mem.lastIndexOf(u8, case[0], case[1]).?;
                try std.testing.expectEqualDeep(
                    zeft.CompileDiagnostic{
                        .kind = case[2],
                        .span = .{
                            .start = start,
                            .end = start + case[1].len,
                        },
                    },
                    diagnostic,
                );
            },
        }
    }
}

test "block syntax preserves literal markup attributes and quoted closing characters" {
    const source = "<p title=\"{#if literal}{:else}{/if}\">{#if '}' == '}'}yes{:else if false}no{:else}bad{/if}<!--{#for x in y}{/for}--></p>";
    const xml = "<![CDATA[{#if literal}{:else}{/if}]]>";
    inline for (.{
        .{
            source,
            "<p title=\"{#if literal}{:else}{/if}\">yes<!--{#for x in y}{/for}--></p>",
            zeft.OutputFormat.html,
        },
        .{
            xml,
            xml,
            zeft.OutputFormat.xml,
        },
    }) |case| {
        var template = switch (try zeft.compile(
            std.testing.allocator,
            case[0],
            .{ .format = case[2] },
        )) {
            .success => |value| value,
            .failure => return error.UnexpectedCompileFailure,
        };
        defer template.deinit();
        var buffer: [256]u8 = undefined;
        var writer = std.Io.Writer.fixed(&buffer);
        try std.testing.expectEqual(zeft.RenderResult.success, try template.render(&writer, .{}));
        try std.testing.expectEqualStrings(case[1], writer.buffered());
    }
    const structural = "<ul>{#if show}<li>A</li>{:else if inner}<li>B</li>{:else}<li>C</li>{/if}{#for item in items}<li>{{item.name}}</li>{:else}<li>empty</li>{/for}</ul>";
    for ([_]zeft.WhitespacePolicy{ .preserve, .compact, .pretty }) |policy| {
        var template = switch (try zeft.compile(
            std.testing.allocator,
            structural,
            .{ .whitespace = policy },
        )) {
            .success => |value| value,
            .failure => return error.UnexpectedCompileFailure,
        };
        defer template.deinit();
        var buffer: [256]u8 = undefined;
        var writer = std.Io.Writer.fixed(&buffer);
        try std.testing.expectEqual(
            zeft.RenderResult.success,
            try template.render(
                &writer,
                &Context{
                    .show = false,
                    .inner = true,
                },
            ),
        );
        try std.testing.expectEqualStrings(if (policy == .pretty) "<ul>\n  <li>B</li>\n  <li>empty</li>\n</ul>\n" else "<ul><li>B</li><li>empty</li></ul>", writer.buffered());
    }
}
