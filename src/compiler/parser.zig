//! Lexer and parser for HTML elements, static attributes, and text interpolations.

const std = @import("std");
const zeft = @import("zeft_core");

pub const Token = struct {
    span: zeft.SourceSpan,
    data: Data,

    pub const Data = union(enum) {
        text: []const u8,
        open_element: OpenElement,
        close_element: []const u8,
        expression: zeft.SourceSpan,
    };
};

pub const OpenElement = struct {
    name: []const u8,
    attributes: []Attribute,
    serialized: []const u8,
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
    attributes: []Attribute,
    /// Exact source bytes for the opening tag, including attribute spacing and quoting.
    opening_tag: []const u8,
    children: []Node,
};

pub const Attribute = struct {
    name: []const u8,
    span: zeft.SourceSpan,
    value: ?AttributeValue,
};

pub const AttributeValue = struct {
    quote_style: QuoteStyle,
    span: zeft.SourceSpan,
    segments: []ValueSegment,
};

pub const QuoteStyle = enum {
    single,
    double,
};

pub const ValueSegment = struct {
    span: zeft.SourceSpan,
    data: Data,

    pub const Data = union(enum) {
        text: []const u8,
        expression: zeft.SourceSpan,
    };
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

/// Tokenize the supported language. All spans are half-open byte offsets into source.
pub fn lex(allocator: std.mem.Allocator, source: []const u8) std.mem.Allocator.Error!LexResult {
    var tokens: std.ArrayList(Token) = .empty;
    var lexer = Lexer{ .allocator = allocator, .source = source };

    while (try lexer.next()) |token| {
        try tokens.append(allocator, token);
    }
    if (lexer.failure) |diagnostic| return .{ .failure = diagnostic };
    return .{ .success = try tokens.toOwnedSlice(allocator) };
}

/// Parse HTML elements, static attributes, and text-position interpolation into temporary AST nodes.
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
        const name = self.source[name_start..self.offset];

        if (closing) {
            if (self.offset >= self.source.len or self.source[self.offset] != '>') return self.invalidTag(start);
            self.offset += 1;
            return .{
                .span = .{ .start = start, .end = self.offset },
                .data = .{ .close_element = name },
            };
        }

        var attributes: std.ArrayList(Attribute) = .empty;
        while (self.offset < self.source.len) {
            const whitespace_start = self.offset;
            while (self.offset < self.source.len and isMarkupWhitespace(self.source[self.offset])) : (self.offset += 1) {}
            if (self.offset >= self.source.len) break;
            if (self.source[self.offset] == '>') {
                self.offset += 1;
                return .{
                    .span = .{ .start = start, .end = self.offset },
                    .data = .{ .open_element = .{
                        .name = name,
                        .attributes = try attributes.toOwnedSlice(self.allocator),
                        .serialized = self.source[start..self.offset],
                    } },
                };
            }
            if (self.offset == whitespace_start) return self.invalidTag(start);

            const attribute_start = self.offset;
            while (self.offset < self.source.len and isAttributeNameByte(self.source[self.offset])) : (self.offset += 1) {}
            if (self.offset == attribute_start) return self.invalidTag(start);
            const attribute_name = self.source[attribute_start..self.offset];
            const name_end = self.offset;

            while (self.offset < self.source.len and isMarkupWhitespace(self.source[self.offset])) : (self.offset += 1) {}
            var value: ?AttributeValue = null;
            var attribute_end = name_end;
            if (self.offset < self.source.len and self.source[self.offset] == '=') {
                self.offset += 1;
                while (self.offset < self.source.len and isMarkupWhitespace(self.source[self.offset])) : (self.offset += 1) {}
                if (self.offset >= self.source.len or (self.source[self.offset] != '\'' and self.source[self.offset] != '"')) {
                    return self.invalidTag(start);
                }
                const quote = self.source[self.offset];
                self.offset += 1;
                const value_start = self.offset;
                var segments: std.ArrayList(ValueSegment) = .empty;
                var text_start = value_start;
                while (self.offset < self.source.len and self.source[self.offset] != quote) {
                    if (startsWith(self.source, self.offset, "{{")) {
                        if (self.offset > text_start) try segments.append(self.allocator, .{
                            .span = .{ .start = text_start, .end = self.offset },
                            .data = .{ .text = self.source[text_start..self.offset] },
                        });
                        const expression_start = self.offset;
                        self.offset += 2;
                        const content_start = self.offset;
                        while (self.offset + 1 < self.source.len and !startsWith(self.source, self.offset, "}}")) : (self.offset += 1) {}
                        if (self.offset + 1 >= self.source.len) {
                            self.failure = .{
                                .kind = .invalid_expression,
                                .span = .{ .start = expression_start, .end = self.source.len },
                            };
                            self.offset = self.source.len;
                            return null;
                        }
                        const content_end = self.offset;
                        self.offset += 2;
                        try segments.append(self.allocator, .{
                            .span = .{ .start = expression_start, .end = self.offset },
                            .data = .{ .expression = .{
                                .start = trimStart(self.source, content_start, content_end),
                                .end = trimEnd(self.source, content_start, content_end),
                            } },
                        });
                        text_start = self.offset;
                    } else {
                        self.offset += 1;
                    }
                }
                if (self.offset >= self.source.len) return self.invalidTag(start);
                const value_end = self.offset;
                if (text_start < value_end or segments.items.len == 0) try segments.append(self.allocator, .{
                    .span = .{ .start = text_start, .end = value_end },
                    .data = .{ .text = self.source[text_start..value_end] },
                });
                self.offset += 1;
                attribute_end = self.offset;
                value = .{
                    .quote_style = if (quote == '\'') .single else .double,
                    .span = .{ .start = value_start, .end = value_end },
                    .segments = try segments.toOwnedSlice(self.allocator),
                };
            } else {
                // Leave separating whitespace for the next attribute scan.
                self.offset = name_end;
            }
            try attributes.append(self.allocator, .{
                .name = attribute_name,
                .span = .{ .start = attribute_start, .end = attribute_end },
                .value = value,
            });
        }
        return self.invalidTag(start);
    }

    fn invalidTag(self: *Lexer, start: usize) ?Token {
        while (self.offset < self.source.len and self.source[self.offset] != '>') : (self.offset += 1) {}
        if (self.offset < self.source.len) self.offset += 1;
        self.failure = .{
            .kind = .invalid_markup,
            .span = .{ .start = start, .end = self.offset },
        };
        return null;
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
                .open_element => |opening| {
                    const children = try self.parseChildren(opening.name, token.span);
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
                        .data = .{ .element = .{
                            .name = opening.name,
                            .attributes = opening.attributes,
                            .opening_tag = opening.serialized,
                            .children = children.nodes,
                        } },
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

fn isMarkupWhitespace(byte: u8) bool {
    return byte == ' ' or byte == '\t' or byte == '\r' or byte == '\n' or byte == '\x0c';
}

fn isAttributeNameByte(byte: u8) bool {
    return byte > 0x20 and byte != 0x7f and byte != '>' and byte != '/' and byte != '=' and
        byte != '"' and byte != '\'' and byte != '<' and byte != '`';
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
