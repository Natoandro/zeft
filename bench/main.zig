const std = @import("std");
const zeft = @import("zeft");

const CountingAllocator = struct {
    child: std.mem.Allocator,
    allocations: usize = 0,
    requested_bytes: usize = 0,

    fn allocator(self: *CountingAllocator) std.mem.Allocator {
        return .{ .ptr = self, .vtable = &.{ .alloc = alloc, .resize = resize, .remap = remap, .free = free } };
    }
    fn alloc(ptr: *anyopaque, n: usize, alignment: std.mem.Alignment, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ptr));
        const result = self.child.rawAlloc(n, alignment, ra) orelse return null;
        self.allocations += 1;
        self.requested_bytes += n;
        return result;
    }
    fn resize(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, n: usize, ra: usize) bool {
        const self: *CountingAllocator = @ptrCast(@alignCast(ptr));
        const resized = self.child.rawResize(memory, alignment, n, ra);
        if (resized and n > memory.len) self.requested_bytes += n - memory.len;
        return resized;
    }
    fn remap(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, n: usize, ra: usize) ?[*]u8 {
        const self: *CountingAllocator = @ptrCast(@alignCast(ptr));
        const remapped = self.child.rawRemap(memory, alignment, n, ra) orelse return null;
        if (n > memory.len) self.requested_bytes += n - memory.len;
        return remapped;
    }
    fn free(ptr: *anyopaque, memory: []u8, alignment: std.mem.Alignment, ra: usize) void {
        const self: *CountingAllocator = @ptrCast(@alignCast(ptr));
        self.child.rawFree(memory, alignment, ra);
    }
};

const Sink = struct {
    writer: std.Io.Writer,
    calls: usize = 0,
    bytes: usize = 0,
    const vtable: std.Io.Writer.VTable = .{ .drain = drain };
    fn init() Sink {
        return .{ .writer = .{ .vtable = &vtable, .buffer = &.{} } };
    }
    fn drain(writer: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        const self: *Sink = @fieldParentPtr("writer", writer);
        self.calls += 1;
        var n: usize = 0;
        for (data[0 .. data.len - 1]) |part| n += part.len;
        n += data[data.len - 1].len * splat;
        self.bytes += n;
        return n;
    }
};

const Context = struct { name: []const u8, items: []const []const u8, show: bool };
const Case = struct { name: []const u8, source: []const u8 };

pub fn main() !void {
    var large = std.ArrayList(u8).empty;
    defer large.deinit(std.heap.page_allocator);
    try large.appendSlice(std.heap.page_allocator, "<ul>");
    for (0..250) |_| try large.appendSlice(std.heap.page_allocator, "<li class='item'>Static catalog entry</li>");
    try large.appendSlice(std.heap.page_allocator, "</ul>");

    const cases = [_]Case{
        .{ .name = "small", .source = "<p>Hello, {{ name }}!</p>" },
        .{ .name = "large", .source = large.items },
        .{ .name = "dynamic", .source = "<p>{{ name }}</p><p>{{ name }}</p><p>{{ name }}</p>" },
        .{ .name = "control-flow", .source = "{% if show %}<ul>{% for item in items %}<li>{{ item }}</li>{% endfor %}</ul>{% else %}hidden{% endif %}" },
    };
    std.debug.print("case,compile_ns,render_ns,compile_allocs,compile_bytes,render_allocs,render_bytes,write_calls,output_bytes,compiled_bytes\n", .{});
    for (cases) |case| try runCase(case);
}

fn runCase(case: Case) !void {
    var counter = CountingAllocator{ .child = std.heap.page_allocator };
    const allocator = counter.allocator();
    var started = nowNs();
    const before_allocs = counter.allocations;
    const before_bytes = counter.requested_bytes;
    const compiled = try zeft.compile(allocator, case.source, .{});
    const compile_ns = nowNs() - started;
    var template = switch (compiled) {
        .success => |value| value,
        .failure => return error.BenchmarkCompileFailed,
    };
    const compile_allocs = counter.allocations - before_allocs;
    const compile_bytes = counter.requested_bytes - before_bytes;

    const context = Context{ .name = "<Ada>", .items = &.{ "one", "two", "three" }, .show = true };
    const render_allocs_before = counter.allocations;
    const render_bytes_before = counter.requested_bytes;
    var sink = Sink.init();
    started = nowNs();
    for (0..1000) |_| {
        sink = Sink.init();
        const result = try template.renderWithOptions(&sink.writer, &context, .{ .allocator = allocator });
        if (result != .success) return error.BenchmarkRenderFailed;
    }
    const render_ns = (nowNs() - started) / 1000;
    const render_allocs = counter.allocations - render_allocs_before;
    const render_bytes = counter.requested_bytes - render_bytes_before;
    const writes = sink.calls;
    const output_bytes = sink.bytes;
    const compiled_bytes = template.compiledSize();
    template.deinit();
    std.debug.print("{s},{d},{d},{d},{d},{d},{d},{d},{d},{d}\n", .{
        case.name,     compile_ns,   render_ns, compile_allocs, compile_bytes,
        render_allocs, render_bytes, writes,    output_bytes,   compiled_bytes,
    });
}

fn nowNs() u64 {
    var ts: std.os.linux.timespec = undefined;
    _ = std.os.linux.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}
