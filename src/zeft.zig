//! Public entry point for the Zeft template compiler and renderer.

const std = @import("std");

pub const OutputFormat = enum {
    html,
    xml,
};

pub const WhitespacePolicy = enum {
    preserve,
    compact,
    pretty,
};

/// Compile-time settings. Defaults are HTML output with source whitespace
/// preserved.
pub const CompileOptions = struct {
    format: OutputFormat = .html,
    whitespace: WhitespacePolicy = .preserve,
};

/// A half-open byte range in the original template source: [start, end).
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

/// Owns the finalized storage for one compiled template.
pub const CompiledTemplate = struct {
    allocator: std.mem.Allocator,
    owned_storage: ?[]u8 = null,

    /// Releases storage owned by this template. Call exactly once.
    pub fn deinit(self: *CompiledTemplate) void {
        if (self.owned_storage) |storage| self.allocator.free(storage);
        self.* = undefined;
    }
};

pub const CompileResult = union(enum) {
    success: CompiledTemplate,
    failure: CompileDiagnostic,
};

/// Compile source into an owning template or a categorized diagnostic.
///
/// The parser frontend is implemented, but compilation still reports
/// `unsupported_syntax` until analysis, lowering, finalization, and rendering
/// are available.
pub fn compile(
    allocator: std.mem.Allocator,
    source: []const u8,
    options: CompileOptions,
) CompileResult {
    _ = allocator;
    _ = options;
    return .{ .failure = .{
        .kind = .unsupported_syntax,
        .span = .{ .start = 0, .end = source.len },
    } };
}
