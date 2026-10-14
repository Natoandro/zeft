const std = @import("std");
const zeft = @import("zeft");
const cases = @import("fixtures/safety.zig");

fn compile(source: []const u8, options: zeft.CompileOptions) !zeft.CompiledTemplate {
    return switch (try zeft.compile(std.testing.allocator, source, options)) {
        .success => |template| template,
        .failure => error.UnexpectedCompileFailure,
    };
}

fn expectRejected(
    source: []const u8,
    options: zeft.CompileOptions,
    kind: zeft.CompileErrorKind,
) !void {
    var result = try zeft.compile(std.testing.allocator, source, options);
    if (result == .success) {
        result.success.deinit();
        return error.ExpectedCompileFailure;
    }
    try std.testing.expectEqual(kind, result.failure.kind);
    try std.testing.expect(result.failure.span.?.isValid(source.len));
}

test "S-001 executable HTML interpolation is rejected and static and XML content remain valid" {
    for (cases.executable_html) |source| {
        try expectRejected(source, .{}, .unsupported_syntax);
    }
    var static = try compile("<script>let x=1;</script><p onclick='run()'>ok</p>", .{});
    defer static.deinit();
    var xml = try compile("<script>{{ value }}</script><x onclick='{{ value }}'/>", .{
        .format = .xml,
    });
    defer xml.deinit();
    var output: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    try std.testing.expectEqual(zeft.RenderResult.success, try xml.render(&writer, .{ .value = "<&" }));
    try std.testing.expectEqualStrings("<script>&lt;&amp;</script><x onclick='&lt;&amp;'/>", writer.buffered());
}

test "S-002 XML validates unique attribute names and literal characters" {
    for (cases.malformed_xml) |source| {
        try expectRejected(source, .{ .format = .xml }, .invalid_markup);
    }
    var valid = try compile("<x a='1' A='2' ns:a-b.c='3'>&#9;é</x>", .{ .format = .xml });
    defer valid.deinit();
}

test "S-003 evaluated logical operands require booleans and skipped operands remain skipped" {
    for (cases.invalid_logical) |source| {
        var template = try compile(source, .{});
        defer template.deinit();
        var output: [64]u8 = undefined;
        var writer = std.Io.Writer.fixed(&output);
        const result = try template.render(&writer, .{});
        try std.testing.expectEqual(zeft.RenderErrorKind.invalid_operand, result.failure.kind);
    }
    var template = try compile("{{ false && missing }}|{{ true || missing }}", .{});
    defer template.deinit();
    var output: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    try std.testing.expectEqual(zeft.RenderResult.success, try template.render(&writer, .{}));
    try std.testing.expectEqualStrings("false|true", writer.buffered());
}

test "S-004 nested markup grouped unary and left-deep expressions fail without stack exhaustion" {
    var source: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer source.deinit();
    for ([_]usize{ 128, 129 }) |depth| {
        source.clearRetainingCapacity();
        for (0..depth) |_| try source.writer.writeAll("<x>");
        for (0..depth) |_| try source.writer.writeAll("</x>");
        if (depth == 128) {
            var template = try compile(source.written(), .{});
            template.deinit();
        } else try expectRejected(source.written(), .{}, .unsupported_syntax);
        source.clearRetainingCapacity();
        try source.writer.writeAll("{{ ");
        for (0..depth) |_| try source.writer.writeAll("(");
        try source.writer.writeAll("true");
        for (0..depth) |_| try source.writer.writeAll(")");
        try source.writer.writeAll(" }}");
        if (depth == 128) {
            var template = try compile(source.written(), .{});
            template.deinit();
        } else try expectRejected(source.written(), .{}, .unsupported_syntax);
    }
    source.clearRetainingCapacity();
    for (0..1000) |_| try source.writer.writeAll("<x>");
    for (0..1000) |_| try source.writer.writeAll("</x>");
    try expectRejected(source.written(), .{}, .unsupported_syntax);
    for ([_][]const u8{ "(", "!" }) |token| {
        source.clearRetainingCapacity();
        try source.writer.writeAll("{{ ");
        for (0..1000) |_| try source.writer.writeAll(token);
        try source.writer.writeAll("true");
        if (token[0] == '(') for (0..1000) |_| try source.writer.writeAll(")");
        try source.writer.writeAll(" }}");
        try expectRejected(source.written(), .{}, .unsupported_syntax);
    }
    source.clearRetainingCapacity();
    try source.writer.writeAll("{{ 1");
    for (0..1000) |_| try source.writer.writeAll(" + 1");
    try source.writer.writeAll(" }}");
    try expectRejected(source.written(), .{}, .unsupported_syntax);
}

