//! Format-aware lexer and parser for markup and text interpolations.

const std = @import("std");
const zeft = @import("zeft_core");

pub const Token = struct {
    span: zeft.SourceSpan,
    data: Data,

    pub const Data = union(enum) {
        text: []const u8,
        static_markup: StaticMarkup,
        open_element: OpenElement,
        close_element: []const u8,
        expression: zeft.SourceSpan,
        directive: Directive,
    };
};

pub const Directive = union(enum) {
    if_: zeft.SourceSpan,
    else_,
    endif,
    for_: struct { name: []const u8, name_span: zeft.SourceSpan, expression: zeft.SourceSpan },
    endfor,
    break_,
    continue_,
    include: []const u8,
    unknown,
};

pub const StaticMarkup = struct {
    kind: Kind,
    serialized: []const u8,

    pub const Kind = enum { comment, doctype, cdata, xml_declaration };
};

pub const OpenElement = struct {
    name: []const u8,
    attributes: []Attribute,
    serialized: []const u8,
    self_closing: bool,
};

pub const Node = struct {
    span: zeft.SourceSpan,
    data: Data,

    pub const Data = union(enum) {
        text: []const u8,
        static_markup: StaticMarkup,
        element: Element,
        expression: Expression,
        conditional: Conditional,
        loop: Loop,
        break_,
        continue_,
        include: []const u8,
    };
};

pub const Conditional = struct { condition: zeft.SourceSpan, then_nodes: []Node, else_nodes: []Node };
pub const Loop = struct { name: []const u8, name_span: zeft.SourceSpan, expression: zeft.SourceSpan, children: []Node };

