//! Cache and include scenarios through the public API.
const fixture_data = @import("fixtures/cache.zig");
const std = @import("std");
const zeft = @import("zeft");
const allocator = std.testing.allocator;
const context = .{ .value = @as([]const u8, "<Ada>") };
const root = fixture_data.includes.root.template;
const child = fixture_data.includes.child.template;
const child_v2 = fixture_data.includes.child_v2.template;
const invalid = fixture_data.includes.invalid.template;

const cache_cases = @import("fixtures/cache.zig");

fn load(
    cache: *zeft.TemplateCache,
    identity: []const u8,
    source: []const u8,
    options: zeft.CompileOptions,
) !zeft.TemplateLease {
    return switch (try cache.getOrCompile(identity, source, options)) {
        .success => |lease| lease,
        .failure => error.UnexpectedCompileFailure,
    };
}

fn expectLease(lease: *const zeft.TemplateLease, expected: []const u8) !void {
    const buffer = try allocator.alloc(u8, expected.len + 256);
    defer allocator.free(buffer);
    var writer = std.Io.Writer.fixed(buffer);
    try std.testing.expectEqual(
        zeft.RenderResult.success,
        try lease.renderWithOptions(
            &writer,
            context,
            .{ .allocator = allocator },
        ),
    );
    try std.testing.expectEqualStrings(expected, writer.buffered());
}

fn render(
    cache: *zeft.TemplateCache,
    identity: []const u8,
    writer: *std.Io.Writer,
) !zeft.RenderResult {
    return cache.renderWithOptions(
        allocator,
        identity,
        writer,
        context,
        .{ .allocator = allocator },
    );
}

test "CA-001 cache hits distinct identities and source versions" {
    errdefer std.debug.print("CA-001 fixture input\n", .{});
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    var first = try load(&cache, "child", child, .{});
    defer first.deinit();
    var hit = try load(&cache, "child", child, .{});
    defer hit.deinit();
    try std.testing.expect(first.entry == hit.entry);
    var distinct = try load(&cache, "child ", child, .{});
    defer distinct.deinit();
    try std.testing.expect(first.entry != distinct.entry);
    var changed = try load(&cache, "child", child_v2, .{});
    defer changed.deinit();
    try expectLease(&first, "<p>&lt;Ada&gt;</p>");
    try expectLease(&changed, "<b>&lt;Ada&gt;</b>");
}

test "CA-002 cache options preserve independent retained outputs" {
    errdefer std.debug.print("CA-002 fixture input\n", .{});
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    const source = fixture_data.includes.options.template;
    const options = [_]zeft.CompileOptions{
        .{},
        .{ .whitespace = .compact },
        .{ .whitespace = .pretty },
        .{
            .whitespace = .pretty,
            .indentation = "\t",
        },
        .{ .format = .xml },
    };
    const outputs = [_][]const u8{
        fixture_data.includes.options_preserve.output,
        fixture_data.includes.options_compact.output,
        fixture_data.includes.options_pretty.output,
        fixture_data.includes.options_tab.output,
        fixture_data.includes.options_preserve.output,
    };
    var leases: [options.len]zeft.TemplateLease = undefined;
    var initialized: usize = 0;
    defer for (leases[0..initialized]) |*lease| lease.deinit();
    for (options, 0..) |option, i| {
        leases[i] = try load(&cache, "options", source, option);
        initialized += 1;
        for (leases[0..i]) |previous| try std.testing.expect(previous.entry != leases[i].entry);
    }
    for (&leases, outputs) |*lease, output| try expectLease(lease, output);
}

test "CA-003 independently compiled nested and repeated includes reload children" {
    errdefer std.debug.print("CA-003 fixture input\n", .{});
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    var parent = try load(&cache, "root", root, .{});
    defer parent.deinit();
    var initial_child = try load(&cache, "child", child, .{});
    defer initial_child.deinit();
    try expectLease(&parent, fixture_data.includes.root.output);
    var next_child = try load(&cache, "child", child_v2, .{});
    defer next_child.deinit();
    try expectLease(&parent, fixture_data.includes.root_child_v2.output);
    var next_parent = try load(&cache, "root", fixture_data.includes.root_v2.template, .{});
    defer next_parent.deinit();
    try expectLease(&next_parent, fixture_data.includes.root_v2.output);
    try expectLease(&parent, fixture_data.includes.root_child_v2.output);
    var nested = try load(&cache, "child", fixture_data.includes.nested.template, .{});
    defer nested.deinit();
    var leaf = try load(&cache, "leaf", fixture_data.includes.leaf.template, .{});
    defer leaf.deinit();
    try expectLease(&parent, fixture_data.includes.nested.output);
}

