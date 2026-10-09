//! Cache and include scenarios through the public API.
const std = @import("std");
const zeft = @import("zeft");
const allocator = std.testing.allocator;
const context = .{ .value = @as([]const u8, "<Ada>") };
const root = @embedFile("fixtures/includes/root.tmpl");
const child = @embedFile("fixtures/includes/child.tmpl");
const child_v2 = @embedFile("fixtures/includes/child-v2.tmpl");
const invalid = @embedFile("fixtures/includes/invalid.tmpl");

pub const harness_ids = [_][]const u8{ "CA-001", "CA-002", "CA-003", "CA-004", "CA-005", "CA-006", "CA-007" };

fn load(cache: *zeft.TemplateCache, identity: []const u8, source: []const u8, options: zeft.CompileOptions) !zeft.TemplateLease {
    return switch (try cache.getOrCompile(identity, source, options)) {
        .success => |lease| lease,
        .failure => error.UnexpectedCompileFailure,
    };
}

fn expectLease(lease: *const zeft.TemplateLease, expected: []const u8) !void {
    const buffer = try allocator.alloc(u8, expected.len + 256);
    defer allocator.free(buffer);
    var writer = std.Io.Writer.fixed(buffer);
    try std.testing.expectEqual(zeft.RenderResult.success, try lease.renderWithOptions(&writer, context, .{ .allocator = allocator }));
    try std.testing.expectEqualStrings(expected, writer.buffered());
}

fn render(cache: *zeft.TemplateCache, identity: []const u8, writer: *std.Io.Writer) !zeft.RenderResult {
    return cache.renderWithOptions(allocator, identity, writer, context, .{ .allocator = allocator });
}

test "CA-001 cache hits distinct identities and source versions" {
    errdefer std.debug.print("CA-001 fixtures/includes/child.tmpl\n", .{});
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
    errdefer std.debug.print("CA-002 fixtures/includes/options.tmpl\n", .{});
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    const source = @embedFile("fixtures/includes/options.tmpl");
    const options = [_]zeft.CompileOptions{ .{}, .{ .whitespace = .compact }, .{ .whitespace = .pretty }, .{ .whitespace = .pretty, .indentation = "\t" }, .{ .format = .xml } };
    const outputs = [_][]const u8{ @embedFile("fixtures/includes/options-preserve.out"), @embedFile("fixtures/includes/options-compact.out"), @embedFile("fixtures/includes/options-pretty.out"), @embedFile("fixtures/includes/options-tab.out"), @embedFile("fixtures/includes/options-preserve.out") };
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
    errdefer std.debug.print("CA-003 fixtures/includes/root.tmpl\n", .{});
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    var parent = try load(&cache, "root", root, .{});
    defer parent.deinit();
    var initial_child = try load(&cache, "child", child, .{});
    defer initial_child.deinit();
    try expectLease(&parent, @embedFile("fixtures/includes/root.out"));
    var next_child = try load(&cache, "child", child_v2, .{});
    defer next_child.deinit();
    try expectLease(&parent, @embedFile("fixtures/includes/root-child-v2.out"));
    var next_parent = try load(&cache, "root", @embedFile("fixtures/includes/root-v2.tmpl"), .{});
    defer next_parent.deinit();
    try expectLease(&next_parent, @embedFile("fixtures/includes/root-v2.out"));
    try expectLease(&parent, @embedFile("fixtures/includes/root-child-v2.out"));
    var nested = try load(&cache, "child", @embedFile("fixtures/includes/nested.tmpl"), .{});
    defer nested.deinit();
    var leaf = try load(&cache, "leaf", @embedFile("fixtures/includes/leaf.tmpl"), .{});
    defer leaf.deinit();
    try expectLease(&parent, @embedFile("fixtures/includes/nested.out"));
}

test "CA-004 failed parent and child reloads preserve valid versions" {
    errdefer std.debug.print("CA-004 fixtures/includes/invalid.tmpl\n", .{});
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
            .failure => |diagnostic| try std.testing.expectEqualDeep(zeft.CompileDiagnostic{ .kind = .invalid_markup, .span = .{ .start = 0, .end = 6 } }, diagnostic),
        }
    }
    try expectLease(&parent, @embedFile("fixtures/includes/root.out"));
    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectEqual(zeft.RenderResult.success, try render(&cache, "root", &writer));
    try std.testing.expectEqualStrings(@embedFile("fixtures/includes/root.out"), writer.buffered());
}