pub const Element = struct {
    name: []const u8,
    attributes: []Attribute,
    /// Exact source bytes for the opening tag, including attribute spacing and quoting.
    opening_tag: []const u8,
    /// Exact source bytes for the closing tag; empty for void and self-closing elements.
    closing_tag: []const u8,
    children: []Node,
    is_void: bool,
    self_closing: bool,
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

/// Tokenize the supported language as HTML. All spans are half-open byte offsets into source.
pub fn lex(allocator: std.mem.Allocator, source: []const u8) std.mem.Allocator.Error!LexResult {
    return lexWithFormat(allocator, source, .html);
}

pub fn lexWithFormat(
    allocator: std.mem.Allocator,
    source: []const u8,
    format: zeft.OutputFormat,
) std.mem.Allocator.Error!LexResult {
    var tokens: std.ArrayList(Token) = .empty;
    var lexer = Lexer{ .allocator = allocator, .source = source, .format = format };

    while (try lexer.next()) |token| {
        try tokens.append(allocator, token);
    }
    if (lexer.failure) |diagnostic| return .{ .failure = diagnostic };
    return .{ .success = try tokens.toOwnedSlice(allocator) };
}

/// Parse HTML elements, attributes, static markup, and text-position interpolation.
pub fn parse(allocator: std.mem.Allocator, source: []const u8) std.mem.Allocator.Error!ParseResult {
    return parseWithFormat(allocator, source, .html);
}

pub fn parseWithFormat(
    allocator: std.mem.Allocator,
    source: []const u8,
    format: zeft.OutputFormat,
) std.mem.Allocator.Error!ParseResult {
    const lexed = try lexWithFormat(allocator, source, format);
    const tokens = switch (lexed) {
        .success => |value| value,
        .failure => |diagnostic| return .{ .failure = diagnostic },
    };

    var parser = Parser{
        .allocator = allocator,
        .source = source,
        .tokens = tokens,
        .format = format,
    };
    const parsed = try parser.parseChildren(null, null, 0);
    if (parser.failure) |diagnostic| return .{ .failure = diagnostic };
    if (parsed.stop != null) return .{ .failure = .{ .kind = .invalid_construct, .span = parsed.stop_span } };
    return .{ .success = .{ .nodes = parsed.nodes } };
}

const Lexer = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    format: zeft.OutputFormat,
    offset: usize = 0,
    xml_1_1: bool = false,
    failure: ?zeft.CompileDiagnostic = null,

    fn next(self: *Lexer) std.mem.Allocator.Error!?Token {
        if (self.offset == self.source.len) return null;
        const start = self.offset;

        if (startsWith(self.source, self.offset, "<!--")) return self.commentToken();
        if (self.format == .html and startsWithAsciiIgnoreCase(self.source, self.offset, "<!doctype")) return self.doctypeToken();
        if (self.format == .xml and startsWith(self.source, self.offset, "<![CDATA[")) return self.cdataToken();
        if (self.format == .xml and startsWith(self.source, self.offset, "<?xml")) return self.xmlDeclarationToken();
        if (startsWith(self.source, self.offset, "<!") or startsWith(self.source, self.offset, "<?")) {
            return self.invalidSpecialMarkup(start);
        }
        if (startsWith(self.source, self.offset, "{{")) return self.expressionToken();
        if (startsWith(self.source, self.offset, "{%")) return self.directiveToken();
        if (startsTag(self.source, self.offset)) return self.tagToken();
        if (self.format == .xml and self.source[self.offset] == '<') return self.invalidSpecialMarkup(start);

        var decoded: std.ArrayList(u8) = .empty;
        while (self.offset < self.source.len) {
            if (self.format == .xml and self.source[self.offset] == '&') {
                const end = xmlReferenceEnd(self.source, self.offset, self.xml_1_1) orelse {
                    self.failure = .{ .kind = .invalid_markup, .span = .{ .start = self.offset, .end = @min(self.offset + 1, self.source.len) } };
                    return null;
                };
                try decoded.appendSlice(self.allocator, self.source[self.offset..end]);
                self.offset = end;
            } else if (self.format == .xml and startsWith(self.source, self.offset, "]]>")) {
                self.failure = .{ .kind = .invalid_markup, .span = .{ .start = self.offset, .end = self.offset + 3 } };
                return null;
            } else if (startsWith(self.source, self.offset, "{{") or startsWith(self.source, self.offset, "{%") or startsTag(self.source, self.offset) or
                startsSpecialMarkup(self.source, self.offset, self.format))
            {
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

    fn directiveToken(self: *Lexer) std.mem.Allocator.Error!?Token {
        const start = self.offset;
        self.offset += 2;
        const content_start = self.offset;
        while (self.offset + 1 < self.source.len and !startsWith(self.source, self.offset, "%}")) : (self.offset += 1) {}
        if (self.offset + 1 >= self.source.len) {
            self.failure = .{ .kind = .syntax, .span = .{ .start = start, .end = self.source.len } };
            return null;
        }
        const content_end = self.offset;
        self.offset += 2;
        const content = trimSpan(self.source, content_start, content_end);
        const bytes = self.source[content.start..content.end];
        var directive: Directive = .unknown;
        if (std.mem.startsWith(u8, bytes, "if ")) {
            directive = .{ .if_ = trimSpan(self.source, content.start + 3, content.end) };
        } else if (std.mem.eql(u8, bytes, "else")) {
            directive = .else_;
        } else if (std.mem.eql(u8, bytes, "endif")) {
            directive = .endif;
        } else if (std.mem.eql(u8, bytes, "endfor")) {
            directive = .endfor;
        } else if (std.mem.eql(u8, bytes, "break")) {
            directive = .break_;
        } else if (std.mem.eql(u8, bytes, "continue")) {
            directive = .continue_;
        } else if (std.mem.startsWith(u8, bytes, "include ")) {
            const path = trimSpan(self.source, content.start + "include ".len, content.end);
            if (path.end - path.start >= 2 and self.source[path.start] == '"' and self.source[path.end - 1] == '"' and
                std.mem.indexOfScalar(u8, self.source[path.start + 1 .. path.end - 1], '"') == null)
            {
                directive = .{ .include = self.source[path.start + 1 .. path.end - 1] };
            }
        } else if (std.mem.startsWith(u8, bytes, "for ")) {
            const rest_start = content.start + 4;
            const in_index = std.mem.indexOf(u8, self.source[rest_start..content.end], " in ");
            if (in_index) |found| {
                const name_span = trimSpan(self.source, rest_start, rest_start + found);
                const expr_span = trimSpan(self.source, rest_start + found + 4, content.end);
                if (validIdentifier(self.source[name_span.start..name_span.end]) and expr_span.start < expr_span.end) {
                    directive = .{ .for_ = .{ .name = self.source[name_span.start..name_span.end], .name_span = name_span, .expression = expr_span } };
                }
            }
        }
        return .{ .span = .{ .start = start, .end = self.offset }, .data = .{ .directive = directive } };
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
            .data = .{ .expression = trimSpan(self.source, content_start, content_end) },
        };
    }

    fn commentToken(self: *Lexer) std.mem.Allocator.Error!?Token {
        const start = self.offset;
        self.offset += "<!--".len;
        while (self.offset + "-->".len <= self.source.len and !startsWith(self.source, self.offset, "-->")) : (self.offset += 1) {
            if (self.format == .xml and startsWith(self.source, self.offset, "--")) {
                self.failure = .{
                    .kind = .invalid_markup,
                    .span = .{ .start = start, .end = self.offset + 2 },
                };
                return null;
            }
        }
        if (self.offset + "-->".len > self.source.len) {
            self.failure = .{
                .kind = .invalid_markup,
                .span = .{ .start = start, .end = self.source.len },
            };
            self.offset = self.source.len;
            return null;
        }
        if (self.format == .xml and self.offset > start + "<!--".len and self.source[self.offset - 1] == '-') {
            self.failure = .{
                .kind = .invalid_markup,
                .span = .{ .start = start, .end = self.offset + "-->".len },
            };
            return null;
        }
        self.offset += "-->".len;
        return .{
            .span = .{ .start = start, .end = self.offset },
            .data = .{ .static_markup = .{ .kind = .comment, .serialized = self.source[start..self.offset] } },
        };
    }

    fn cdataToken(self: *Lexer) std.mem.Allocator.Error!?Token {
        const start = self.offset;
        self.offset += "<![CDATA[".len;
        while (self.offset + "]]>".len <= self.source.len and !startsWith(self.source, self.offset, "]]>")) : (self.offset += 1) {}
        if (self.offset + "]]>".len > self.source.len) {
            self.failure = .{
                .kind = .invalid_markup,
                .span = .{ .start = start, .end = self.source.len },
            };
            self.offset = self.source.len;
            return null;
        }
        self.offset += "]]>".len;
        return .{
            .span = .{ .start = start, .end = self.offset },
            .data = .{ .static_markup = .{ .kind = .cdata, .serialized = self.source[start..self.offset] } },
        };
    }

    fn xmlDeclarationToken(self: *Lexer) std.mem.Allocator.Error!?Token {
        const start = self.offset;
        if (start != 0) return self.invalidSpecialMarkup(start);
        self.offset += "<?xml".len;
        if (self.offset >= self.source.len or !isMarkupWhitespace(self.source[self.offset])) return self.invalidSpecialMarkup(start);
        while (self.offset < self.source.len and isMarkupWhitespace(self.source[self.offset])) : (self.offset += 1) {}

        const version = self.xmlPseudoAttribute(start) orelse return null;
        if (!std.mem.eql(u8, version.name, "version") or
            !(std.mem.eql(u8, version.value, "1.0") or std.mem.eql(u8, version.value, "1.1")))
        {
            return self.invalidSpecialMarkup(start);
        }
        self.xml_1_1 = std.mem.eql(u8, version.value, "1.1");

        var encoding_seen = false;
        var standalone_seen = false;
        while (true) {
            if (startsWith(self.source, self.offset, "?>")) {
                self.offset += 2;
                return .{
                    .span = .{ .start = start, .end = self.offset },
                    .data = .{ .static_markup = .{ .kind = .xml_declaration, .serialized = self.source[start..self.offset] } },
                };
            }
            if (self.offset >= self.source.len or !isMarkupWhitespace(self.source[self.offset])) return self.invalidSpecialMarkup(start);
            while (self.offset < self.source.len and isMarkupWhitespace(self.source[self.offset])) : (self.offset += 1) {}
            if (startsWith(self.source, self.offset, "?>")) continue;

            const attribute = self.xmlPseudoAttribute(start) orelse return null;
            if (std.mem.eql(u8, attribute.name, "encoding")) {
                if (encoding_seen or standalone_seen or !isValidXmlEncoding(attribute.value)) return self.invalidSpecialMarkup(start);
                encoding_seen = true;
            } else if (std.mem.eql(u8, attribute.name, "standalone")) {
                if (standalone_seen or !(std.mem.eql(u8, attribute.value, "yes") or std.mem.eql(u8, attribute.value, "no"))) {
                    return self.invalidSpecialMarkup(start);
                }
                standalone_seen = true;
            } else {
                return self.invalidSpecialMarkup(start);
            }
        }
    }

    fn xmlPseudoAttribute(self: *Lexer, tag_start: usize) ?XmlPseudoAttribute {
        const name_start = self.offset;
        if (self.offset >= self.source.len or !std.ascii.isAlphabetic(self.source[self.offset])) {
            _ = self.invalidSpecialMarkup(tag_start);
            return null;
        }
        self.offset += 1;
        while (self.offset < self.source.len and std.ascii.isAlphabetic(self.source[self.offset])) : (self.offset += 1) {}
        const name = self.source[name_start..self.offset];
        while (self.offset < self.source.len and isMarkupWhitespace(self.source[self.offset])) : (self.offset += 1) {}
        if (self.offset >= self.source.len or self.source[self.offset] != '=') {
            _ = self.invalidSpecialMarkup(tag_start);
            return null;
        }
        self.offset += 1;
        while (self.offset < self.source.len and isMarkupWhitespace(self.source[self.offset])) : (self.offset += 1) {}
        if (self.offset >= self.source.len or (self.source[self.offset] != '\'' and self.source[self.offset] != '"')) {
            _ = self.invalidSpecialMarkup(tag_start);
            return null;
        }
        const quote = self.source[self.offset];
        self.offset += 1;
        const value_start = self.offset;
        while (self.offset < self.source.len and self.source[self.offset] != quote) : (self.offset += 1) {}
        if (self.offset >= self.source.len) {
            _ = self.invalidSpecialMarkup(tag_start);
            return null;
        }
        const value = self.source[value_start..self.offset];
        self.offset += 1;
        return .{ .name = name, .value = value };
    }

    fn doctypeToken(self: *Lexer) std.mem.Allocator.Error!?Token {
        const start = self.offset;
        self.offset += "<!doctype".len;
        if (self.offset >= self.source.len or !isMarkupWhitespace(self.source[self.offset])) return self.invalidSpecialMarkup(start);
        while (self.offset < self.source.len and isMarkupWhitespace(self.source[self.offset])) : (self.offset += 1) {}
        if (!startsWithAsciiIgnoreCase(self.source, self.offset, "html")) return self.invalidSpecialMarkup(start);
        self.offset += "html".len;
        if (self.offset < self.source.len and self.source[self.offset] != '>' and !isMarkupWhitespace(self.source[self.offset])) {
            return self.invalidSpecialMarkup(start);
        }
        while (self.offset < self.source.len and isMarkupWhitespace(self.source[self.offset])) : (self.offset += 1) {}
        if (self.offset >= self.source.len or self.source[self.offset] != '>') return self.invalidSpecialMarkup(start);
        self.offset += 1;
        return .{
            .span = .{ .start = start, .end = self.offset },
            .data = .{ .static_markup = .{ .kind = .doctype, .serialized = self.source[start..self.offset] } },
        };
    }

    fn invalidSpecialMarkup(self: *Lexer, start: usize) ?Token {
        while (self.offset < self.source.len and self.source[self.offset] != '>') : (self.offset += 1) {}
        if (self.offset < self.source.len) self.offset += 1;
        self.failure = .{
            .kind = .invalid_markup,
            .span = .{ .start = start, .end = self.offset },
        };
        return null;
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
            if (self.source[self.offset] == '/') {
                self.offset += 1;
                if (self.offset >= self.source.len or self.source[self.offset] != '>') return self.invalidTag(start);
                self.offset += 1;
                return .{
                    .span = .{ .start = start, .end = self.offset },
                    .data = .{ .open_element = .{
                        .name = name,
                        .attributes = try attributes.toOwnedSlice(self.allocator),
                        .serialized = self.source[start..self.offset],
                        .self_closing = true,
                    } },
                };
            }
            if (self.source[self.offset] == '>') {
                self.offset += 1;
                return .{
                    .span = .{ .start = start, .end = self.offset },
                    .data = .{ .open_element = .{
                        .name = name,
                        .attributes = try attributes.toOwnedSlice(self.allocator),
                        .serialized = self.source[start..self.offset],
                        .self_closing = false,
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
                    if (self.format == .xml and self.source[self.offset] == '<') return self.invalidTag(start);
                    if (self.format == .xml and self.source[self.offset] == '&') {
                        self.offset = xmlReferenceEnd(self.source, self.offset, self.xml_1_1) orelse return self.invalidTag(start);
                        continue;
                    }
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
                            .data = .{ .expression = trimSpan(self.source, content_start, content_end) },
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
            if (self.format == .xml and value == null) return self.invalidTag(start);
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

const XmlPseudoAttribute = struct {
    name: []const u8,
    value: []const u8,
};

const ParsedChildren = struct {
    nodes: []Node,
    close_span: ?zeft.SourceSpan,
    stop: ?Directive = null,
    stop_span: ?zeft.SourceSpan = null,
};

const Parser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    tokens: []const Token,
    format: zeft.OutputFormat,
    index: usize = 0,
    failure: ?zeft.CompileDiagnostic = null,

    fn parseChildren(
        self: *Parser,
        parent_name: ?[]const u8,
        parent_span: ?zeft.SourceSpan,
        loop_depth: usize,
    ) std.mem.Allocator.Error!ParsedChildren {
        var nodes: std.ArrayList(Node) = .empty;
        while (self.index < self.tokens.len and self.failure == null) {
            const token = self.tokens[self.index];
            self.index += 1;
            switch (token.data) {
                .text => |text| try nodes.append(self.allocator, .{ .span = token.span, .data = .{ .text = text } }),
                .static_markup => |markup| try nodes.append(self.allocator, .{
                    .span = token.span,
                    .data = .{ .static_markup = markup },
                }),
                .expression => |expression_span| try nodes.append(self.allocator, .{
                    .span = token.span,
                    .data = .{ .expression = .{ .source_span = expression_span } },
                }),
                .directive => |directive| switch (directive) {
                    .else_, .endif, .endfor => return .{ .nodes = try nodes.toOwnedSlice(self.allocator), .close_span = null, .stop = directive, .stop_span = token.span },
                    .if_ => |condition| {
                        const then_result = try self.parseChildren(parent_name, parent_span, loop_depth);
                        if (self.failure != null) break;
                        var else_nodes: []Node = &.{};
                        const end_span = if (then_result.stop) |stop| switch (stop) {
                            .else_ => blk: {
                                const else_result = try self.parseChildren(parent_name, parent_span, loop_depth);
                                if (self.failure != null) break;
                                if (!isEndIf(else_result.stop)) {
                                    self.failure = .{ .kind = .invalid_construct, .span = else_result.stop_span orelse token.span };
                                    break;
                                }
                                else_nodes = else_result.nodes;
                                break :blk else_result.stop_span.?;
                            },
                            .endif => then_result.stop_span.?,
                            else => {
                                self.failure = .{ .kind = .invalid_construct, .span = token.span };
                                break;
                            },
                        } else {
                            self.failure = .{ .kind = .invalid_construct, .span = token.span };
                            break;
                        };
                        try nodes.append(self.allocator, .{ .span = .{ .start = token.span.start, .end = end_span.end }, .data = .{ .conditional = .{ .condition = condition, .then_nodes = then_result.nodes, .else_nodes = else_nodes } } });
                    },
                    .for_ => |loop| {
                        const body = try self.parseChildren(parent_name, parent_span, loop_depth + 1);
                        if (self.failure != null) break;
                        if (!isEndFor(body.stop)) {
                            self.failure = .{ .kind = .invalid_construct, .span = body.stop_span orelse token.span };
                            break;
                        }
                        try nodes.append(self.allocator, .{ .span = .{ .start = token.span.start, .end = body.stop_span.?.end }, .data = .{ .loop = .{ .name = loop.name, .name_span = loop.name_span, .expression = loop.expression, .children = body.nodes } } });
                    },
                    .break_ => {
                        if (loop_depth == 0) {
                            self.failure = .{ .kind = .invalid_construct, .span = token.span };
                            break;
                        }
                        try nodes.append(self.allocator, .{ .span = token.span, .data = .break_ });
                    },
                    .continue_ => {
                        if (loop_depth == 0) {
                            self.failure = .{ .kind = .invalid_construct, .span = token.span };
                            break;
                        }
                        try nodes.append(self.allocator, .{ .span = token.span, .data = .continue_ });
                    },
                    .include => |path| try nodes.append(self.allocator, .{ .span = token.span, .data = .{ .include = path } }),
                    .unknown => {
                        self.failure = .{ .kind = .syntax, .span = token.span };
                        break;
                    },
                },
                .close_element => |name| {
                    if (parent_name) |expected| {
                        const names_match = if (self.format == .html)
                            std.ascii.eqlIgnoreCase(name, expected)
                        else
                            std.mem.eql(u8, name, expected);
                        if (!names_match) {
                            self.failure = .{ .kind = .invalid_markup, .span = token.span };
                            break;
                        }
                        return .{ .nodes = try nodes.toOwnedSlice(self.allocator), .close_span = token.span };
                    }
                    self.failure = .{ .kind = .invalid_markup, .span = token.span };
                    break;
                },
                .open_element => |opening| {
                    const is_void = self.format == .html and isHtmlVoidElement(opening.name);
                    if (self.format == .html and opening.self_closing and !is_void) {
                        self.failure = .{ .kind = .invalid_markup, .span = token.span };
                        break;
                    }
                    if (is_void or opening.self_closing) {
                        try nodes.append(self.allocator, .{
                            .span = token.span,
                            .data = .{ .element = .{
                                .name = opening.name,
                                .attributes = opening.attributes,
                                .opening_tag = opening.serialized,
                                .closing_tag = "",
                                .children = &.{},
                                .is_void = is_void,
                                .self_closing = opening.self_closing,
                            } },
                        });
                        continue;
                    }
                    const children = try self.parseChildren(opening.name, token.span, loop_depth);
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
                            .closing_tag = self.source[close_span.start..close_span.end],
                            .children = children.nodes,
                            .is_void = false,
                            .self_closing = false,
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

fn isHtmlVoidElement(name: []const u8) bool {
    const void_names = .{
        "area",  "base", "br",   "col",   "embed",  "hr",    "img",
        "input", "link", "meta", "param", "source", "track", "wbr",
    };
    inline for (void_names) |void_name| {
        if (std.ascii.eqlIgnoreCase(name, void_name)) return true;
    }
    return false;
}

fn startsWith(source: []const u8, offset: usize, needle: []const u8) bool {
    return offset <= source.len and std.mem.startsWith(u8, source[offset..], needle);
}

fn startsWithAsciiIgnoreCase(source: []const u8, offset: usize, needle: []const u8) bool {
    return offset <= source.len and source.len - offset >= needle.len and
        std.ascii.eqlIgnoreCase(source[offset .. offset + needle.len], needle);
}

fn isValidXmlEncoding(value: []const u8) bool {
    if (value.len == 0 or !std.ascii.isAlphabetic(value[0])) return false;
    for (value[1..]) |byte| {
        if (!std.ascii.isAlphanumeric(byte) and byte != '.' and byte != '_' and byte != '-') return false;
    }
    return true;
}

fn xmlReferenceEnd(source: []const u8, start: usize, xml_1_1: bool) ?usize {
    if (start >= source.len or source[start] != '&') return null;
    var end = start + 1;
    while (end < source.len and source[end] != ';') : (end += 1) {
        if (source[end] == '&' or source[end] == '<' or isMarkupWhitespace(source[end])) return null;
    }
    if (end == source.len or end == start + 1) return null;
    const body = source[start + 1 .. end];
    if (std.mem.eql(u8, body, "amp") or std.mem.eql(u8, body, "lt") or std.mem.eql(u8, body, "gt") or
        std.mem.eql(u8, body, "apos") or std.mem.eql(u8, body, "quot")) return end + 1;

    if (body[0] != '#') return null;
    var digits = body[1..];
    var base: u8 = 10;
    if (digits.len > 0 and digits[0] == 'x') {
        base = 16;
        digits = digits[1..];
    }
    if (digits.len == 0) return null;
    var codepoint: u32 = 0;
    for (digits) |digit| {
        const value: u32 = if (digit >= '0' and digit <= '9')
            digit - '0'
        else if (base == 16 and digit >= 'a' and digit <= 'f')
            digit - 'a' + 10
        else if (base == 16 and digit >= 'A' and digit <= 'F')
            digit - 'A' + 10
        else
            return null;
        codepoint = std.math.mul(u32, codepoint, base) catch return null;
        codepoint = std.math.add(u32, codepoint, value) catch return null;
    }
    if (!isXmlCharacter(codepoint, xml_1_1)) return null;
    return end + 1;
}

fn isXmlCharacter(codepoint: u32, xml_1_1: bool) bool {
    if (xml_1_1) return (codepoint >= 0x1 and codepoint <= 0xD7FF) or
        (codepoint >= 0xE000 and codepoint <= 0xFFFD) or
        (codepoint >= 0x10000 and codepoint <= 0x10FFFF);
    return codepoint == 0x9 or codepoint == 0xA or codepoint == 0xD or
        (codepoint >= 0x20 and codepoint <= 0xD7FF) or
        (codepoint >= 0xE000 and codepoint <= 0xFFFD) or
        (codepoint >= 0x10000 and codepoint <= 0x10FFFF);
}

fn startsTag(source: []const u8, offset: usize) bool {
    if (offset >= source.len or source[offset] != '<') return false;
    var name_offset = offset + 1;
    if (name_offset < source.len and source[name_offset] == '/') name_offset += 1;
    return name_offset < source.len and isNameStart(source[name_offset]);
}

fn startsSpecialMarkup(source: []const u8, offset: usize, format: zeft.OutputFormat) bool {
    if (format == .xml and offset < source.len and source[offset] == '<') return true;
    if (startsWith(source, offset, "<!") or startsWith(source, offset, "<?")) return true;
    return format == .html and startsWith(source, offset, "<!doctype") or
        format == .xml and (startsWith(source, offset, "<![CDATA[") or startsWith(source, offset, "<?xml"));
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

fn trimSpan(source: []const u8, start: usize, end: usize) zeft.SourceSpan {
    const trimmed_start = trimStart(source, start, end);
    return .{ .start = trimmed_start, .end = trimEnd(source, trimmed_start, end) };
}

fn validIdentifier(value: []const u8) bool {
    if (value.len == 0 or !isIdentifierStart(value[0])) return false;
    for (value[1..]) |byte| if (!isIdentifierContinue(byte)) return false;
    return true;
}

fn isIdentifierStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}
fn isIdentifierContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn isEndIf(directive: ?Directive) bool {
    if (directive) |value| return switch (value) {
        .endif => true,
        else => false,
    };
    return false;
}

fn isEndFor(directive: ?Directive) bool {
    if (directive) |value| return switch (value) {
        .endfor => true,
        else => false,
    };
    return false;
}
