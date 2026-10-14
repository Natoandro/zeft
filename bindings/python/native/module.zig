const std = @import("std");
const zeft = @import("zeft");

const NativeTemplate = struct { template: zeft.CompiledTemplate };

const CValue = extern struct {
    tag: c_int,
    boolean: c_int,
    integer: i64,
    float: f64,
    data: [*]const u8,
    len: usize,
    children: [*]const CValue,
    keys: [*]const CBytes,
};
const CBytes = extern struct { data: [*]const u8, len: usize };
const CSpan = extern struct { present: c_int, start: usize, end: usize };

fn valueFromC(value: *const CValue) zeft.Value {
    return switch (value.tag) {
        0 => .null,
        1 => .{ .boolean = value.boolean != 0 },
        2 => .{ .integer = value.integer },
        3 => .{ .float = value.float },
        4 => .{ .string = value.data[0..value.len] },
        5 => .{ .object = .{
            .pointer = @ptrCast(value),
            .get_property = objectProperty,
        } },
        6 => .{ .sequence = .{
            .pointer = @ptrCast(value),
            .len = value.len,
            .get_index = sequenceIndex,
        } },
        else => .null,
    };
}

fn objectProperty(raw: *const anyopaque, name: []const u8) ?zeft.Value {
    const object: *const CValue = @ptrCast(@alignCast(raw));
    for (object.children[0..object.len], 0..) |*child, index| {
        const key = object.keys[index];
        if (std.mem.eql(u8, key.data[0..key.len], name)) return valueFromC(child);
    }
    return null;
}

fn sequenceIndex(raw: *const anyopaque, index: usize) ?zeft.Value {
    const sequence: *const CValue = @ptrCast(@alignCast(raw));
    if (index >= sequence.len) return null;
    return valueFromC(&sequence.children[index]);
}

export fn zeft_template_compile(
    source: [*]const u8,
    source_len: usize,
    format: c_int,
    whitespace: c_int,
    indentation: [*]const u8,
    indentation_len: usize,
    out_template: *?*NativeTemplate,
    out_kind: *c_int,
    out_span: *CSpan,
) c_int {
    const owner = std.heap.c_allocator.create(NativeTemplate) catch return -1;
    const formats = [_]zeft.OutputFormat{ .html, .xml };
    const policies = [_]zeft.WhitespacePolicy{ .preserve, .compact, .pretty };
    const result = zeft.compile(std.heap.c_allocator, source[0..source_len], .{
        .format = formats[@intCast(format)],
        .whitespace = policies[@intCast(whitespace)],
        .indentation = indentation[0..indentation_len],
    }) catch {
        std.heap.c_allocator.destroy(owner);
        return -1;
    };
    switch (result) {
        .success => |template| {
            owner.* = .{ .template = template };
            out_template.* = owner;
            return 0;
        },
        .failure => |diagnostic| {
            std.heap.c_allocator.destroy(owner);
            out_kind.* = @intFromEnum(diagnostic.kind);
            setSpan(out_span, diagnostic.span);
            return 1;
        },
    }
}

export fn zeft_template_render(
    raw: *NativeTemplate,
    context: *const CValue,
    output: *?[*]u8,
    output_len: *usize,
    out_kind: *c_int,
    out_span: *CSpan,
) c_int {
    var allocating = std.Io.Writer.Allocating.init(std.heap.c_allocator);
    const entries = std.heap.c_allocator.alloc(zeft.ContextEntry, context.len) catch {
        allocating.deinit();
        return -1;
    };
    defer std.heap.c_allocator.free(entries);
    for (context.children[0..context.len], 0..) |*child, index| {
        const key = context.keys[index];
        entries[index] = .{
            .name = key.data[0..key.len],
            .value = valueFromC(child),
        };
    }
    const result = raw.template.renderRuntime(&allocating.writer, entries, .{}) catch {
        allocating.deinit();
        return -1;
    };
    switch (result) {
        .success => {
            const list = allocating.toArrayList();
            output.* = list.items.ptr;
            output_len.* = list.items.len;
            return 0;
        },
        .failure => |diagnostic| {
            allocating.deinit();
            out_kind.* = @intFromEnum(diagnostic.kind);
            setSpan(out_span, diagnostic.span);
            return 1;
        },
    }
}

export fn zeft_buffer_release(buffer: ?[*]u8, len: usize) void {
    if (len == 0) return;
    if (buffer) |bytes| std.heap.c_allocator.free(bytes[0..len]);
}

fn setSpan(out: *CSpan, span: ?zeft.SourceSpan) void {
    if (span) |value| {
        out.* = .{ .present = 1, .start = value.start, .end = value.end };
    } else {
        out.* = .{ .present = 0, .start = 0, .end = 0 };
    }
}

export fn zeft_template_release(raw: ?*NativeTemplate) void {
    const owner = raw orelse return;
    owner.template.deinit();
    std.heap.c_allocator.destroy(owner);
}
