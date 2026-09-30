//! Lower the parsed AST and analyzed expressions into Render IR.

const std = @import("std");
const zeft = @import("zeft_core");
const parser = @import("zeft_parser");
const analysis = @import("zeft_analysis");
const ir = @import("zeft_ir");

pub const LowerResult = union(enum) {
    success: ir.Program,
    failure: zeft.CompileDiagnostic,
};

pub fn lower(
    allocator: std.mem.Allocator,
    document: parser.Document,
    analyzed: analysis.Result,
) std.mem.Allocator.Error!LowerResult {
    var lowerer = Lowerer{
        .allocator = allocator,
        .analyzed = analyzed,
    };
    try lowerer.visit(document.nodes);
    if (lowerer.failure) |diagnostic| return .{ .failure = diagnostic };
    const source_end = if (document.nodes.len == 0) 0 else document.nodes[document.nodes.len - 1].span.end;
    try lowerer.instructions.append(allocator, .{
        .span = .{ .start = source_end, .end = source_end },
        .data = .end,
    });
    return .{ .success = .{
        .strings = try lowerer.strings.toOwnedSlice(allocator),
        .symbols = analyzed.symbols,
        .expressions = try lowerer.expressions.toOwnedSlice(allocator),
        .instructions = try lowerer.instructions.toOwnedSlice(allocator),
    } };
}

const Lowerer = struct {
    allocator: std.mem.Allocator,
    analyzed: analysis.Result,
    expression_index: usize = 0,
    strings: std.ArrayList([]const u8) = .empty,
    expressions: std.ArrayList(ir.ExpressionProgram) = .empty,
    instructions: std.ArrayList(ir.Instruction) = .empty,
    failure: ?zeft.CompileDiagnostic = null,

    fn visit(self: *Lowerer, nodes: []const parser.Node) std.mem.Allocator.Error!void {
        for (nodes) |node| {
            switch (node.data) {
                .text => |text| try self.writeStatic(text, node.span),
                .static_markup => |markup| try self.writeStatic(markup.serialized, node.span),
                .element => |element| {
                    try self.writeOpeningTag(element, node.span.start);
                    try self.visit(element.children);
                    if (!element.is_void and !element.self_closing) {
                        const closing = try std.fmt.allocPrint(self.allocator, "</{s}>", .{element.name});
                        try self.writeStatic(closing, .{ .start = node.span.end - element.name.len - 3, .end = node.span.end });
                    }
                },
                .expression => |expr| try self.writeExpression(expr.source_span, node.span),
            }
            if (self.failure != null) return;
        }
    }

    fn writeStatic(self: *Lowerer, bytes: []const u8, span: zeft.SourceSpan) std.mem.Allocator.Error!void {
        if (bytes.len == 0) return;
        const id = std.math.cast(ir.StringId, self.strings.items.len) orelse unreachable;
        try self.strings.append(self.allocator, bytes);
        try self.instructions.append(self.allocator, .{
            .span = span,
            .data = .{ .write_static = id },
        });
    }

    fn writeOpeningTag(self: *Lowerer, element: parser.Element, source_start: usize) std.mem.Allocator.Error!void {
        var cursor: usize = 0;
        for (element.attributes) |attribute| {
            if (attribute.value) |value| {
                for (value.segments) |segment| {
                    switch (segment.data) {
                        .text => {},
                        .expression => |source_span| {
                            const expression_start = segment.span.start - source_start;
                            const expression_end = segment.span.end - source_start;
                            try self.writeStatic(element.opening_tag[cursor..expression_start], .{
                                .start = source_start + cursor,
                                .end = source_start + expression_start,
                            });
                            try self.writeExpression(source_span, segment.span);
                            cursor = expression_end;
                        },
                    }
                }
            }
        }
        try self.writeStatic(element.opening_tag[cursor..], .{
            .start = source_start + cursor,
            .end = source_start + element.opening_tag.len,
        });
    }

    fn writeExpression(self: *Lowerer, source_span: zeft.SourceSpan, output_span: zeft.SourceSpan) std.mem.Allocator.Error!void {
        if (self.expression_index >= self.analyzed.expressions.len) {
            self.failure = .{ .kind = .syntax, .span = source_span };
            return;
        }
        const expression_info = self.analyzed.expressions[self.expression_index];
        self.expression_index += 1;
        const id = std.math.cast(ir.ExpressionId, self.expressions.items.len) orelse unreachable;
        const expr_instructions = try self.allocator.alloc(ir.ExpressionInstruction, 2);
        expr_instructions[0] = .{
            .span = expression_info.identifier.span,
            .data = .{ .load_root_symbol = expression_info.symbol_id },
        };
        expr_instructions[1] = .{
            .span = expression_info.identifier.span,
            .data = .return_value,
        };
        try self.expressions.append(self.allocator, .{ .instructions = expr_instructions });
        try self.instructions.append(self.allocator, .{
            .span = output_span,
            .data = .{ .write_expression = .{
                .expression_id = id,
                .escape_context = switch (expression_info.output_context) {
                    .text => .text,
                    .attribute => .attribute,
                },
            } },
        });
    }
};

test "lowers serialized static markup and expression operations" {
    const source = "<p>Hello, {{ name }}!</p>";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const parsed = try parser.parse(allocator, source);
    const document = switch (parsed) {
        .success => |value| value,
        .failure => return error.UnexpectedParseFailure,
    };
    const analyzed_result = try analysis.analyze(allocator, source, document);
    const analyzed = switch (analyzed_result) {
        .success => |value| value,
        .failure => return error.UnexpectedAnalysisFailure,
    };
    const lowered = try lower(allocator, document, analyzed);
    const program = switch (lowered) {
        .success => |value| value,
        .failure => return error.UnexpectedLowerFailure,
    };
    try std.testing.expectEqual(@as(usize, 6), program.instructions.len);
    try std.testing.expectEqualStrings("<p>", program.strings[0]);
    try std.testing.expectEqualStrings("Hello, ", program.strings[1]);
    try std.testing.expectEqualStrings("!", program.strings[2]);
    try std.testing.expectEqualStrings("</p>", program.strings[3]);
    try std.testing.expectEqual(@as(usize, 2), program.expressions[0].instructions.len);
    try std.testing.expectEqual(@as(usize, 0), program.instructions[2].data.write_expression.expression_id);
    try std.testing.expectEqual(@as(zeft.SourceSpan, .{ .start = source.len, .end = source.len }), program.instructions[5].span);
}
