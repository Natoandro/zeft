//! Parser for plain identifier and property/index access expressions.

const std = @import("std");
const zeft = @import("zeft_core");

pub const Identifier = struct {
    name: []const u8,
    span: zeft.SourceSpan,
};

pub const Access = struct {
    span: zeft.SourceSpan,
    data: Data,

    pub const Data = union(enum) {
        property: []const u8,
        index: usize,
    };
};

pub const Expression = struct {
    root: Identifier,
    accesses: []Access,
    span: zeft.SourceSpan,
};

pub const ParseResult = union(enum) {
    success: Expression,
    failure: zeft.CompileDiagnostic,
};

/// Parse an access-only expression from its delimiter-trimmed source span.
/// Operators and other expression forms are intentionally rejected here.
pub fn parse(
    allocator: std.mem.Allocator,
    source: []const u8,
    span: zeft.SourceSpan,
) std.mem.Allocator.Error!ParseResult {
    if (!span.isValid(source.len) or span.start == span.end) return invalid(span);
    var offset = span.start;
    const root_start = offset;
    if (!isStart(source[offset])) return invalid(span);
    offset += 1;
    while (offset < span.end and isContinue(source[offset])) : (offset += 1) {}
    const root_name = source[root_start..offset];
    if (isReserved(root_name)) return invalid(.{ .start = root_start, .end = offset });
    const root = Identifier{ .name = root_name, .span = .{ .start = root_start, .end = offset } };

    var accesses: std.ArrayList(Access) = .empty;
    while (offset < span.end) {
        const access_start = offset;
        switch (source[offset]) {
            '.' => {
                offset += 1;
                const property_start = offset;
                if (offset >= span.end or !isStart(source[offset])) return invalid(.{ .start = access_start, .end = span.end });
                offset += 1;
                while (offset < span.end and isContinue(source[offset])) : (offset += 1) {}
                try accesses.append(allocator, .{
                    .span = .{ .start = access_start, .end = offset },
                    .data = .{ .property = source[property_start..offset] },
                });
            },
            '[' => {
                offset += 1;
                const digits_start = offset;
                var index: usize = 0;
                while (offset < span.end and std.ascii.isDigit(source[offset])) : (offset += 1) {
                    index = std.math.mul(usize, index, 10) catch return invalid(.{ .start = access_start, .end = offset + 1 });
                    index = std.math.add(usize, index, source[offset] - '0') catch return invalid(.{ .start = access_start, .end = offset + 1 });
                }
                if (offset == digits_start or offset >= span.end or source[offset] != ']') {
                    return invalid(.{ .start = access_start, .end = span.end });
                }
                offset += 1;
                try accesses.append(allocator, .{
                    .span = .{ .start = access_start, .end = offset },
                    .data = .{ .index = index },
                });
            },
            else => return invalid(.{ .start = offset, .end = span.end }),
        }
    }

    return .{ .success = .{
        .root = root,
        .accesses = try accesses.toOwnedSlice(allocator),
        .span = span,
    } };
}

fn invalid(span: zeft.SourceSpan) ParseResult {
    return .{ .failure = .{ .kind = .invalid_expression, .span = span } };
}

fn isStart(byte: u8) bool {
    return std.ascii.isAlphabetic(byte) or byte == '_';
}

fn isContinue(byte: u8) bool {
    return std.ascii.isAlphanumeric(byte) or byte == '_';
}

fn isReserved(name: []const u8) bool {
    return std.mem.eql(u8, name, "null") or std.mem.eql(u8, name, "true") or std.mem.eql(u8, name, "false");
}

test "parses root identifiers and chained property/index accesses" {
    const source = "users[12].profile.display_name";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const parsed = try parse(arena.allocator(), source, .{ .start = 0, .end = source.len });
    const expression = switch (parsed) {
        .success => |value| value,
        .failure => return error.UnexpectedParseFailure,
    };
    try std.testing.expectEqualStrings("users", expression.root.name);
    try std.testing.expectEqual(zeft.SourceSpan{ .start = 0, .end = 5 }, expression.root.span);
    try std.testing.expectEqual(@as(usize, 3), expression.accesses.len);
    try std.testing.expectEqual(@as(usize, 12), expression.accesses[0].data.index);
    try std.testing.expectEqual(zeft.SourceSpan{ .start = 5, .end = 9 }, expression.accesses[0].span);
    try std.testing.expectEqualStrings("profile", expression.accesses[1].data.property);
    try std.testing.expectEqual(zeft.SourceSpan{ .start = 9, .end = 17 }, expression.accesses[1].span);
    try std.testing.expectEqualStrings("display_name", expression.accesses[2].data.property);
}

test "rejects operators, dynamic indexes, malformed accesses, and non-ASCII identifiers" {
    for ([_][]const u8{ "", "7user", "null", "true", "false", "user + other", "user.name()", "items[index]", "items[-1]", "items[]", "user..name", "é" }) |source| {
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        const parsed = try parse(arena.allocator(), source, .{ .start = 0, .end = source.len });
        switch (parsed) {
            .success => return error.ExpectedDiagnostic,
            .failure => |diagnostic| try std.testing.expectEqual(zeft.CompileErrorKind.invalid_expression, diagnostic.kind),
        }
    }
}
