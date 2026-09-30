//! Phase 1 lexer and parser for static HTML elements and text interpolations.

const std = @import("std");
const zeft = @import("zeft_core");

pub const Token = struct {
    span: zeft.SourceSpan,
    data: Data,

    pub const Data = union(enum) {
        text: []const u8,
        open_element: []const u8,
        close_element: []const u8,
        expression: zeft.SourceSpan,
    };
};

pub const Node = struct {
    span: zeft.SourceSpan,
    data: Data,

    pub const Data = union(enum) {
        text: []const u8,
        element: Element,
        expression: Expression,
    };
};

pub const Element = struct {
    name: []const u8,
    children: []Node,
};

pub const Expression = struct {
    /// The trimmed expression bytes, retained as a source span rather than copied.
    source_span: zeft.SourceSpan,
};

pub const Document = struct {
    nodes: []Node,
};

pub const LexResult = union(enum) {
    success: []Token,
    failure: zeft.CompileDiagnostic,
};

pub const ParseResult = union(enum) {
    success: Document,
    failure: zeft.CompileDiagnostic,
};

/// Tokenize the Phase 1 language. All spans are half-open byte offsets into source.
pub fn lex(allocator: std.mem.Allocator, source: []const u8) std.mem.Allocator.Error!LexResult {
    var tokens: std.ArrayList(Token) = .empty;
    var lexer = Lexer{ .allocator = allocator, .source = source };

    while (try lexer.next()) |token| {
        try tokens.append(allocator, token);
    }
    if (lexer.failure) |diagnostic| return .{ .failure = diagnostic };
    return .{ .success = try tokens.toOwnedSlice(allocator) };
}

/// Parse static HTML elements and text-position interpolation into temporary AST nodes.
pub fn parse(allocator: std.mem.Allocator, source: []const u8) std.mem.Allocator.Error!ParseResult {
    const lexed = try lex(allocator, source);
    const tokens = switch (lexed) {
        .success => |value| value,
        .failure => |diagnostic| return .{ .failure = diagnostic },
    };

    var parser = Parser{
        .allocator = allocator,
        .source = source,
        .tokens = tokens,
    };
    const parsed = try parser.parseChildren(null, null);
    if (parser.failure) |diagnostic| return .{ .failure = diagnostic };
    return .{ .success = .{ .nodes = parsed.nodes } };
}

const Lexer = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    offset: usize = 0,
    failure: ?zeft.CompileDiagnostic = null,

    fn next(self: *Lexer) std.mem.Allocator.Error!?Token {
        if (self.offset == self.source.len) return null;
        const start = self.offset;

        if (startsWith(self.source, self.offset, "{{")) return self.expressionToken();
        if (startsTag(self.source, self.offset)) return self.tagToken();

        var decoded: std.ArrayList(u8) = .empty;
        while (self.offset < self.source.len) {
            if (startsWith(self.source, self.offset, "\\\\")) {
                try decoded.append(self.allocator, '\\');
                self.offset += 2;
            } else if (startsWith(self.source, self.offset, "\\{{")) {
                try decoded.appendSlice(self.allocator, "{{");
                self.offset += 3;
            } else if (startsWith(self.source, self.offset, "{{") or startsTag(self.source, self.offset)) {
                break;
            } else {
                try decoded.append(self.allocator, self.source[self.offset]);
                self.offset += 1;
            }
        }

        // A construct at the current offset is emitted by the next invocation.
        if (self.offset == start) return self.next();
        return .{
            .span = .{ .start = start, .end = self.offset },
            .data = .{ .text = try decoded.toOwnedSlice(self.allocator) },
        };
    }

    fn expressionToken(self: *Lexer) std.mem.Allocator.Error!?Token {
        const start = self.offset;
        self.offset += 2;
        const content_start = self.offset;
        while (self.offset + 1 < self.source.len and !startsWith(self.source, self.offset, "}}")) : (self.offset += 1) {}
        if (self.offset + 1 >= self.source.len) {
            self.failure = .{
                .kind = .invalid_expression,
                .span = .{ .start = start, .end = self.source.len },
            };
            self.offset = self.source.len;
            return null;
        }

        const content_end = self.offset;
        self.offset += 2;
        return .{
            .span = .{ .start = start, .end = self.offset },
            .data = .{ .expression = .{
                .start = trimStart(self.source, content_start, content_end),
                .end = trimEnd(self.source, content_start, content_end),
            } },
        };
    }

    fn tagToken(self: *Lexer) std.mem.Allocator.Error!?Token {
        const start = self.offset;
        const closing = self.source[self.offset + 1] == '/';
        self.offset += if (closing) @as(usize, 2) else 1;
        const name_start = self.offset;

        if (self.offset >= self.source.len or !isNameStart(self.source[self.offset])) {
            self.failure = .{
                .kind = .invalid_markup,
                .span = .{ .start = start, .end = @min(start + 2, self.source.len) },
            };
            return null;
        }
        self.offset += 1;
        while (self.offset < self.source.len and isNameContinue(self.source[self.offset])) : (self.offset += 1) {}
        const name_end = self.offset;

        if (self.offset >= self.source.len or self.source[self.offset] != '>') {
            while (self.offset < self.source.len and self.source[self.offset] != '>') : (self.offset += 1) {}
            if (self.offset < self.source.len) self.offset += 1;
            self.failure = .{
                .kind = .invalid_markup,
                .span = .{ .start = start, .end = self.offset },
            };
            return null;
        }
        self.offset += 1;
        const name = self.source[name_start..name_end];
        return .{
            .span = .{ .start = start, .end = self.offset },
            .data = if (closing) .{ .close_element = name } else .{ .open_element = name },
        };
    }
};

