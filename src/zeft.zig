//! Public entry point for the Zeft template compiler and renderer.

const std = @import("std");
const core = @import("zeft_core");
const parser = @import("zeft_parser");
const analysis = @import("zeft_analysis");
const lower = @import("zeft_lower");
const ir = @import("zeft_ir");
const optimizer = @import("zeft_optimize");
const runtime = @import("zeft_runtime");

pub const OutputFormat = core.OutputFormat;
pub const WhitespacePolicy = core.WhitespacePolicy;
pub const CompileOptions = core.CompileOptions;
pub const SourceSpan = core.SourceSpan;
pub const CompileErrorKind = core.CompileErrorKind;
pub const RenderErrorKind = core.RenderErrorKind;
pub const CompileDiagnostic = core.CompileDiagnostic;
pub const RenderDiagnostic = core.RenderDiagnostic;

pub const CompileResult = union(enum) {
    success: CompiledTemplate,
    failure: CompileDiagnostic,
};

pub const RenderResult = runtime.RenderResult;

const ContextEntry = runtime.ContextEntry;

const FinalizedTemplate = struct {
    owner_allocator: std.mem.Allocator,
    storage: *std.heap.ArenaAllocator,
    program: ir.Program,
    options: CompileOptions,
};

/// Owns the finalized storage for one compiled template.
pub const CompiledTemplate = struct {
    impl: *anyopaque,

    fn finalized(self: *const CompiledTemplate) *const FinalizedTemplate {
        return @ptrCast(@alignCast(self.impl));
    }

    /// Releases all finalized data owned by this template. Call exactly once.
    pub fn deinit(self: *CompiledTemplate) void {
        const data: *FinalizedTemplate = @ptrCast(@alignCast(self.impl));
        data.storage.deinit();
        data.owner_allocator.destroy(data.storage);
        data.owner_allocator.destroy(data);
        self.* = undefined;
    }

    /// Render against a struct whose fields are byte strings. Runtime template
    /// errors are returned as diagnostics; writer errors propagate unchanged.
    pub fn render(
        self: *const CompiledTemplate,
        writer: *std.Io.Writer,
        context: anytype,
    ) anyerror!RenderResult {
        const ContextType = @TypeOf(context);
        const type_info = @typeInfo(ContextType);
        if (type_info != .@"struct") @compileError("render context must be a struct of string fields");

        const fields = type_info.@"struct".fields;
        var entries: [fields.len]ContextEntry = undefined;
        inline for (fields, 0..) |field, index| {
            entries[index] = .{
                .name = field.name,
                .value = contextString(field.type, @field(context, field.name)),
            };
        }
        const compiled = self.finalized();
        return runtime.render(compiled.program, writer, &entries, compiled.options.format);
    }
};

/// Compile source to an allocator-owned template or a categorized diagnostic.
/// Temporary AST and IR storage is released before this function returns.
pub fn compile(
    allocator: std.mem.Allocator,
    source: []const u8,
    options: CompileOptions,
) std.mem.Allocator.Error!CompileResult {
    if (options.whitespace != .preserve) return .{ .failure = .{
        .kind = .unsupported_syntax,
        .span = .{ .start = 0, .end = source.len },
    } };

    var temporary = std.heap.ArenaAllocator.init(allocator);
    defer temporary.deinit();
    const temp_allocator = temporary.allocator();

    const parsed = try parser.parseWithFormat(temp_allocator, source, options.format);
    const document = switch (parsed) {
        .success => |value| value,
        .failure => |diagnostic| return .{ .failure = diagnostic },
    };
    const analyzed_result = try analysis.analyze(temp_allocator, source, document);
    const analyzed = switch (analyzed_result) {
        .success => |value| value,
        .failure => |diagnostic| return .{ .failure = diagnostic },
    };
    const lowered = try lower.lower(temp_allocator, document, analyzed);
    const program = switch (lowered) {
        .success => |value| value,
        .failure => |diagnostic| return .{ .failure = diagnostic },
    };

    // Run optimization on every successful compile, including the no-op case.
    const optimized = try optimizer.optimize(temp_allocator, program);
    return .{ .success = try finalize(allocator, optimized, options) };
}

