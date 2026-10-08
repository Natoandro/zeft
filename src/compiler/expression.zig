//! Parser for template expressions.

const std = @import("std");
const zeft = @import("zeft_core");

pub const Operator = enum { not, negate, or_, and_, equal, not_equal, less, less_equal, greater, greater_equal, add, subtract, multiply, divide, modulo };
pub const Literal = union(enum) { null, boolean: bool, number: f64, string: []const u8 };
pub const Expression = struct {
    span: zeft.SourceSpan,
    data: Data,
    pub const Data = union(enum) {
        literal: Literal,
        identifier: []const u8,
        property: struct { base: *Expression, name: []const u8, selector_span: zeft.SourceSpan },
        index: struct { base: *Expression, value: usize, selector_span: zeft.SourceSpan },
        unary: struct { op: Operator, operand: *Expression },
        binary: struct { op: Operator, left: *Expression, right: *Expression },
    };
};
pub const ParseResult = union(enum) { success: Expression, failure: zeft.CompileDiagnostic };

pub fn parse(allocator: std.mem.Allocator, source: []const u8, span: zeft.SourceSpan) std.mem.Allocator.Error!ParseResult {
    if (!span.isValid(source.len) or span.start == span.end) return invalid(span);
    var p = Parser{ .allocator = allocator, .source = source, .start = span.start, .end = span.end, .offset = span.start };
    p.skipSpace();
    const root = (try p.parseBinary(1)) orelse return invalid(.{ .start = p.offset, .end = @min(p.offset + 1, span.end) });
    p.skipSpace();
    if (p.offset != span.end) return invalid(.{ .start = p.offset, .end = span.end });
    return .{ .success = root.* };
}

