//! Render finalized instructions. This module intentionally has no markup
//! parser dependency: static markup reaches it only as serialized byte strings.

const std = @import("std");
const core = @import("zeft_core");
const ir = @import("zeft_ir");

pub const Value = union(enum) {
    null,
    boolean: bool,
    number: f64,
    string: []const u8,
    object: Object,
    sequence: Sequence,
};

pub const Object = struct {
    pointer: *const anyopaque,
    get_property: *const fn (*const anyopaque, []const u8) ?Value,
};

pub const Sequence = struct {
    pointer: *const anyopaque,
    len: usize,
    get_index: *const fn (*const anyopaque, usize) ?Value,
};

pub const ContextEntry = struct { name: []const u8, value: Value };
pub const RenderResult = union(enum) {
    success,
    failure: core.RenderDiagnostic,
};

pub fn isString(comptime T: type) bool {
    const type_info = @typeInfo(T);
    return (type_info == .pointer and type_info.pointer.size == .slice and type_info.pointer.child == u8) or
        (type_info == .array and type_info.array.child == u8) or
        (type_info == .pointer and type_info.pointer.size == .one and @typeInfo(type_info.pointer.child) == .array and
            @typeInfo(type_info.pointer.child).array.child == u8);
}

pub fn stringValue(comptime T: type, value: T) []const u8 {
    if (comptime isString(T)) {
        const type_info = @typeInfo(T);
        if (type_info == .array) return value[0..];
        if (type_info == .pointer and type_info.pointer.size == .one and @typeInfo(type_info.pointer.child) == .array) return value[0..];
        return value;
    }
    unreachable;
}

/// Adapt supported native context values without allocating or copying them.
/// Objects are Zig structs, sequences are arrays/slices, and scalar leaves are
/// byte strings in the initial access-only expression subset.
pub fn adapt(comptime T: type, pointer: *const T) Value {
    const type_info = @typeInfo(T);
    if (type_info == .pointer and type_info.pointer.size == .slice and type_info.pointer.child == u8) {
        return .{ .string = pointer.* };
    }
    if (type_info == .array and type_info.array.child == u8) {
        return .{ .string = pointer.*[0..] };
    }
    if (type_info == .pointer and type_info.pointer.size == .slice) {
        return .{ .sequence = .{
            .pointer = @ptrCast(pointer),
            .len = pointer.*.len,
            .get_index = sequenceIndex(T),
        } };
    }
    if (type_info == .array) {
        return .{ .sequence = .{
            .pointer = @ptrCast(pointer),
            .len = type_info.array.len,
            .get_index = sequenceIndex(T),
        } };
    }
    if (type_info == .@"struct") {
        return .{ .object = .{ .pointer = @ptrCast(pointer), .get_property = objectProperty(T) } };
    }
    @compileError("context values must be structs, arrays, slices, or byte strings");
}

fn objectProperty(comptime T: type) *const fn (*const anyopaque, []const u8) ?Value {
    return struct {
        fn get(pointer: *const anyopaque, name: []const u8) ?Value {
            const value: *const T = @ptrCast(@alignCast(pointer));
            inline for (@typeInfo(T).@"struct".fields) |field| {
                if (std.mem.eql(u8, name, field.name)) return adapt(field.type, &@field(value.*, field.name));
            }
            return null;
        }
    }.get;
}

fn sequenceIndex(comptime T: type) *const fn (*const anyopaque, usize) ?Value {
    return struct {
        fn get(pointer: *const anyopaque, index: usize) ?Value {
            const value: *const T = @ptrCast(@alignCast(pointer));
            const type_info = @typeInfo(T);
            if (type_info == .array) {
                if (index >= type_info.array.len) return null;
                return adapt(type_info.array.child, &value.*[index]);
            }
            if (type_info == .pointer and type_info.pointer.size == .slice) {
                if (index >= value.*.len) return null;
                return adapt(type_info.pointer.child, &value.*[index]);
            }
            unreachable;
        }
    }.get;
}