const ParsedChildren = struct {
    nodes: []Node,
    close_span: ?zeft.SourceSpan,
};

const Parser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    tokens: []const Token,
    index: usize = 0,
    failure: ?zeft.CompileDiagnostic = null,

    fn parseChildren(
        self: *Parser,
        parent_name: ?[]const u8,
        parent_span: ?zeft.SourceSpan,
    ) std.mem.Allocator.Error!ParsedChildren {
        var nodes: std.ArrayList(Node) = .empty;
        while (self.index < self.tokens.len and self.failure == null) {
            const token = self.tokens[self.index];
            self.index += 1;
            switch (token.data) {
                .text => |text| try nodes.append(self.allocator, .{ .span = token.span, .data = .{ .text = text } }),
                .expression => |expression_span| try nodes.append(self.allocator, .{
                    .span = token.span,
                    .data = .{ .expression = .{ .source_span = expression_span } },
                }),
                .close_element => |name| {
                    if (parent_name) |expected| {
                        if (!std.ascii.eqlIgnoreCase(name, expected)) {
                            self.failure = .{ .kind = .invalid_markup, .span = token.span };
                            break;
                        }
                        return .{ .nodes = try nodes.toOwnedSlice(self.allocator), .close_span = token.span };
                    }
                    self.failure = .{ .kind = .invalid_markup, .span = token.span };
                    break;
                },
                .open_element => |name| {
                    const children = try self.parseChildren(name, token.span);
                    if (self.failure != null) break;
                    const close_span = children.close_span orelse {
                        self.failure = .{
                            .kind = .invalid_markup,
                            .span = parent_span orelse token.span,
                        };
                        break;
                    };
                    try nodes.append(self.allocator, .{
                        .span = .{ .start = token.span.start, .end = close_span.end },
                        .data = .{ .element = .{ .name = name, .children = children.nodes } },
                    });
                },
            }
        }

        if (self.failure != null) return .{ .nodes = &.{}, .close_span = null };
        if (parent_name != null) {
            self.failure = .{
                .kind = .invalid_markup,
                .span = parent_span orelse .{ .start = self.source.len, .end = self.source.len },
            };
        }
        return .{ .nodes = try nodes.toOwnedSlice(self.allocator), .close_span = null };
    }
};

fn startsWith(source: []const u8, offset: usize, needle: []const u8) bool {
    return offset <= source.len and std.mem.startsWith(u8, source[offset..], needle);
}

fn startsTag(source: []const u8, offset: usize) bool {
    if (offset >= source.len or source[offset] != '<') return false;
    var name_offset = offset + 1;
    if (name_offset < source.len and source[name_offset] == '/') name_offset += 1;
    return name_offset < source.len and isNameStart(source[name_offset]);
}

fn isNameStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isNameContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_' or byte == '-' or byte == ':' or byte == '.';
}

fn isExpressionWhitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t' or byte == '\r' or byte == '\n';
}

fn trimStart(source: []const u8, start: usize, end: usize) usize {
    var offset = start;
    while (offset < end and isExpressionWhitespace(source[offset])) : (offset += 1) {}
    return offset;
}

fn trimEnd(source: []const u8, start: usize, end: usize) usize {
    var offset = end;
    while (offset > start and isExpressionWhitespace(source[offset - 1])) : (offset -= 1) {}
    return offset;
}
