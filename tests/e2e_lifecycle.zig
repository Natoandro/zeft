const std = @import("std");
const zeft = @import("zeft");

pub const harness_ids = [_][]const u8{
    "LC-001/source-and-options-ownership",
    "LC-002/static-writer-error",
    "LC-003/dynamic-writer-error-scratch",
    "LC-004/include-writer-error-scratch",
    "LC-005/callback-error-scratch",
    "LC-006/diagnostic-error-scratch",
    "LC-007/overlapping-compiled-renders",
    "LC-008/active-child-eviction-and-reload",
    "LC-009/byte-array-context-storage",
};

const DebugAllocator = std.heap.DebugAllocator(.{
    .thread_safe = true,
    .stack_trace_frames = 0,
    .enable_memory_limit = true,
});
const ValueContext = struct { value: []const u8 = "value" };
const copy_registration = [_]zeft.Registration{.{ .name = "copy", .callback = copyValue }};

test "LC-009 byte arrays retain context storage for pointer value and nested contexts" {
    const Bytes = struct { bytes: [4]u8 };
    const context = Bytes{ .bytes = "byte".* };
    var root = try compile(@embedFile("fixtures/lifecycle/array-root.tmpl"), .{});
    defer root.deinit();
    var buffer: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectEqual(zeft.RenderResult.success, try root.render(&writer, &context));
    try std.testing.expectEqualStrings(@embedFile("fixtures/lifecycle/array.out"), writer.buffered());
    writer = .fixed(&buffer);
    try std.testing.expectEqual(zeft.RenderResult.success, try root.render(&writer, context));
    try std.testing.expectEqualStrings(@embedFile("fixtures/lifecycle/array.out"), writer.buffered());
    var nested = try compile(@embedFile("fixtures/lifecycle/array-nested.tmpl"), .{});
    defer nested.deinit();
    const nested_context = struct { record: Bytes }{ .record = context };
    writer = .fixed(&buffer);
    try std.testing.expectEqual(
        zeft.RenderResult.success,
        try nested.render(
            &writer,
            &nested_context,
        ),
    );
    try std.testing.expectEqualStrings(@embedFile("fixtures/lifecycle/array.out"), writer.buffered());
}

fn compile(source: []const u8, options: zeft.CompileOptions) !zeft.CompiledTemplate {
    return switch (try zeft.compile(std.testing.allocator, source, options)) {
        .success => |value| value,
        .failure => error.UnexpectedCompileFailure,
    };
}

fn load(cache: *zeft.TemplateCache, identity: []const u8, source: []const u8) !zeft.TemplateLease {
    return switch (try cache.getOrCompile(identity, source, .{})) {
        .success => |value| value,
        .failure => error.UnexpectedCompileFailure,
    };
}

fn copyValue(
    allocator: std.mem.Allocator,
    _: ?*const anyopaque,
    args: []const zeft.Value,
) anyerror!zeft.Value {
    if (args.len != 1 or args[0] != .string) return error.BadArguments;
    return .{ .string = try allocator.dupe(u8, args[0].string) };
}

fn allocateThenFail(
    allocator: std.mem.Allocator,
    _: ?*const anyopaque,
    _: []const zeft.Value,
) anyerror!zeft.Value {
    _ = try allocator.dupe(u8, "callback temporary bytes");
    return error.CallbackRejected;
}

