//! Phase 1 parser for a single root-context identifier expression.

const std = @import("std");
const zeft = @import("zeft_core");

pub const Identifier = struct {
    name: []const u8,
    span: zeft.SourceSpan,
};

pub const ParseResult = union(enum) {
    success: Identifier,
    failure: zeft.CompileDiagnostic,
};

/// Parse one Phase 1 identifier from its already delimiter-trimmed source span.
pub fn parse(source: []const u8, span: zeft.SourceSpan) ParseResult {
    if (!span.isValid(source.len) or span.start == span.end) return invalid(span);
    const name = source[span.start..span.end];
    if (!isStart(name[0])) return invalid(span);
    for (name[1..]) |byte| {
        if (!isContinue(byte)) return invalid(span);
    }
    return .{ .success = .{ .name = name, .span = span } };
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

test "accepts ASCII root identifiers" {
    const source = "__user7";
    const result = parse(source, .{ .start = 0, .end = source.len });
    switch (result) {
        .success => |identifier| try std.testing.expectEqualStrings(source, identifier.name),
        .failure => return error.UnexpectedParseFailure,
    }
}

test "rejects non-identifiers and non-ASCII bytes" {
    for ([_][]const u8{ "", "7user", "user.name", "name + other", "é" }) |source| {
        const result = parse(source, .{ .start = 0, .end = source.len });
        switch (result) {
            .success => return error.ExpectedDiagnostic,
            .failure => |diagnostic| try std.testing.expectEqual(zeft.CompileErrorKind.invalid_expression, diagnostic.kind),
        }
    }
}