fn evictChild(
    _: std.mem.Allocator,
    raw: ?*const anyopaque,
    _: []const zeft.Value,
) anyerror!zeft.Value {
    const cache: *zeft.TemplateCache = @ptrCast(@alignCast(@constCast(raw.?)));
    cache.evict("child");
    return .null;
}

test "S-005 include diagnostics survive child eviction during an active render" {
    var cache = zeft.TemplateCache.init(std.testing.allocator);
    defer cache.deinit();
    var root = (try cache.getOrCompile("root", "{% include \"child\" %}", .{})).success;
    defer root.deinit();
    var child = (try cache.getOrCompile("child", "{{ evict() }}{% include \"missing\" %}", .{})).success;
    child.deinit();
    const registrations = [_]zeft.Registration{.{
        .name = "evict",
        .callback = evictChild,
        .user_data = &cache,
    }};
    var output: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const result = try root.renderWithOptions(&writer, .{}, .{ .functions = &registrations });
    try std.testing.expectEqual(zeft.RenderErrorKind.missing_include, result.failure.kind);
    try std.testing.expectEqualStrings("missing", result.failure.include_identity.?);
    try std.testing.expectEqualStrings("child", result.failure.include_parent_identity.?);
    const identity = try std.testing.allocator.dupe(u8, "absent");
    const missing = try cache.render(std.testing.allocator, identity, &writer, .{});
    std.testing.allocator.free(identity);
    try std.testing.expectEqualStrings("absent", missing.failure.include_identity.?);
}

fn oom(_: std.mem.Allocator, _: ?*const anyopaque, _: []const zeft.Value) anyerror!zeft.Value {
    return error.OutOfMemory;
}

test "S-006 callable allocation failures propagate as allocator errors" {
    const registrations = [_]zeft.Registration{.{ .name = "oom", .callback = oom }};
    for ([_][]const u8{ "{{ oom() }}", "{{ 1 | oom }}" }) |source| {
        var template = try compile(source, .{});
        defer template.deinit();
        var output: [16]u8 = undefined;
        var writer = std.Io.Writer.fixed(&output);
        try std.testing.expectError(error.OutOfMemory, template.renderWithOptions(&writer, .{}, .{
            .functions = &registrations,
            .filters = &registrations,
        }));
    }
}

fn count(_: std.mem.Allocator, _: ?*const anyopaque, args: []const zeft.Value) anyerror!zeft.Value {
    return .{ .integer = @intCast(args.len) };
}

test "S-007 expression stacks and call argument counts support large flat calls" {
    var source: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer source.deinit();
    try source.writer.writeAll("{{ count(");
    for (0..65536) |_| try source.writer.writeAll("1,");
    try source.writer.writeAll("count()) }}");
    var template = try compile(source.written(), .{});
    defer template.deinit();
    const registrations = [_]zeft.Registration{.{ .name = "count", .callback = count }};
    var output: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    try std.testing.expectEqual(zeft.RenderResult.success, try template.renderWithOptions(
        &writer,
        .{},
        .{
            .allocator = std.testing.allocator,
            .functions = &registrations,
        },
    ));
    try std.testing.expectEqualStrings("65537", writer.buffered());
}