test "LC-001 compiled source and indentation survive buffer release" {
    var tracked: DebugAllocator = .init;
    defer std.testing.expect(tracked.deinit() == .ok) catch @panic("compile allocation leak");
    const allocator = tracked.allocator();
    var template = blk: {
        const source = try allocator.dupe(u8, @embedFile("fixtures/lifecycle/ownership.tmpl"));
        defer allocator.free(source);
        const indentation = try allocator.dupe(u8, "\t");
        defer allocator.free(indentation);
        const result = switch (try zeft.compile(
            allocator,
            source,
            .{
                .whitespace = .pretty,
                .indentation = indentation,
            },
        )) {
            .success => |value| value,
            .failure => return error.UnexpectedCompileFailure,
        };
        // Overwrite both inputs, then release them before rendering.
        @memset(source, 'x');
        @memset(indentation, 'x');
        break :blk result;
    };
    var template_alive = true;
    defer if (template_alive) template.deinit();
    const owned_bytes = tracked.total_requested_bytes;
    try std.testing.expect(owned_bytes > 0);
    var buffer: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectEqual(
        zeft.RenderResult.success,
        try template.render(
            &writer,
            ValueContext{ .value = "<owned>" },
        ),
    );
    try std.testing.expectEqualStrings(@embedFile("fixtures/lifecycle/ownership.out"), writer.buffered());
    try std.testing.expectEqual(owned_bytes, tracked.total_requested_bytes);
    template.deinit();
    template_alive = false;
    try std.testing.expectEqual(@as(usize, 0), tracked.total_requested_bytes);
}

test "LC-002 original static writer error propagates" {
    var template = try compile(@embedFile("fixtures/lifecycle/static.tmpl"), .{});
    defer template.deinit();
    var buffer: [1]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(error.WriteFailed, template.render(&writer, .{}));
}

test "LC-003 dynamic writer error releases callback scratch" {
    var tracked: DebugAllocator = .init;
    defer std.testing.expect(tracked.deinit() == .ok) catch @panic("render allocation leak");
    var template = try compile(@embedFile("fixtures/lifecycle/dynamic.tmpl"), .{});
    defer template.deinit();
    var buffer: [1]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(
        error.WriteFailed,
        template.renderWithOptions(
            &writer,
            ValueContext{ .value = "temporary&" },
            .{
                .allocator = tracked.allocator(),
                .filters = &copy_registration,
            },
        ),
    );
    try std.testing.expectEqual(@as(usize, 0), tracked.total_requested_bytes);
}

test "LC-004 include writer error releases render state and child lease" {
    var tracked: DebugAllocator = .init;
    defer std.testing.expect(tracked.deinit() == .ok) catch @panic("include allocation leak");
    var cache = zeft.TemplateCache.init(tracked.allocator());
    defer cache.deinit();
    var parent = try load(&cache, "parent", @embedFile("fixtures/lifecycle/parent.tmpl"));
    defer parent.deinit();
    var child = try load(&cache, "child", @embedFile("fixtures/lifecycle/child.tmpl"));
    child.deinit();
    const baseline = tracked.total_requested_bytes;
    var buffer: [1]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    try std.testing.expectError(
        error.WriteFailed,
        cache.renderWithOptions(
            tracked.allocator(),
            "parent",
            &writer,
            ValueContext{},
            .{
                .allocator = tracked.allocator(),
                .filters = &copy_registration,
            },
        ),
    );
    try std.testing.expectEqual(baseline, tracked.total_requested_bytes);
    // With no application-held child lease, eviction can reclaim its storage.
    cache.evict("child");
    try std.testing.expect(tracked.total_requested_bytes < baseline);
}

test "LC-005 callback failure releases allocations made before error" {
    var tracked: DebugAllocator = .init;
    defer std.testing.expect(tracked.deinit() == .ok) catch @panic("callback allocation leak");
    var template = try compile(@embedFile("fixtures/lifecycle/callback-error.tmpl"), .{});
    defer template.deinit();
    const registration = [_]zeft.Registration{.{ .name = "fail", .callback = allocateThenFail }};
    var buffer: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const rendered = try template.renderWithOptions(
        &writer,
        ValueContext{},
        .{
            .allocator = tracked.allocator(),
            .filters = &registration,
        },
    );
    try std.testing.expect(rendered == .failure);
    try std.testing.expectEqualDeep(
        zeft.RenderDiagnostic{
            .kind = .filter_failure,
            .span = .{
                .start = 11,
                .end = 15,
            },
        },
        rendered.failure,
    );
    try std.testing.expectEqual(@as(usize, 0), tracked.total_requested_bytes);
}

