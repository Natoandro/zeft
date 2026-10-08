//! Lower the parsed AST and analyzed expressions into Render IR.

const std = @import("std");
const zeft = @import("zeft_core");
const parser = @import("zeft_parser");
const analysis = @import("zeft_analysis");
const ir = @import("zeft_ir");
const expression = analysis.Expression;

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
    locals: std.ArrayList(struct { name: []const u8, slot: u32 }) = .empty,
    loop_stack: std.ArrayList(struct { begin: usize }) = .empty,
    next_slot: u32 = 0,

    fn visit(self: *Lowerer, nodes: []const parser.Node) std.mem.Allocator.Error!void {
        for (nodes) |node| {
            switch (node.data) {
                .text => |text| try self.writeStatic(text, node.span),
                .static_markup => |markup| try self.writeStatic(markup.serialized, node.span),
                .break_ => try self.instructions.append(self.allocator, .{ .span = node.span, .data = .{ .loop_break = 0 } }),
                .continue_ => try self.instructions.append(self.allocator, .{ .span = node.span, .data = .{ .loop_continue = 0 } }),
                .conditional => |conditional| {
                    const condition_id = try self.compileExpression(conditional.condition);
                    const branch_index = self.instructions.items.len;
                    try self.instructions.append(self.allocator, .{ .span = conditional.condition, .data = .{ .jump_if_false = .{ .expression_id = condition_id, .target = 0 } } });
                    try self.visit(conditional.then_nodes);
                    const jump_index = self.instructions.items.len;
                    try self.instructions.append(self.allocator, .{ .span = node.span, .data = .{ .jump = 0 } });
                    self.instructions.items[branch_index].data.jump_if_false.target = @intCast(self.instructions.items.len);
                    try self.visit(conditional.else_nodes);
                    self.instructions.items[jump_index].data.jump = @intCast(self.instructions.items.len);
                },
                .loop => |loop| {
                    const expression_id = try self.compileExpression(loop.expression);
                    const slot = self.next_slot;
                    self.next_slot += 1;
                    const begin = self.instructions.items.len;
                    try self.instructions.append(self.allocator, .{ .span = loop.expression, .data = .{ .loop_begin = .{ .expression_id = expression_id, .slot = slot, .exit_target = 0 } } });
                    const body_target: u32 = @intCast(self.instructions.items.len);
                    try self.locals.append(self.allocator, .{ .name = loop.name, .slot = slot });
                    try self.loop_stack.append(self.allocator, .{ .begin = begin });
                    try self.visit(loop.children);
                    const next = self.instructions.items.len;
                    try self.instructions.append(self.allocator, .{ .span = node.span, .data = .{ .loop_next = .{ .body_target = body_target, .exit_target = 0 } } });
                    const exit_target: u32 = @intCast(self.instructions.items.len);
                    self.instructions.items[begin].data.loop_begin.exit_target = exit_target;
                    self.instructions.items[next].data.loop_next.exit_target = exit_target;
                    self.patchLoopControls(next, exit_target);
                    self.loop_stack.items.len -= 1;
                    self.locals.items.len -= 1;
                },
                .element => |element| {
                    try self.writeOpeningTag(element, node.span.start);
                    try self.visit(element.children);
                    if (element.closing_tag.len != 0) {
                        try self.writeStatic(element.closing_tag, .{
                            .start = node.span.end - element.closing_tag.len,
                            .end = node.span.end,
                        });
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
        const id = try self.compileExpression(source_span);
        const expression_info = self.analyzed.expressions[self.expression_index - 1];
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
        return;
    }

    fn compileExpression(self: *Lowerer, source_span: zeft.SourceSpan) std.mem.Allocator.Error!ir.ExpressionId {
        _ = source_span;
        const expression_info = self.analyzed.expressions[self.expression_index];
        self.expression_index += 1;
        const id = std.math.cast(ir.ExpressionId, self.expressions.items.len) orelse unreachable;
        var expr_instructions: std.ArrayList(ir.ExpressionInstruction) = .empty;
        try self.emitExpr(&expr_instructions, expression_info.expression);
        try expr_instructions.append(self.allocator, .{
            .span = expression_info.expression.span,
            .data = .return_value,
        });
        try self.expressions.append(self.allocator, .{ .instructions = try expr_instructions.toOwnedSlice(self.allocator) });
        return id;
    }

    fn emitExpr(self: *Lowerer, output: *std.ArrayList(ir.ExpressionInstruction), expr: analysis.Expression) std.mem.Allocator.Error!void {
        switch (expr.data) {
            .literal => |literal| try output.append(self.allocator, .{ .span = expr.span, .data = .{ .push_literal = switch (literal) {
                .null => .null,
                .boolean => |v| .{ .boolean = v },
                .number => |v| .{ .number = v },
                .string => |v| .{ .string = v },
            } } }),
            .identifier => |name| if (self.findLocal(name)) |slot|
                try output.append(self.allocator, .{ .span = expr.span, .data = .{ .load_local = slot } })
            else
                try output.append(self.allocator, .{ .span = expr.span, .data = .{ .load_root_symbol = self.findSymbol(name) } }),
            .property => |access| {
                try self.emitExpr(output, access.base.*);
                try output.append(self.allocator, .{ .span = access.selector_span, .data = .{ .get_property = access.name } });
            },
            .index => |access| {
                try self.emitExpr(output, access.base.*);
                try output.append(self.allocator, .{ .span = access.selector_span, .data = .{ .get_index = access.value } });
            },
            .unary => |unary| {
                try self.emitExpr(output, unary.operand.*);
                try output.append(self.allocator, .{ .span = unary.operator_span, .data = .{ .unary = @enumFromInt(@intFromEnum(unary.op)) } });
            },
            .binary => |binary| {
                try self.emitExpr(output, binary.left.*);
                if (binary.op == .and_ or binary.op == .or_) {
                    const jump_index = output.items.len;
                    try output.append(self.allocator, .{ .span = binary.left.span, .data = if (binary.op == .and_) .{ .jump_if_false = 0 } else .{ .jump_if_true = 0 } });
                    try self.emitExpr(output, binary.right.*);
                    const target: u32 = @intCast(output.items.len);
                    if (binary.op == .and_) output.items[jump_index].data.jump_if_false = target else output.items[jump_index].data.jump_if_true = target;
                } else {
                    try self.emitExpr(output, binary.right.*);
                    try output.append(self.allocator, .{ .span = binary.operator_span, .data = .{ .binary = @enumFromInt(@intFromEnum(binary.op)) } });
                }
            },
            .call => |call| {
                for (call.args) |arg| try self.emitExpr(output, arg.*);
                try output.append(self.allocator, .{ .span = call.call_span, .data = .{ .call_function = .{ .name = call.name, .argument_count = @intCast(call.args.len) } } });
            },
            .filter => |filter| {
                try self.emitExpr(output, filter.input.*);
                for (filter.args) |arg| try self.emitExpr(output, arg.*);
                try output.append(self.allocator, .{ .span = filter.call_span, .data = .{ .call_filter = .{ .name = filter.name, .argument_count = @intCast(filter.args.len + 1) } } });
            },
        }
    }

    fn findSymbol(self: *Lowerer, name: []const u8) analysis.SymbolId {
        for (self.analyzed.symbols) |symbol| if (std.mem.eql(u8, symbol.name, name)) return symbol.id;
        unreachable;
    }

    fn findLocal(self: *Lowerer, name: []const u8) ?u32 {
        var index = self.locals.items.len;
        while (index > 0) {
            index -= 1;
            if (std.mem.eql(u8, self.locals.items[index].name, name)) return self.locals.items[index].slot;
        }
        return null;
    }

    fn patchLoopControls(self: *Lowerer, next: usize, exit: u32) void {
        const frame = self.loop_stack.items[self.loop_stack.items.len - 1];
        for (self.instructions.items[frame.begin + 1 .. next]) |*instruction| {
            switch (instruction.data) {
                .loop_break => {
                    if (instruction.data.loop_break == 0) instruction.data.loop_break = exit;
                },
                .loop_continue => {
                    if (instruction.data.loop_continue == 0) instruction.data.loop_continue = @intCast(next);
                },
                else => {},
            }
        }
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
