//! Semantic analysis for the template AST.

const std = @import("std");
const zeft = @import("zeft_core");
const parser = @import("zeft_parser");
const expression = @import("zeft_expression");
pub const Expression = expression.Expression;

pub const SymbolId = u32;

pub const OutputContext = enum {
    text,
    attribute,
};

pub const Symbol = struct {
    id: SymbolId,
    name: []const u8,
};

pub const AnalyzedExpression = struct {
    expression: expression.Expression,
    symbol_id: SymbolId,
    output_context: OutputContext,
};

pub const Result = struct {
    symbols: []Symbol,
    expressions: []AnalyzedExpression,
};

pub const AnalyzeResult = union(enum) {
    success: Result,
    failure: zeft.CompileDiagnostic,
};

/// Analyze expression names in depth-first document order and assign stable IDs.
pub fn analyze(
    allocator: std.mem.Allocator,
    source: []const u8,
    document: parser.Document,
) std.mem.Allocator.Error!AnalyzeResult {
    var analyzer = Analyzer{ .allocator = allocator, .source = source };
    try analyzer.visit(document.nodes);
    if (analyzer.failure) |diagnostic| return .{ .failure = diagnostic };
    return .{ .success = .{
        .symbols = try analyzer.symbols.toOwnedSlice(allocator),
        .expressions = try analyzer.expressions.toOwnedSlice(allocator),
    } };
}

const Analyzer = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    symbols: std.ArrayList(Symbol) = .empty,
    expressions: std.ArrayList(AnalyzedExpression) = .empty,
    failure: ?zeft.CompileDiagnostic = null,

    fn visit(self: *Analyzer, nodes: []const parser.Node) std.mem.Allocator.Error!void {
        for (nodes) |node| {
            switch (node.data) {
                .text, .static_markup => {},
                .element => |element| {
                    for (element.attributes) |attribute| {
                        if (attribute.value) |value| {
                            for (value.segments) |segment| {
                                switch (segment.data) {
                                    .text => {},
                                    .expression => |span| try self.addExpression(span, .attribute),
                                }
                                if (self.failure != null) return;
                            }
                        }
                    }
                    try self.visit(element.children);
                },
                .expression => |expr| try self.addExpression(expr.source_span, .text),
            }
        }
    }

    fn addExpression(self: *Analyzer, span: zeft.SourceSpan, output_context: OutputContext) std.mem.Allocator.Error!void {
        const parsed = try expression.parse(self.allocator, self.source, span);
        const parsed_expression = switch (parsed) {
            .success => |value| value,
            .failure => |diagnostic| {
                self.failure = diagnostic;
                return;
            },
        };
        try self.collectSymbols(&parsed_expression);
        const symbol_id = if (firstIdentifier(&parsed_expression)) |name| self.getSymbolId(name) else 0;
        try self.expressions.append(self.allocator, .{
            .expression = parsed_expression,
            .symbol_id = symbol_id,
            .output_context = output_context,
        });
    }

    fn collectSymbols(self: *Analyzer, expr: *const expression.Expression) std.mem.Allocator.Error!void {
        switch (expr.data) {
            .identifier => |name| {
                _ = try self.getOrAddSymbol(name);
            },
            .property => |access| try self.collectSymbols(access.base),
            .index => |access| try self.collectSymbols(access.base),
            .unary => |unary| try self.collectSymbols(unary.operand),
            .call => |call| for (call.args) |arg| try self.collectSymbols(arg),
            .filter => |filter| {
                try self.collectSymbols(filter.input);
                for (filter.args) |arg| try self.collectSymbols(arg);
            },
            .binary => |binary| {
                try self.collectSymbols(binary.left);
                try self.collectSymbols(binary.right);
            },
            .literal => {},
        }
    }

    fn getSymbolId(self: *Analyzer, name: []const u8) SymbolId {
        for (self.symbols.items) |symbol| if (std.mem.eql(u8, name, symbol.name)) return symbol.id;
        unreachable;
    }

    fn getOrAddSymbol(self: *Analyzer, name: []const u8) std.mem.Allocator.Error!SymbolId {
        for (self.symbols.items) |symbol| {
            if (std.mem.eql(u8, symbol.name, name)) return symbol.id;
        }
        const id = std.math.cast(SymbolId, self.symbols.items.len) orelse unreachable;
        try self.symbols.append(self.allocator, .{ .id = id, .name = name });
        return id;
    }
};

fn firstIdentifier(expr: *const expression.Expression) ?[]const u8 {
    return switch (expr.data) {
        .identifier => |name| name,
        .property => |v| firstIdentifier(v.base),
        .index => |v| firstIdentifier(v.base),
        .unary => |v| firstIdentifier(v.operand),
        .call => |v| if (v.args.len > 0) firstIdentifier(v.args[0]) else null,
        .filter => |v| firstIdentifier(v.input),
        .binary => |v| firstIdentifier(v.left) orelse firstIdentifier(v.right),
        .literal => null,
    };
}

test "assigns first-occurrence root symbol IDs and HTML text context" {
    const source = "{{ name }}<b>{{other}}{{name}}</b>";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const parsed = try parser.parse(allocator, source);
    const document = switch (parsed) {
        .success => |value| value,
        .failure => return error.UnexpectedParseFailure,
    };
    const analyzed = try analyze(allocator, source, document);
    const result = switch (analyzed) {
        .success => |value| value,
        .failure => return error.UnexpectedAnalysisFailure,
    };
    try std.testing.expectEqual(@as(usize, 2), result.symbols.len);
    try std.testing.expectEqualStrings("name", result.symbols[0].name);
    try std.testing.expectEqual(@as(SymbolId, 0), result.expressions[0].symbol_id);
    try std.testing.expectEqual(@as(SymbolId, 1), result.expressions[1].symbol_id);
    try std.testing.expectEqual(@as(SymbolId, 0), result.expressions[2].symbol_id);
    try std.testing.expectEqual(OutputContext.text, result.expressions[0].output_context);
}

test "analyzes attribute interpolations before child expressions with distinct contexts" {
    const source = "<a title=\"{{ name }}\">{{ name }}</a>";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const parsed = try parser.parse(allocator, source);
    const document = switch (parsed) {
        .success => |value| value,
        .failure => return error.UnexpectedParseFailure,
    };
    const analyzed = try analyze(allocator, source, document);
    const result = switch (analyzed) {
        .success => |value| value,
        .failure => return error.UnexpectedAnalysisFailure,
    };

    try std.testing.expectEqual(@as(usize, 2), result.expressions.len);
    try std.testing.expectEqual(OutputContext.attribute, result.expressions[0].output_context);
    try std.testing.expectEqual(OutputContext.text, result.expressions[1].output_context);
    try std.testing.expectEqual(result.expressions[0].symbol_id, result.expressions[1].symbol_id);
}

test "analyzes XML expressions with text and attribute contexts" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const source = "<node title=\"{{ attribute }}\">{{ text }}</node>";
    const document = switch (try parser.parseWithFormat(arena.allocator(), source, .xml)) {
        .success => |value| value,
        .failure => return error.UnexpectedParseFailure,
    };
    const result = try analyze(arena.allocator(), source, document);
    switch (result) {
        .failure => return error.UnexpectedAnalysisFailure,
        .success => |analyzed| {
            try std.testing.expectEqual(OutputContext.attribute, analyzed.expressions[0].output_context);
            try std.testing.expectEqual(OutputContext.text, analyzed.expressions[1].output_context);
        },
    }
}