test "LC-006 later template diagnostic releases successful callback scratch" {
    var tracked: DebugAllocator = .init;
    defer std.testing.expect(tracked.deinit() == .ok) catch @panic("diagnostic allocation leak");
    var template = try compile(@embedFile("fixtures/lifecycle/diagnostic.tmpl"), .{});
    defer template.deinit();
    var buffer: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&buffer);
    const rendered = try template.renderWithOptions(
        &writer,
        ValueContext{},
        .{
            .allocator = tracked.allocator(),
            .filters = &copy_registration,
        },
    );
    try std.testing.expect(rendered == .failure);
    try std.testing.expectEqualDeep(
        zeft.RenderDiagnostic{
            .kind = .missing_variable,
            .span = .{
                .start = 21,
                .end = 27,
            },
        },
        rendered.failure,
    );
    try std.testing.expectEqual(@as(usize, 0), tracked.total_requested_bytes);
}

const Gate = struct {
    entered: std.atomic.Value(bool) = .init(false),
    proceed: std.atomic.Value(bool) = .init(false),
    done: std.atomic.Value(bool) = .init(false),
};

fn holdValue(
    allocator: std.mem.Allocator,
    raw: ?*const anyopaque,
    args: []const zeft.Value,
) anyerror!zeft.Value {
    const result = try copyValue(allocator, null, args);
    const gate: *Gate = @ptrCast(@alignCast(@constCast(raw.?)));
    gate.entered.store(true, .release);
    while (!gate.proceed.load(.acquire)) std.atomic.spinLoopHint();
    return result;
}

fn waitUntilEntered(gate: *Gate) !void {
    while (!gate.entered.load(.acquire) and !gate.done.load(.acquire)) std.atomic.spinLoopHint();
    try std.testing.expect(gate.entered.load(.acquire));
}

const ConcurrentContext = struct { show: bool, items: []const []const u8, fallback: []const u8 };
const CompiledWorker = struct {
    template: *const zeft.CompiledTemplate,
    gate: *Gate,
    context: ConcurrentContext,
    allocator: std.mem.Allocator,
    bytes: [64]u8 = undefined,
    len: usize = 0,
    failed: bool = false,
};

fn renderCompiled(worker: *CompiledWorker) void {
    defer worker.gate.done.store(true, .release);
    var writer = std.Io.Writer.fixed(&worker.bytes);
    const registrations = [_]zeft.Registration{.{
        .name = "hold",
        .callback = holdValue,
        .user_data = worker.gate,
    }};
    const rendered = worker.template.renderWithOptions(
        &writer,
        &worker.context,
        .{
            .allocator = worker.allocator,
            .functions = &registrations,
        },
    ) catch {
        worker.failed = true;
        return;
    };
    worker.failed = rendered != .success;
    worker.len = writer.buffered().len;
}