test "O-003 hash lookup preserves many first-occurrence symbols and repeated string ownership" {
    var source: std.Io.Writer.Allocating = .init(std.testing.allocator);
    defer source.deinit();
    var names: [512][16]u8 = undefined;
    var entries: [512]zeft.ContextEntry = undefined;
    for (&entries, 0..) |*entry, i| {
        const name = try std.fmt.bufPrint(&names[i], "v{d}", .{i});
        entry.* = .{ .name = name, .value = .{ .string = "x" } };
        try source.writer.print("{{{{ {s} }}}}|", .{name});
    }
    var template = try compile(source.written(), .{});
    defer template.deinit();
    try std.testing.checkAllAllocationFailures(
        std.testing.allocator,
        exerciseLargeCompilation,
        .{source.written()},
    );
    source.clearRetainingCapacity();
    var output: [1024]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    try std.testing.expectEqual(zeft.RenderResult.success, try template.renderRuntime(
        &writer,
        &entries,
        .{ .allocator = std.testing.allocator },
    ));
    for (0..512) |i| try std.testing.expectEqualStrings("x|", output[i * 2 ..][0..2]);
    const size = template.compiledSize();
    try std.testing.expectEqual(size, template.compiledSize());
}

fn exerciseLargeCompilation(allocator: std.mem.Allocator, source: []const u8) !void {
    var template = switch (try zeft.compile(allocator, source, .{})) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
}

fn noProperty(_: *const anyopaque, _: []const u8) ?zeft.Value {
    return null;
}
fn noIndex(_: *const anyopaque, _: usize) ?zeft.Value {
    return null;
}

test "S-008 null equality works with all value tags in runtime and folded expressions" {
    const dummy: u8 = 0;
    const values = [_]zeft.Value{
        .null,
        .{ .boolean = true },
        .{ .integer = 42 },
        .{ .float = 1.5 },
        .{ .string = "hi" },
        .{ .object = .{ .pointer = &dummy, .get_property = noProperty } },
        .{ .sequence = .{ .pointer = &dummy, .len = 0, .get_index = noIndex } },
    };
    var template = try compile("{{ value == null }}|{{ null == value }}|{{ value != null }}|{{ null != value }}", .{});
    defer template.deinit();
    for (values) |value| {
        const entries = [_]zeft.ContextEntry{.{ .name = "value", .value = value }};
        var output: [64]u8 = undefined;
        var writer = std.Io.Writer.fixed(&output);
        try std.testing.expectEqual(zeft.RenderResult.success, try template.renderRuntime(
            &writer,
            &entries,
            .{ .allocator = std.testing.allocator },
        ));
        try std.testing.expectEqualStrings(if (value == .null)
            "true|true|false|false"
        else
            "false|false|true|true", writer.buffered());
    }
    var folded = try compile("{{ null == true }}|{{ null != 'hi' }}|{{ 1 == null }}|{{ null == null }}", .{});
    defer folded.deinit();
    var output: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    try std.testing.expectEqual(zeft.RenderResult.success, try folded.render(&writer, .{}));
    try std.testing.expectEqualStrings("false|true|false|true", writer.buffered());
}

test "S-009 all builtins support direct calls and function registrations override piped builtins" {
    var template = try compile("{{ upper('hi') }}|{{ lower('HI') }}|{{ trim(' hi ') }}|" ++
        "{{ default(null, 'hi') }}|{{ length('hi') }}", .{});
    defer template.deinit();
    var output: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    try std.testing.expectEqual(zeft.RenderResult.success, try template.render(&writer, .{}));
    try std.testing.expectEqualStrings("HI|hi|hi|hi|2", writer.buffered());
    var overridden = try compile("{{ upper('hi') }}|{{ 'hi' | upper }}", .{});
    defer overridden.deinit();
    const registrations = [_]zeft.Registration{.{ .name = "upper", .callback = count }};
    writer = .fixed(&output);
    try std.testing.expectEqual(zeft.RenderResult.success, try overridden.renderWithOptions(
        &writer,
        .{},
        .{ .functions = &registrations },
    ));
    try std.testing.expectEqualStrings("1|1", writer.buffered());
}
