//! Types shared by the public API and compiler modules.

const std = @import("std");

pub const OutputFormat = enum { html, xml };
pub const WhitespacePolicy = enum { preserve, compact, pretty };

pub const CompileOptions = struct {
    format: OutputFormat = .html,
    whitespace: WhitespacePolicy = .preserve,
};

pub const SourceSpan = struct {
    start: usize,
    end: usize,

    pub fn isValid(self: SourceSpan, source_len: usize) bool {
        return self.start <= self.end and self.end <= source_len;
    }
};

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
    filter_failure,
    function_failure,
    writer_failure,
};

pub const CompileDiagnostic = struct {
    kind: CompileErrorKind,
    span: ?SourceSpan = null,
};

pub const RenderDiagnostic = struct {
    kind: RenderErrorKind,
    span: ?SourceSpan = null,
};

test "source spans are half-open and bounded by source length" {
    const span: SourceSpan = .{ .start = 2, .end = 5 };
    try std.testing.expect(span.isValid(5));
    try std.testing.expect(!span.isValid(4));
    try std.testing.expect(!(SourceSpan{ .start = 3, .end = 2 }).isValid(4));
}
