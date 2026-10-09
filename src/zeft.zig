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
pub const Value = runtime.Value;
pub const Callable = runtime.Callable;
pub const Registration = runtime.Registration;
pub const RenderOptions = runtime.RenderOptions;

const ContextEntry = runtime.ContextEntry;

const FinalizedTemplate = struct {
    owner_allocator: std.mem.Allocator,
    storage: *std.heap.ArenaAllocator,
    program: ir.Program,
    options: CompileOptions,
};

const CacheMutex = struct {
    held: std.atomic.Value(bool) = .init(false),

    fn lock(self: *CacheMutex) void {
        while (self.held.cmpxchgWeak(false, true, .acquire, .monotonic) != null) std.atomic.spinLoopHint();
    }

    fn unlock(self: *CacheMutex) void {
        self.held.store(false, .release);
    }
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

    /// Render against a struct with byte-string fields, or pass a pointer when
    /// the context contains nested structs, arrays, or slices. Runtime template
    /// errors are returned as diagnostics; writer errors propagate unchanged.
    pub fn render(
        self: *const CompiledTemplate,
        writer: *std.Io.Writer,
        context: anytype,
    ) anyerror!RenderResult {
        const compiled = self.finalized();
        return @call(.never_inline, renderContext, .{ compiled.program, writer, context, compiled.options.format, RenderOptions{} });
    }

    /// Render with caller supplied filters, functions, and scratch allocator.
    /// Registered callback data must remain valid for the duration of render.
    pub fn renderWithOptions(
        self: *const CompiledTemplate,
        writer: *std.Io.Writer,
        context: anytype,
        options: RenderOptions,
    ) anyerror!RenderResult {
        const compiled = self.finalized();
        return @call(.never_inline, renderContext, .{ compiled.program, writer, context, compiled.options.format, options });
    }

    fn renderRuntime(self: *const CompiledTemplate, writer: *std.Io.Writer, context: []const ContextEntry, options: RenderOptions) anyerror!RenderResult {
        const compiled = self.finalized();
        return runtime.renderWithOptions(compiled.program, writer, context, compiled.options.format, options);
    }
};

const CacheEntry = struct {
    identity: []const u8,
    source: []const u8,
    options: CompileOptions,
    fingerprint: u64,
    template: CompiledTemplate,
    references: usize = 0,
    retired: bool = false,
};

/// A retained immutable compiled template. Release each lease exactly once.
pub const TemplateLease = struct {
    cache: *TemplateCache,
    entry: *CacheEntry,

    pub fn deinit(self: *TemplateLease) void {
        self.cache.release(self.entry);
        self.* = undefined;
    }

    pub fn render(self: *const TemplateLease, writer: *std.Io.Writer, context: anytype) anyerror!RenderResult {
        return self.cache.renderLease(self, writer, context, .{});
    }

    pub fn renderWithOptions(self: *const TemplateLease, writer: *std.Io.Writer, context: anytype, options: RenderOptions) anyerror!RenderResult {
        return self.cache.renderLease(self, writer, context, options);
    }
};

const CacheRenderFrame = struct {
    cache: *TemplateCache,
    allocator: std.mem.Allocator,
    dependencies: std.ArrayList([]const u8) = .empty,
};

