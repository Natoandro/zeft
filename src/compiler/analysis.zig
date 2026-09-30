//! Semantic analysis for the Phase 1 template AST.

const std = @import("std");
const zeft = @import("zeft_core");
const parser = @import("zeft_parser");
const expression = @import("zeft_expression");

pub const SymbolId = u32;

pub const OutputContext = enum {
    html_text,
};

pub const Symbol = struct {
    id: SymbolId,
    name: []const u8,
};

pub const AnalyzedExpression = struct {
    identifier: expression.Identifier,
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
    format: zeft.OutputFormat,
) std.mem.Allocator.Error!AnalyzeResult {
    if (format == .xml) return .{ .failure = .{
        .kind = .unsupported_syntax,
        .span = .{ .start = 0, .end = source.len },
    } };

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
                .text => {},
                .element => |element| try self.visit(element.children),
                .expression => |expr| {
                    const parsed = expression.parse(self.source, expr.source_span);
                    const identifier = switch (parsed) {
                        .success => |value| value,
                        .failure => |diagnostic| {
                            self.failure = diagnostic;
                            return;
                        },
                    };
                    const symbol_id = try self.getOrAddSymbol(identifier.name);
                    try self.expressions.append(self.allocator, .{
                        .identifier = identifier,
                        .symbol_id = symbol_id,
                        .output_context = .html_text,
                    });
                },
            }
        }
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
    const analyzed = try analyze(allocator, source, document, .html);
    const result = switch (analyzed) {
        .success => |value| value,
        .failure => return error.UnexpectedAnalysisFailure,
    };
    try std.testing.expectEqual(@as(usize, 2), result.symbols.len);
    try std.testing.expectEqualStrings("name", result.symbols[0].name);
    try std.testing.expectEqual(@as(SymbolId, 0), result.expressions[0].symbol_id);
    try std.testing.expectEqual(@as(SymbolId, 1), result.expressions[1].symbol_id);
    try std.testing.expectEqual(@as(SymbolId, 0), result.expressions[2].symbol_id);
    try std.testing.expectEqual(OutputContext.html_text, result.expressions[0].output_context);
}

test "rejects XML mode for the Phase 1 analyzer" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try analyze(arena.allocator(), "<p/>", .{ .nodes = &.{} }, .xml);
    switch (result) {
        .success => return error.ExpectedDiagnostic,
        .failure => |diagnostic| {
            try std.testing.expectEqual(zeft.CompileErrorKind.unsupported_syntax, diagnostic.kind);
            try std.testing.expectEqual(@as(?zeft.SourceSpan, .{ .start = 0, .end = 4 }), diagnostic.span);
        },
    }
}