test "CA-004 failed parent and child reloads preserve valid versions" {
    errdefer std.debug.print("CA-004 fixture input\n", .{});
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    var parent = try load(&cache, "root", root, .{});
    defer parent.deinit();
    var initial_child = try load(&cache, "child", child, .{});
    defer initial_child.deinit();
    for ([_][]const u8{ "root", "child" }) |identity| {
        switch (try cache.getOrCompile(identity, invalid, .{})) {
            .success => |value| {
                var lease = value;
                lease.deinit();
                return error.ExpectedCompileFailure;
            },
            .failure => |diagnostic| try std.testing.expectEqualDeep(
                zeft.CompileDiagnostic{
                    .kind = .invalid_markup,
                    .span = .{
                        .start = 0,
                        .end = 6,
                    },
                },
                diagnostic,
            ),
        }
    }
    try expectLease(&parent, fixture_data.includes.root.output);
    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectEqual(zeft.RenderResult.success, try render(&cache, "root", &writer));
    try std.testing.expectEqualStrings(fixture_data.includes.root.output, writer.buffered());
}

test "CA-005 missing dependencies and initial child failure retain diagnostic identities" {
    errdefer std.debug.print("CA-005 fixture input\n", .{});
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectEqualDeep(
        zeft.RenderResult{ .failure = .{
            .kind = .missing_template,
            .include_identity = "unknown",
        } },
        try render(
            &cache,
            "unknown",
            &writer,
        ),
    );
    var parent = try load(&cache, "parent", fixture_data.includes.missing.template, .{});
    var parent_alive = true;
    defer if (parent_alive) parent.deinit();
    const missing = try render(&cache, "parent", &writer);
    try std.testing.expectEqualDeep(
        zeft.RenderResult{ .failure = .{
            .kind = .missing_include,
            .span = .{
                .start = 0,
                .end = 22,
            },
            .include_identity = "absent",
            .include_parent_identity = "parent",
        } },
        missing,
    );
    switch (try cache.getOrCompile("absent", invalid, .{})) {
        .success => |value| {
            var lease = value;
            lease.deinit();
            return error.ExpectedCompileFailure;
        },
        .failure => {},
    }
    const failed = try render(&cache, "parent", &writer);
    try std.testing.expectEqualDeep(
        zeft.RenderResult{ .failure = .{
            .kind = .include_compile_failure,
            .span = .{
                .start = 0,
                .end = 22,
            },
            .include_identity = "absent",
            .include_parent_identity = "parent",
            .include_compile_diagnostic = .{
                .kind = .invalid_markup,
                .span = .{
                    .start = 0,
                    .end = 6,
                },
            },
        } },
        failed,
    );
    parent.deinit();
    parent_alive = false;
    cache.evict("parent");
    var replacement = try load(&cache, "parent", child, .{});
    defer replacement.deinit();
    try std.testing.expectEqualStrings("parent", missing.failure.include_parent_identity.?);
    try std.testing.expectEqualStrings("absent", failed.failure.include_identity.?);
    var fixed = try load(&cache, "absent", child, .{});
    defer fixed.deinit();
    var restored = try load(&cache, "parent", fixture_data.includes.missing.template, .{});
    defer restored.deinit();
    try expectLease(&restored, "<p>&lt;Ada&gt;</p>");
}

test "CA-006 recursive includes report the offending dependency edge" {
    errdefer std.debug.print("CA-006 fixture input\n", .{});
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    var a = try load(&cache, "a", fixture_data.includes.cycle_a.template, .{});
    defer a.deinit();
    var b = try load(&cache, "b", fixture_data.includes.cycle_b.template, .{});
    defer b.deinit();
    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectEqualDeep(
        zeft.RenderResult{ .failure = .{
            .kind = .include_cycle,
            .span = .{
                .start = 1,
                .end = 18,
            },
            .include_identity = "a",
            .include_parent_identity = "b",
        } },
        try render(
            &cache,
            "a",
            &writer,
        ),
    );
}

test "CA-007 eviction keeps retained roots valid and resolves current children" {
    errdefer std.debug.print("CA-007 fixture input\n", .{});
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    var parent = try load(&cache, "root", root, .{});
    defer parent.deinit();
    var initial_child = try load(&cache, "child", child, .{});
    defer initial_child.deinit();
    cache.evict("root");
    try expectLease(&parent, fixture_data.includes.root.output);
    cache.evict("child");
    try expectLease(&initial_child, "<p>&lt;Ada&gt;</p>");
    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const failure = try parent.renderWithOptions(&writer, context, .{ .allocator = allocator });
    try std.testing.expectEqual(zeft.RenderErrorKind.missing_include, failure.failure.kind);
    var changed = try load(&cache, "child", child_v2, .{});
    defer changed.deinit();
    try expectLease(&parent, fixture_data.includes.root_child_v2.output);
}