/// Thread-safe cache for immutable compiled templates and independently loaded includes.
pub const TemplateCache = struct {
    allocator: std.mem.Allocator,
    diagnostic_storage: std.heap.ArenaAllocator,
    mutex: CacheMutex = .{},
    entries: std.ArrayList(*CacheEntry) = .empty,
    all_entries: std.ArrayList(*CacheEntry) = .empty,
    failures: std.ArrayList(struct { identity: []const u8, diagnostic: CompileDiagnostic }) = .empty,

    pub fn init(allocator: std.mem.Allocator) TemplateCache {
        return .{ .allocator = allocator, .diagnostic_storage = std.heap.ArenaAllocator.init(allocator) };
    }

    /// Compile or reload an identity. On a failed reload, its last valid entry remains available.
    pub fn getOrCompile(self: *TemplateCache, identity: []const u8, source: []const u8, options: CompileOptions) std.mem.Allocator.Error!CacheCompileResult {
        self.mutex.lock();
        defer self.mutex.unlock();
        const fingerprint = cacheFingerprint(identity, source, options);
        for (self.entries.items) |entry| {
            if (!entry.retired and std.mem.eql(u8, entry.identity, identity) and entry.fingerprint == fingerprint and
                std.mem.eql(u8, entry.source, source) and optionsEqual(entry.options, options))
            {
                entry.references += 1;
                return .{ .success = .{ .cache = self, .entry = entry } };
            }
        }
        const compiled = try compile(self.allocator, source, options);
        switch (compiled) {
            .failure => |diagnostic| {
                try self.recordFailure(identity, diagnostic);
                return .{ .failure = diagnostic };
            },
            .success => |template| {
                var owned_template = template;
                errdefer owned_template.deinit();
                const identity_copy = try self.allocator.dupe(u8, identity);
                errdefer self.allocator.free(identity_copy);
                const source_copy = try self.allocator.dupe(u8, source);
                errdefer self.allocator.free(source_copy);
                const indentation_copy = try self.allocator.dupe(u8, options.indentation);
                errdefer self.allocator.free(indentation_copy);
                const new_entry = try self.allocator.create(CacheEntry);
                errdefer self.allocator.destroy(new_entry);
                new_entry.* = .{
                    .identity = identity_copy,
                    .source = source_copy,
                    .options = options,
                    .fingerprint = fingerprint,
                    .template = owned_template,
                    .references = 1,
                };
                new_entry.options.indentation = indentation_copy;
                // Reserve every list slot before retiring the current version.
                // If either allocation fails, the previous entry stays current.
                try self.all_entries.ensureUnusedCapacity(self.allocator, 1);
                try self.entries.ensureUnusedCapacity(self.allocator, 1);
                self.all_entries.appendAssumeCapacity(new_entry);
                self.retireIdentity(identity);
                self.entries.appendAssumeCapacity(new_entry);
                owned_template = undefined;
                self.clearFailure(identity);
                return .{ .success = .{ .cache = self, .entry = new_entry } };
            },
        }
    }

    /// Remove the current version for an identity. Existing leases remain valid.
    pub fn evict(self: *TemplateCache, identity: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.retireIdentity(identity);
    }

    /// Render an identity and resolve every include from the current cache entry.
    pub fn render(self: *TemplateCache, allocator: std.mem.Allocator, identity: []const u8, writer: *std.Io.Writer, context: anytype) anyerror!RenderResult {
        return self.renderWithOptions(allocator, identity, writer, context, .{});
    }

    pub fn renderWithOptions(self: *TemplateCache, allocator: std.mem.Allocator, identity: []const u8, writer: *std.Io.Writer, context: anytype, options: RenderOptions) anyerror!RenderResult {
        var root = self.acquire(identity) orelse return .{ .failure = .{ .kind = .missing_template, .include_identity = identity } };
        defer root.deinit();
        return self.renderLeaseWithAllocator(allocator, &root, writer, context, options);
    }

    fn renderLease(self: *TemplateCache, lease: *const TemplateLease, writer: *std.Io.Writer, context: anytype, options: RenderOptions) anyerror!RenderResult {
        return self.renderLeaseWithAllocator(options.allocator, lease, writer, context, options);
    }

    fn renderLeaseWithAllocator(self: *TemplateCache, allocator: std.mem.Allocator, lease: *const TemplateLease, writer: *std.Io.Writer, context: anytype, options: RenderOptions) anyerror!RenderResult {
        var frame = CacheRenderFrame{ .cache = self, .allocator = allocator };
        defer frame.dependencies.deinit(allocator);
        try frame.dependencies.append(allocator, lease.entry.identity);
        var configured = options;
        configured.include_context = &frame;
        configured.include_resolver = resolveCachedInclude;
        const result = try lease.entry.template.renderWithOptions(writer, context, configured);
        return self.persistIncludeDiagnostic(result);
    }

    pub fn deinit(self: *TemplateCache) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        for (self.all_entries.items) |entry| {
            std.debug.assert(entry.references == 0);
            var template = entry.template;
            template.deinit();
            self.allocator.free(entry.identity);
            self.allocator.free(entry.source);
            self.allocator.free(@constCast(entry.options.indentation));
            self.allocator.destroy(entry);
        }
        for (self.failures.items) |failure| self.allocator.free(failure.identity);
        self.entries.deinit(self.allocator);
        self.all_entries.deinit(self.allocator);
        self.failures.deinit(self.allocator);
        self.diagnostic_storage.deinit();
        self.* = undefined;
    }

    fn persistIncludeDiagnostic(self: *TemplateCache, result: RenderResult) std.mem.Allocator.Error!RenderResult {
        if (result != .failure or (result.failure.include_identity == null and result.failure.include_parent_identity == null)) return result;
        self.mutex.lock();
        defer self.mutex.unlock();
        var diagnostic = result.failure;
        if (diagnostic.include_identity) |identity| {
            diagnostic.include_identity = try self.diagnostic_storage.allocator().dupe(u8, identity);
        }
        if (diagnostic.include_parent_identity) |identity| {
            diagnostic.include_parent_identity = try self.diagnostic_storage.allocator().dupe(u8, identity);
        }
        return .{ .failure = diagnostic };
    }

    fn acquire(self: *TemplateCache, identity: []const u8) ?TemplateLease {
        self.mutex.lock();
        defer self.mutex.unlock();
        for (self.entries.items) |entry| if (!entry.retired and std.mem.eql(u8, entry.identity, identity)) {
            entry.references += 1;
            return .{ .cache = self, .entry = entry };
        };
        return null;
    }

    fn release(self: *TemplateCache, entry: *CacheEntry) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        std.debug.assert(entry.references > 0);
        entry.references -= 1;
        if (entry.retired and entry.references == 0) self.destroyEntry(entry);
    }

    fn retireIdentity(self: *TemplateCache, identity: []const u8) void {
        var index: usize = 0;
        while (index < self.entries.items.len) {
            const entry = self.entries.items[index];
            if (entry.retired or !std.mem.eql(u8, entry.identity, identity)) {
                index += 1;
                continue;
            }
            _ = self.entries.orderedRemove(index);
            entry.retired = true;
            if (entry.references == 0) self.destroyEntry(entry);
        }
    }

    fn failureFor(self: *TemplateCache, identity: []const u8) ?CompileDiagnostic {
        self.mutex.lock();
        defer self.mutex.unlock();
        for (self.failures.items) |failure| if (std.mem.eql(u8, failure.identity, identity)) return failure.diagnostic;
        return null;
    }

    fn destroyEntry(self: *TemplateCache, entry: *CacheEntry) void {
        for (self.all_entries.items, 0..) |candidate, index| if (candidate == entry) {
            _ = self.all_entries.orderedRemove(index);
            break;
        };
        var template = entry.template;
        template.deinit();
        self.allocator.free(entry.identity);
        self.allocator.free(entry.source);
        self.allocator.free(@constCast(entry.options.indentation));
        self.allocator.destroy(entry);
    }

    fn recordFailure(self: *TemplateCache, identity: []const u8, diagnostic: CompileDiagnostic) std.mem.Allocator.Error!void {
        const identity_copy = try self.allocator.dupe(u8, identity);
        errdefer self.allocator.free(identity_copy);
        try self.failures.ensureUnusedCapacity(self.allocator, 1);
        self.clearFailure(identity);
        self.failures.appendAssumeCapacity(.{ .identity = identity_copy, .diagnostic = diagnostic });
    }

    fn clearFailure(self: *TemplateCache, identity: []const u8) void {
        var index: usize = 0;
        while (index < self.failures.items.len) {
            if (std.mem.eql(u8, self.failures.items[index].identity, identity)) {
                self.allocator.free(self.failures.items[index].identity);
                _ = self.failures.orderedRemove(index);
            } else index += 1;
        }
    }
};