test "CA-005 missing dependencies and initial child failure retain diagnostic identities" {
    errdefer std.debug.print("CA-005 fixtures/includes/missing.tmpl\n", .{});
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectEqualDeep(zeft.RenderResult{ .failure = .{ .kind = .missing_template, .include_identity = "unknown" } }, try render(&cache, "unknown", &writer));
    var parent = try load(&cache, "parent", @embedFile("fixtures/includes/missing.tmpl"), .{});
    var parent_alive = true;
    defer if (parent_alive) parent.deinit();
    const missing = try render(&cache, "parent", &writer);
    try std.testing.expectEqualDeep(zeft.RenderResult{ .failure = .{ .kind = .missing_include, .span = .{ .start = 0, .end = 22 }, .include_identity = "absent", .include_parent_identity = "parent" } }, missing);
    switch (try cache.getOrCompile("absent", invalid, .{})) {
        .success => |value| {
            var lease = value;
            lease.deinit();
            return error.ExpectedCompileFailure;
        },
        .failure => {},
    }
    const failed = try render(&cache, "parent", &writer);
    try std.testing.expectEqualDeep(zeft.RenderResult{ .failure = .{ .kind = .include_compile_failure, .span = .{ .start = 0, .end = 22 }, .include_identity = "absent", .include_parent_identity = "parent", .include_compile_diagnostic = .{ .kind = .invalid_markup, .span = .{ .start = 0, .end = 6 } } } }, failed);
    parent.deinit();
    parent_alive = false;
    cache.evict("parent");
    var replacement = try load(&cache, "parent", child, .{});
    defer replacement.deinit();
    try std.testing.expectEqualStrings("parent", missing.failure.include_parent_identity.?);
    try std.testing.expectEqualStrings("absent", failed.failure.include_identity.?);
    var fixed = try load(&cache, "absent", child, .{});
    defer fixed.deinit();
    var restored = try load(&cache, "parent", @embedFile("fixtures/includes/missing.tmpl"), .{});
    defer restored.deinit();
    try expectLease(&restored, "<p>&lt;Ada&gt;</p>");
}

test "CA-006 recursive includes report the offending dependency edge" {
    errdefer std.debug.print("CA-006 fixtures/includes/cycle-a.tmpl\n", .{});
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    var a = try load(&cache, "a", @embedFile("fixtures/includes/cycle-a.tmpl"), .{});
    defer a.deinit();
    var b = try load(&cache, "b", @embedFile("fixtures/includes/cycle-b.tmpl"), .{});
    defer b.deinit();
    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectEqualDeep(zeft.RenderResult{ .failure = .{ .kind = .include_cycle, .span = .{ .start = 1, .end = 18 }, .include_identity = "a", .include_parent_identity = "b" } }, try render(&cache, "a", &writer));
}

test "CA-007 eviction keeps retained roots valid and resolves current children" {
    errdefer std.debug.print("CA-007 fixtures/includes/root.tmpl\n", .{});
    var cache = zeft.TemplateCache.init(allocator);
    defer cache.deinit();
    var parent = try load(&cache, "root", root, .{});
    defer parent.deinit();
    var initial_child = try load(&cache, "child", child, .{});
    defer initial_child.deinit();
    cache.evict("root");
    try expectLease(&parent, @embedFile("fixtures/includes/root.out"));
    cache.evict("child");
    try expectLease(&initial_child, "<p>&lt;Ada&gt;</p>");
    var buffer: [256]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const failure = try parent.renderWithOptions(&writer, context, .{ .allocator = allocator });
    try std.testing.expectEqual(zeft.RenderErrorKind.missing_include, failure.failure.kind);
    var changed = try load(&cache, "child", child_v2, .{});
    defer changed.deinit();
    try expectLease(&parent, @embedFile("fixtures/includes/root-child-v2.out"));
}
