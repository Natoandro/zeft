//! Types shared by the public API and compiler modules.

const std = @import("std");

pub const OutputFormat = enum { html, xml };
pub const WhitespacePolicy = enum { preserve, compact, pretty };
pub const max_compile_nesting = 128;

pub const CompileOptions = struct {
    format: OutputFormat = .html,
    whitespace: WhitespacePolicy = .preserve,
    /// Indentation bytes for pretty output; defaults to two spaces.
    indentation: []const u8 = "  ",
    /// Optional caller-owned identity attached to diagnostics.
    source_identity: ?[]const u8 = null,
};

pub const SourceSpan = struct {
    start: usize,
    end: usize,

    pub fn isValid(self: SourceSpan, source_len: usize) bool {
        return self.start <= self.end and self.end <= source_len;
    }
};

pub const SourceLocation = struct { line: usize, column: usize };

pub fn sourceLocation(source: []const u8, offset: usize) ?SourceLocation {
    if (offset > source.len) return null;
    var location: SourceLocation = .{ .line = 1, .column = 1 };
    var index: usize = 0;
    while (index < offset) {
        const byte = source[index];
        if (byte == '\n' or byte == '\r') {
            if (byte == '\r' and index + 1 < offset and source[index + 1] == '\n') {
                index += 1;
            }
            location.line += 1;
            location.column = 1;
            index += 1;
            continue;
        }
        const sequence_length = std.unicode.utf8ByteSequenceLength(byte) catch 1;
        index += @min(sequence_length, offset - index);
        location.column += 1;
    }
    return location;
}

pub const CompileErrorKind = enum {
    syntax,
    invalid_markup,
    invalid_expression,
    invalid_construct,
    unsupported_syntax,
};

pub const RenderErrorKind = enum {
    missing_variable,
    invalid_property_access,
    invalid_operand,
    non_iterable,
    callable_failure,
    writer_failure,
    missing_template,
    missing_include,
    include_cycle,
    include_compile_failure,
};

pub const CompileDiagnostic = struct {
    kind: CompileErrorKind,
    span: ?SourceSpan = null,
    source_identity: ?[]const u8 = null,
};

pub const IncludeFrame = struct {
    parent_identity: []const u8,
    child_identity: []const u8,
    span: SourceSpan,
};

pub const RenderDiagnostic = struct {
    kind: RenderErrorKind,
    span: ?SourceSpan = null,
    source_identity: ?[]const u8 = null,
    include_stack: []const IncludeFrame = &.{},
    callback_error: ?[]const u8 = null,
    /// Stable include identity associated with dependency errors.
    include_identity: ?[]const u8 = null,
    /// Identity of the template containing the failed include directive.
    include_parent_identity: ?[]const u8 = null,
    /// Original child compile diagnostic, when the child has no valid entry.
    include_compile_diagnostic: ?CompileDiagnostic = null,
};

test "source spans are half-open and bounded by source length" {
    const span: SourceSpan = .{ .start = 2, .end = 5 };
    try std.testing.expect(span.isValid(5));
    try std.testing.expect(!span.isValid(4));
    try std.testing.expect(!(SourceSpan{ .start = 3, .end = 2 }).isValid(4));
}

test "source locations use one-based Unicode columns" {
    const source = "éx\r\ny";
    try std.testing.expectEqual(
        SourceLocation{ .line = 1, .column = 2 },
        sourceLocation(source, 2).?,
    );
    try std.testing.expectEqual(
        SourceLocation{ .line = 2, .column = 2 },
        sourceLocation(source, source.len).?,
    );
    try std.testing.expect(sourceLocation(source, source.len + 1) == null);
}