pub const CacheCompileResult = union(enum) { success: TemplateLease, failure: CompileDiagnostic };

fn resolveCachedInclude(raw: *anyopaque, identity: []const u8, writer: *std.Io.Writer, context: []const ContextEntry, format: OutputFormat, options: RenderOptions, span: SourceSpan) anyerror!RenderResult {
    const frame: *CacheRenderFrame = @ptrCast(@alignCast(raw));
    const parent_identity = frame.dependencies.items[frame.dependencies.items.len - 1];
    for (frame.dependencies.items) |active| if (std.mem.eql(u8, active, identity)) {
        return .{ .failure = .{ .kind = .include_cycle, .span = span, .include_identity = identity, .include_parent_identity = parent_identity } };
    };
    var child = frame.cache.acquire(identity) orelse {
        const compile_diagnostic = frame.cache.failureFor(identity);
        return .{ .failure = .{
            .kind = if (compile_diagnostic != null) .include_compile_failure else .missing_include,
            .span = span,
            .include_identity = identity,
            .include_parent_identity = parent_identity,
            .include_compile_diagnostic = compile_diagnostic,
        } };
    };
    defer child.deinit();
    try frame.dependencies.append(frame.allocator, child.entry.identity);
    defer _ = frame.dependencies.pop();
    _ = format;
    return child.entry.template.renderRuntime(writer, context, options);
}

