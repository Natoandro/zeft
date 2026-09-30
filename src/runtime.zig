//! Render finalized instructions. This module intentionally has no markup
//! parser dependency: static markup reaches it only as serialized byte strings.

const std = @import("std");
const core = @import("zeft_core");
const ir = @import("zeft_ir");

pub const ContextEntry = struct { name: []const u8, value: []const u8 };
pub const RenderResult = union(enum) {
    success,
    failure: core.RenderDiagnostic,
};

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
                try writeEscaped(writer, value, write.escape_context, format);
            },
            .end => return .success,
        }
    }
    return .{ .failure = .{ .kind = .invalid_operand } };
}

const ExpressionResult = union(enum) {
    success: []const u8,
    failure: core.RenderDiagnostic,
};

fn evaluateExpression(
    program: ir.Program,
    expression_id: ir.ExpressionId,
    context: []const ContextEntry,
) ExpressionResult {
    if (expression_id >= program.expressions.len) return .{ .failure = .{ .kind = .invalid_operand } };
    const expression = program.expressions[expression_id];
    var value: ?[]const u8 = null;
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