test "LC-007 synchronized overlapping renders isolate branch loop and scratch state" {
    var tracked: DebugAllocator = .init;
    defer std.testing.expect(tracked.deinit() == .ok) catch @panic("concurrent allocation leak");
    var template = try compile(@embedFile("fixtures/lifecycle/concurrent.tmpl"), .{});
    defer template.deinit();
    var first_gate = Gate{};
    var second_gate = Gate{};
    var first = CompiledWorker{
        .template = &template,
        .gate = &first_gate,
        .context = .{
            .show = true,
            .items = &.{
                "A",
                "B",
            },
            .fallback = "unused",
        },
        .allocator = tracked.allocator(),
    };
    var second = CompiledWorker{
        .template = &template,
        .gate = &second_gate,
        .context = .{
            .show = false,
            .items = &.{"unused"},
            .fallback = "other",
        },
        .allocator = tracked.allocator(),
    };
    const first_thread = try std.Thread.spawn(.{}, renderCompiled, .{&first});
    defer {
        first_gate.proceed.store(true, .release);
        first_thread.join();
    }
    try waitUntilEntered(&first_gate);
    const second_thread = try std.Thread.spawn(.{}, renderCompiled, .{&second});
    var second_joined = false;
    defer if (!second_joined) {
        second_gate.proceed.store(true, .release);
        second_thread.join();
    };
    try waitUntilEntered(&second_gate);
    // Both renders have live scratch results before either callback returns.
    try std.testing.expect(tracked.total_requested_bytes > 0);
    second_gate.proceed.store(true, .release);
    second_thread.join();
    second_joined = true;
    try std.testing.expect(!second.failed);
    try std.testing.expectEqualStrings(@embedFile("fixtures/lifecycle/concurrent-second.out"), second.bytes[0..second.len]);
    try std.testing.expect(!first_gate.done.load(.acquire));
    first_gate.proceed.store(true, .release);
    // Join through the deferred cleanup before checking shared allocation count.
    while (!first_gate.done.load(.acquire)) std.atomic.spinLoopHint();
    try std.testing.expect(!first.failed);
    try std.testing.expectEqualStrings(@embedFile("fixtures/lifecycle/concurrent-first.out"), first.bytes[0..first.len]);
    try std.testing.expectEqual(@as(usize, 0), tracked.total_requested_bytes);
}

const CacheWorker = struct {
    cache: *zeft.TemplateCache,
    gate: *Gate,
    bytes: [64]u8 = undefined,
    len: usize = 0,
    failed: bool = false,
};

fn renderCache(worker: *CacheWorker) void {
    defer worker.gate.done.store(true, .release);
    var writer = std.Io.Writer.fixed(&worker.bytes);
    const registrations = [_]zeft.Registration{.{
        .name = "hold",
        .callback = holdValue,
        .user_data = worker.gate,
    }};
    const rendered = worker.cache.renderWithOptions(
        std.heap.page_allocator,
        "parent",
        &writer,
        ValueContext{},
        .{
            .allocator = std.heap.page_allocator,
            .functions = &registrations,
        },
    ) catch {
        worker.failed = true;
        return;
    };
    worker.failed = rendered != .success;
    worker.len = writer.buffered().len;
}

test "LC-008 active included child survives eviction and reload" {
    var cache = zeft.TemplateCache.init(std.testing.allocator);
    defer cache.deinit();
    var parent = try load(&cache, "parent", @embedFile("fixtures/lifecycle/parent.tmpl"));
    defer parent.deinit();
    var child = try load(&cache, "child", @embedFile("fixtures/lifecycle/held-child.tmpl"));
    child.deinit();
    var gate = Gate{};
    var worker = CacheWorker{ .cache = &cache, .gate = &gate };
    const thread = try std.Thread.spawn(.{}, renderCache, .{&worker});
    var joined = false;
    defer if (!joined) {
        gate.proceed.store(true, .release);
        thread.join();
    };
    try waitUntilEntered(&gate);
    // The callback runs inside the independently acquired child lease.
    cache.evict("child");
    var replacement = try load(&cache, "child", @embedFile("fixtures/lifecycle/new-child.tmpl"));
    defer replacement.deinit();
    var bytes: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&bytes);
    try std.testing.expectEqual(
        zeft.RenderResult.success,
        try parent.render(
            &writer,
            ValueContext{},
        ),
    );
    try std.testing.expectEqualStrings(@embedFile("fixtures/lifecycle/new-child.out"), writer.buffered());
    try std.testing.expect(!gate.done.load(.acquire));
    gate.proceed.store(true, .release);
    thread.join();
    joined = true;
    try std.testing.expect(!worker.failed);
    try std.testing.expectEqualStrings(@embedFile("fixtures/lifecycle/held-child.out"), worker.bytes[0..worker.len]);
}