fn cacheFingerprint(identity: []const u8, source: []const u8, options: CompileOptions) u64 {
    var hasher = std.hash.Wyhash.init(0x5a454654);
    hasher.update("zeft-compiler-ir-1");
    hasher.update(identity);
    hasher.update(source);
    hasher.update(&.{ @intFromEnum(options.format), @intFromEnum(options.whitespace) });
    hasher.update(options.indentation);
    return hasher.final();
}

fn optionsEqual(left: CompileOptions, right: CompileOptions) bool {
    return left.format == right.format and left.whitespace == right.whitespace and std.mem.eql(u8, left.indentation, right.indentation);
}

fn renderContext(program: ir.Program, writer: *std.Io.Writer, context: anytype, format: OutputFormat, options: RenderOptions) anyerror!RenderResult {
    const ContextType = @TypeOf(context);
    const type_info = @typeInfo(ContextType);
    const context_is_pointer = type_info == .pointer and type_info.pointer.size == .one and
        @typeInfo(type_info.pointer.child) == .@"struct";
    const StructType = if (context_is_pointer) type_info.pointer.child else ContextType;
    if (@typeInfo(StructType) != .@"struct") @compileError("render context must be a struct or pointer to a struct");

    const fields = @typeInfo(StructType).@"struct".fields;
    var entries: [fields.len]ContextEntry = undefined;
    inline for (fields, 0..) |field, index| {
        entries[index] = .{
            .name = field.name,
            .value = if (comptime runtime.isString(field.type)) blk: {
                const field_value = if (comptime context_is_pointer)
                    @field(context.*, field.name)
                else
                    @field(context, field.name);
                break :blk .{ .string = runtime.stringValue(field.type, field_value) };
            } else if (comptime context_is_pointer) blk: {
                break :blk runtime.adapt(field.type, &@field(context.*, field.name));
            } else @compileError("nested context values require passing a pointer to the context struct"),
        };
    }
    return runtime.renderWithOptions(program, writer, &entries, format, options);
}