fn finalize(
    allocator: std.mem.Allocator,
    program: ir.Program,
    options: CompileOptions,
) std.mem.Allocator.Error!CompiledTemplate {
    const storage = try allocator.create(std.heap.ArenaAllocator);
    storage.* = std.heap.ArenaAllocator.init(allocator);
    errdefer {
        storage.deinit();
        allocator.destroy(storage);
    }
    const persistent = storage.allocator();

    const strings = try persistent.alloc([]const u8, program.strings.len);
    for (program.strings, 0..) |value, index| strings[index] = try persistent.dupe(u8, value);

    const symbols = try persistent.dupe(analysis.Symbol, program.symbols);
    for (symbols) |*symbol| symbol.name = try persistent.dupe(u8, symbol.name);

    const expressions = try persistent.alloc(ir.ExpressionProgram, program.expressions.len);
    for (program.expressions, 0..) |expression, index| {
        expressions[index] = .{ .instructions = try persistent.dupe(ir.ExpressionInstruction, expression.instructions) };
    }

    const finalized = try allocator.create(FinalizedTemplate);
    finalized.* = .{
        .owner_allocator = allocator,
        .storage = storage,
        .program = .{
            .strings = strings,
            .symbols = symbols,
            .expressions = expressions,
            .instructions = try persistent.dupe(ir.Instruction, program.instructions),
        },
        .options = options,
    };
    return .{ .impl = finalized };
}

fn contextString(comptime T: type, value: T) []const u8 {
    const type_info = @typeInfo(T);
    if (type_info == .pointer) {
        const pointer_info = type_info.pointer;
        if (pointer_info.size == .slice and pointer_info.child == u8) return value;
        if (pointer_info.size == .one) {
            const child_info = @typeInfo(pointer_info.child);
            if (child_info == .array and child_info.array.child == u8) return value[0..];
        }
    }
    @compileError("render context fields must be byte strings");
}

test "compile options default to HTML with preserved whitespace" {
    const options: CompileOptions = .{};
    try std.testing.expectEqual(OutputFormat.html, options.format);
    try std.testing.expectEqual(WhitespacePolicy.preserve, options.whitespace);
}

test "compiled template owns finalized storage and renders after source release" {
    const allocator = std.testing.allocator;
    const source = try allocator.dupe(u8, "<p>Hello, {{ name }}!</p>");
    const result = try compile(allocator, source, .{});
    allocator.free(source);
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();

    var output: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, .{ .name = "<Ada>" });
    try std.testing.expectEqual(RenderResult.success, rendered);
    try std.testing.expectEqualStrings("<p>Hello, &lt;Ada&gt;!</p>", std.Io.Writer.buffered(&writer));
}

test "compile returns syntax diagnostics before rendering" {
    var result = try compile(std.testing.allocator, "<p>{{ broken", .{});
    switch (result) {
        .success => |*template| template.deinit(),
        .failure => |diagnostic| {
            try std.testing.expectEqual(CompileErrorKind.invalid_expression, diagnostic.kind);
            try std.testing.expectEqual(@as(?SourceSpan, .{ .start = 3, .end = 12 }), diagnostic.span);
        },
    }
}

test "unsupported whitespace policies return a compile diagnostic" {
    const result = try compile(std.testing.allocator, "text", .{ .whitespace = .compact });
    switch (result) {
        .success => |value| {
            var template = value;
            template.deinit();
            return error.ExpectedDiagnostic;
        },
        .failure => |diagnostic| {
            try std.testing.expectEqual(CompileErrorKind.unsupported_syntax, diagnostic.kind);
            try std.testing.expectEqual(@as(?SourceSpan, .{ .start = 0, .end = 4 }), diagnostic.span);
        },
    }
}

test "render reports missing identifiers with their source span" {
    const result = try compile(std.testing.allocator, "{{ name }}", .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    var output: [16]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, .{});
    switch (rendered) {
        .success => return error.ExpectedDiagnostic,
        .failure => |diagnostic| {
            try std.testing.expectEqual(RenderErrorKind.missing_variable, diagnostic.kind);
            try std.testing.expectEqual(@as(?SourceSpan, .{ .start = 3, .end = 7 }), diagnostic.span);
        },
    }
}

test "writer failures propagate from render" {
    const result = try compile(std.testing.allocator, "some output", .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    var output: [2]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    try std.testing.expectError(error.WriteFailed, template.render(&writer, .{}));
}