const Parser = struct {
    allocator: std.mem.Allocator,
    source: []const u8,
    start: usize,
    end: usize,
    offset: usize,
    fn make(self: *Parser, span: zeft.SourceSpan, data: Expression.Data) std.mem.Allocator.Error!*Expression {
        const result = try self.allocator.create(Expression);
        result.* = .{ .span = span, .data = data };
        return result;
    }
    fn skipSpace(self: *Parser) void {
        while (self.offset < self.end and std.ascii.isWhitespace(self.source[self.offset])) : (self.offset += 1) {}
    }
    fn parseBinary(self: *Parser, min_prec: u8) std.mem.Allocator.Error!?*Expression {
        var lhs = (try self.parseUnary()) orelse return null;
        while (true) {
            self.skipSpace();
            const found = self.binaryOperator() orelse break;
            if (found.precedence < min_prec) break;
            self.offset += found.length;
            const rhs = (try self.parseBinary(found.precedence + 1)) orelse return null;
            lhs = try self.make(.{ .start = lhs.span.start, .end = rhs.span.end }, .{ .binary = .{ .op = found.op, .left = lhs, .right = rhs } });
        }
        return lhs;
    }
    fn parseUnary(self: *Parser) std.mem.Allocator.Error!?*Expression {
        self.skipSpace();
        if (self.offset >= self.end) return null;
        const begin = self.offset;
        if (self.source[self.offset] == '!' or self.source[self.offset] == '-') {
            const byte = self.source[self.offset];
            self.offset += 1;
            const operand = (try self.parseUnary()) orelse return null;
            return try self.make(.{ .start = begin, .end = operand.span.end }, .{ .unary = .{ .op = if (byte == '!') .not else .negate, .operand = operand } });
        }
        return self.parsePrimary();
    }
    fn parsePrimary(self: *Parser) std.mem.Allocator.Error!?*Expression {
        self.skipSpace();
        if (self.offset >= self.end) return null;
        const begin = self.offset;
        const ch = self.source[self.offset];
        var value: *Expression = undefined;
        if (ch == '(') {
            self.offset += 1;
            value = (try self.parseBinary(1)) orelse return null;
            self.skipSpace();
            if (self.offset >= self.end or self.source[self.offset] != ')') return null;
            self.offset += 1;
        } else if (ch == '\'' or ch == '"') {
            self.offset += 1;
            var bytes: std.ArrayList(u8) = .empty;
            while (self.offset < self.end and self.source[self.offset] != ch) : (self.offset += 1) {
                var b = self.source[self.offset];
                if (b == '\n' or b == '\r') return null;
                if (b == '\\') {
                    self.offset += 1;
                    if (self.offset >= self.end) return null;
                    b = switch (self.source[self.offset]) {
                        '\\' => '\\',
                        '\'' => '\'',
                        '"' => '"',
                        'n' => '\n',
                        'r' => '\r',
                        't' => '\t',
                        else => return null,
                    };
                }
                try bytes.append(self.allocator, b);
            }
            if (self.offset >= self.end) return null;
            self.offset += 1;
            value = try self.make(.{ .start = begin, .end = self.offset }, .{ .literal = .{ .string = try bytes.toOwnedSlice(self.allocator) } });
        } else if (std.ascii.isDigit(ch)) {
            while (self.offset < self.end and std.ascii.isDigit(self.source[self.offset])) : (self.offset += 1) {}
            if (self.offset < self.end and self.source[self.offset] == '.') {
                self.offset += 1;
                const fraction_start = self.offset;
                while (self.offset < self.end and std.ascii.isDigit(self.source[self.offset])) : (self.offset += 1) {}
                if (fraction_start == self.offset) return null;
            }
            if (self.offset < self.end and (self.source[self.offset] == 'e' or self.source[self.offset] == 'E')) {
                self.offset += 1;
                if (self.offset < self.end and (self.source[self.offset] == '+' or self.source[self.offset] == '-')) self.offset += 1;
                const exponent_start = self.offset;
                while (self.offset < self.end and std.ascii.isDigit(self.source[self.offset])) : (self.offset += 1) {}
                if (exponent_start == self.offset) return null;
            }
            const number = std.fmt.parseFloat(f64, self.source[begin..self.offset]) catch return null;
            value = try self.make(.{ .start = begin, .end = self.offset }, .{ .literal = .{ .number = number } });
        } else if (isStart(ch)) {
            self.offset += 1;
            while (self.offset < self.end and isContinue(self.source[self.offset])) : (self.offset += 1) {}
            const name = self.source[begin..self.offset];
            if (std.mem.eql(u8, name, "null")) value = try self.make(.{ .start = begin, .end = self.offset }, .{ .literal = .null }) else if (std.mem.eql(u8, name, "true") or std.mem.eql(u8, name, "false")) value = try self.make(.{ .start = begin, .end = self.offset }, .{ .literal = .{ .boolean = name[0] == 't' } }) else value = try self.make(.{ .start = begin, .end = self.offset }, .{ .identifier = name });
        } else return null;
        while (true) {
            self.skipSpace();
            if (self.offset >= self.end) break;
            if (self.source[self.offset] == '.') {
                const access_start = self.offset;
                self.offset += 1;
                const prop = self.offset;
                if (self.offset >= self.end or !isStart(self.source[self.offset])) return null;
                self.offset += 1;
                while (self.offset < self.end and isContinue(self.source[self.offset])) : (self.offset += 1) {}
                value = try self.make(.{ .start = value.span.start, .end = self.offset }, .{ .property = .{ .base = value, .name = self.source[prop..self.offset], .selector_span = .{ .start = access_start, .end = self.offset } } });
            } else if (self.source[self.offset] == '[') {
                self.offset += 1;
                self.skipSpace();
                const digits = self.offset;
                var idx: usize = 0;
                while (self.offset < self.end and std.ascii.isDigit(self.source[self.offset])) : (self.offset += 1) {
                    idx = std.math.add(usize, std.math.mul(usize, idx, 10) catch return null, self.source[self.offset] - '0') catch return null;
                }
                if (digits == self.offset) return null;
                self.skipSpace();
                if (self.offset >= self.end or self.source[self.offset] != ']') return null;
                self.offset += 1;
                value = try self.make(.{ .start = value.span.start, .end = self.offset }, .{ .index = .{ .base = value, .value = idx, .selector_span = .{ .start = digits - 1, .end = self.offset } } });
            } else break;
        }
        return value;
    }
    const Binary = struct { op: Operator, precedence: u8, length: usize };
    fn binaryOperator(self: *Parser) ?Binary {
        const s = self.source[self.offset..self.end];
        const candidates = [_]Binary{ .{ .op = .or_, .precedence = 1, .length = 2 }, .{ .op = .and_, .precedence = 2, .length = 2 }, .{ .op = .equal, .precedence = 3, .length = 2 }, .{ .op = .not_equal, .precedence = 3, .length = 2 }, .{ .op = .less_equal, .precedence = 4, .length = 2 }, .{ .op = .greater_equal, .precedence = 4, .length = 2 }, .{ .op = .less, .precedence = 4, .length = 1 }, .{ .op = .greater, .precedence = 4, .length = 1 }, .{ .op = .add, .precedence = 5, .length = 1 }, .{ .op = .subtract, .precedence = 5, .length = 1 }, .{ .op = .multiply, .precedence = 6, .length = 1 }, .{ .op = .divide, .precedence = 6, .length = 1 }, .{ .op = .modulo, .precedence = 6, .length = 1 } };
        for (candidates) |candidate| {
            const token = switch (candidate.op) {
                .or_ => "||",
                .and_ => "&&",
                .equal => "==",
                .not_equal => "!=",
                .less_equal => "<=",
                .greater_equal => ">=",
                .less => "<",
                .greater => ">",
                .add => "+",
                .subtract => "-",
                .multiply => "*",
                .divide => "/",
                .modulo => "%",
                else => unreachable,
            };
            if (std.mem.startsWith(u8, s, token)) return candidate;
        }
        return null;
    }
};
fn invalid(span: zeft.SourceSpan) ParseResult {
    return .{ .failure = .{ .kind = .invalid_expression, .span = span } };
}
fn isStart(b: u8) bool {
    return std.ascii.isAlphabetic(b) or b == '_';
}
fn isContinue(b: u8) bool {
    return std.ascii.isAlphanumeric(b) or b == '_';
}

test "expression parser handles literals, precedence, grouping and accesses" {
    const source = "!users[2].active || (count + 2 * 3 >= 8 && name == 'Ada')";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const result = try parse(arena.allocator(), source, .{ .start = 0, .end = source.len });
    try std.testing.expect(result == .success);
}
test "expression parser rejects malformed literals and operators" {
    for ([_][]const u8{ "1e", "'bad\\q'", "a +", "(a", "items[-1]", "a === b" }) |source| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const parsed = try parse(arena.allocator(), source, .{ .start = 0, .end = source.len });
        try std.testing.expect(parsed == .failure);
    }
}