pub fn render(
    program: ir.Program,
    writer: *std.Io.Writer,
    context: []const ContextEntry,
    format: core.OutputFormat,
) anyerror!RenderResult {
    var pc: usize = 0;
    while (pc < program.instructions.len) : (pc += 1) {
        const instruction = program.instructions[pc];
        switch (instruction.data) {
            .write_static => |id| try writer.writeAll(program.strings[id]),
            .write_expression => |write| {
                const value = switch (evaluateExpression(program, write.expression_id, context)) {
                    .success => |result| result,
                    .failure => |diagnostic| return .{ .failure = diagnostic },
                };
                switch (value) {
                    .string => |string| try writeEscaped(writer, string, write.escape_context, format),
                    else => return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } },
                }
            },
            .end => return .success,
        }
    }
    return .{ .failure = .{ .kind = .invalid_operand } };
}

const ExpressionResult = union(enum) {
    success: Value,
    failure: core.RenderDiagnostic,
};

fn evaluateExpression(
    program: ir.Program,
    expression_id: ir.ExpressionId,
    context: []const ContextEntry,
) ExpressionResult {
    if (expression_id >= program.expressions.len) return .{ .failure = .{ .kind = .invalid_operand } };
    const expression = program.expressions[expression_id];
    var value: ?Value = null;
    for (expression.instructions) |instruction| switch (instruction.data) {
        .load_root_symbol => |symbol_id| {
            if (symbol_id >= program.symbols.len) return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
            const name = program.symbols[symbol_id].name;
            for (context) |entry| {
                if (std.mem.eql(u8, name, entry.name)) {
                    value = entry.value;
                    break;
                }
            }
            if (value == null) return .{ .failure = .{ .kind = .missing_variable, .span = instruction.span } };
        },
        .get_property => |name| {
            const current = value orelse return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
            value = switch (current) {
                .object => |object| object.get_property(object.pointer, name),
                else => null,
            };
            if (value == null) return .{ .failure = .{ .kind = .invalid_property_access, .span = instruction.span } };
        },
        .get_index => |index| {
            const current = value orelse return .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } };
            value = switch (current) {
                .sequence => |sequence| if (index < sequence.len) sequence.get_index(sequence.pointer, index) else null,
                else => null,
            };
            if (value == null) return .{ .failure = .{ .kind = .invalid_property_access, .span = instruction.span } };
        },
        .return_value => return if (value) |result|
            .{ .success = result }
        else
            .{ .failure = .{ .kind = .invalid_operand, .span = instruction.span } },
    };
    return .{ .failure = .{ .kind = .invalid_operand } };
}

fn writeEscaped(writer: *std.Io.Writer, value: []const u8, context: ir.EscapeContext, format: core.OutputFormat) anyerror!void {
    var segment_start: usize = 0;
    for (value, 0..) |byte, index| {
        const replacement: ?[]const u8 = switch (context) {
            .text => switch (byte) {
                '&' => "&amp;",
                '<' => "&lt;",
                '>' => "&gt;",
                else => null,
            },
            .attribute => switch (byte) {
                '&' => "&amp;",
                '<' => "&lt;",
                '>' => "&gt;",
                '"' => "&quot;",
                '\'' => if (format == .html) "&#39;" else "&apos;",
                else => null,
            },
        };
        if (replacement) |escaped| {
            try writer.writeAll(value[segment_start..index]);
            try writer.writeAll(escaped);
            segment_start = index + 1;
        }
    }
    try writer.writeAll(value[segment_start..]);
}

test "runtime writes serialized static bytes without markup interpretation" {
    const static_bytes = "<Root data-x='a &amp; b'><Child /></Root>";
    const strings = [_][]const u8{static_bytes};
    const instructions = [_]ir.Instruction{
        .{ .span = .{ .start = 0, .end = static_bytes.len }, .data = .{ .write_static = 0 } },
        .{ .span = .{ .start = static_bytes.len, .end = static_bytes.len }, .data = .end },
    };
    const program: ir.Program = .{
        .strings = @constCast(&strings),
        .symbols = &.{},
        .expressions = &.{},
        .instructions = @constCast(&instructions),
    };
    var output: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const result = try render(program, &writer, &.{}, .xml);
    try std.testing.expectEqual(RenderResult.success, result);
    try std.testing.expectEqualStrings(static_bytes, std.Io.Writer.buffered(&writer));
}