/// Compile source to an allocator-owned template or a categorized diagnostic.
/// Temporary AST and IR storage is released before this function returns.
pub fn compile(
    allocator: std.mem.Allocator,
    source: []const u8,
    options: CompileOptions,
) std.mem.Allocator.Error!CompileResult {
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
    const lowered = try lower.lower(temp_allocator, document, analyzed, options);
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
        const instructions = try persistent.dupe(ir.ExpressionInstruction, expression.instructions);
        for (instructions) |*instruction| switch (instruction.data) {
            .get_property => |name| instruction.data = .{ .get_property = try persistent.dupe(u8, name) },
            .push_literal => |literal| switch (literal) {
                .string => |value| instruction.data = .{ .push_literal = .{ .string = try persistent.dupe(u8, value) } },
                else => {},
            },
            .call_function => |call| instruction.data = .{ .call_function = .{ .name = try persistent.dupe(u8, call.name), .argument_count = call.argument_count } },
            .call_filter => |call| instruction.data = .{ .call_filter = .{ .name = try persistent.dupe(u8, call.name), .argument_count = call.argument_count } },
            else => {},
        };
        expressions[index] = .{ .instructions = instructions };
    }

    const indentation = try persistent.dupe(u8, options.indentation);
    const instructions = try persistent.dupe(ir.Instruction, program.instructions);
    const finalized = try allocator.create(FinalizedTemplate);
    finalized.* = .{
        .owner_allocator = allocator,
        .storage = storage,
        .program = .{
            .strings = strings,
            .symbols = symbols,
            .expressions = expressions,
            .instructions = instructions,
        },
        .options = options,
    };
    finalized.options.indentation = indentation;
    return .{ .impl = finalized };
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

test "compact whitespace policy compiles successfully" {
    const result = try compile(std.testing.allocator, "text", .{ .whitespace = .compact });
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
}

test "compiled template owns its pretty indentation option" {
    const allocator = std.testing.allocator;
    const indentation = try allocator.dupe(u8, "\t");
    defer allocator.free(indentation);

    const result = try compile(allocator, "<root><item>x</item></root>", .{ .whitespace = .pretty, .indentation = indentation });
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    @memset(indentation, 'x');

    var output: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    try std.testing.expectEqual(RenderResult.success, try template.render(&writer, .{}));
    try std.testing.expectEqualStrings("<root>\n\t<item>x</item>\n</root>\n", std.Io.Writer.buffered(&writer));
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

test "writer errors propagate unchanged for static and dynamic writes" {
    const sources = [_][]const u8{ "static output", "{{ value }}" };
    for (sources) |source| {
        const result = try compile(std.testing.allocator, source, .{});
        var template = switch (result) {
            .success => |value| value,
            .failure => return error.UnexpectedCompileFailure,
        };
        defer template.deinit();
        var output: [1]u8 = undefined;
        var writer = std.Io.Writer.fixed(&output);
        try std.testing.expectError(error.WriteFailed, template.render(&writer, .{ .value = "dynamic" }));
    }
}

test "compile temporary storage is released and finalized storage lasts until deinit" {
    const DebugAllocator = std.heap.DebugAllocator(.{ .thread_safe = true, .stack_trace_frames = 0, .enable_memory_limit = true });
    var debug_allocator: DebugAllocator = .init;
    defer _ = debug_allocator.deinit();
    const allocator = debug_allocator.allocator();

    const baseline_bytes = debug_allocator.total_requested_bytes;
    const result = try compile(allocator, "<p>{{ name }}</p>", .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    const first_template_bytes = debug_allocator.total_requested_bytes - baseline_bytes;
    try std.testing.expect(first_template_bytes > 0);

    const second_result = try compile(allocator, "<p>{{ name }}</p>", .{});
    var second_template = switch (second_result) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    try std.testing.expectEqual(first_template_bytes, debug_allocator.total_requested_bytes - baseline_bytes - first_template_bytes);
    second_template.deinit();
    try std.testing.expectEqual(baseline_bytes + first_template_bytes, debug_allocator.total_requested_bytes);

    var output: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    try std.testing.expectEqual(RenderResult.success, try template.render(&writer, .{ .name = "Ada" }));
    try std.testing.expectEqualStrings("<p>Ada</p>", std.Io.Writer.buffered(&writer));

    const finalized_bytes = debug_allocator.total_requested_bytes;
    const failed_compile = try compile(allocator, "<p>{{ broken", .{});
    switch (failed_compile) {
        .success => |unexpected_template| {
            var unexpected = unexpected_template;
            unexpected.deinit();
            return error.ExpectedCompileFailure;
        },
        .failure => {},
    }
    try std.testing.expectEqual(finalized_bytes, debug_allocator.total_requested_bytes);

    template.deinit();
    try std.testing.expectEqual(@as(usize, 0), debug_allocator.total_requested_bytes);
}
