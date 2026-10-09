//! Public-API fixture assertions shared by integration suites.
const std = @import("std");
const zeft = @import("zeft");

pub const Success = struct {
    id: []const u8,
    path: []const u8,
    expected_path: ?[]const u8 = null,
    source: []const u8,
    expected: []const u8,
    compile_options: zeft.CompileOptions = .{},
    render_options: zeft.RenderOptions = .{ .allocator = std.testing.allocator },
    headroom: usize = 256,
};

pub const CompileFailure = struct {
    id: []const u8,
    path: []const u8,
    source: []const u8,
    compile_options: zeft.CompileOptions = .{},
    diagnostic: zeft.CompileDiagnostic,
};

pub const RenderFailure = struct {
    id: []const u8,
    path: []const u8,
    source: []const u8,
    compile_options: zeft.CompileOptions = .{},
    render_options: zeft.RenderOptions = .{ .allocator = std.testing.allocator },
    diagnostic: zeft.RenderDiagnostic,
    expected_prefix: ?[]const u8 = null,
    headroom: usize = 256,
};

fn report(case: anytype, failure: anyerror) void {
    std.debug.print("\nfixture {s} ({s}): {s}\n", .{ case.id, case.path, @errorName(failure) });
    if (@hasField(@TypeOf(case), "expected_path")) {
        if (case.expected_path) |path| std.debug.print("expected output: {s}\n", .{path});
    }
}

fn compile(source: []const u8, options: zeft.CompileOptions) !zeft.CompiledTemplate {
    return switch (try zeft.compile(std.testing.allocator, source, options)) {
        .success => |template| template,
        .failure => |diagnostic| {
            std.debug.print("unexpected compile diagnostic: {any}\n", .{diagnostic});
            return error.UnexpectedCompileFailure;
        },
    };
}

pub fn expectSuccess(case: Success, context: anytype) anyerror!void {
    errdefer |failure| report(case, failure);
    var template = try compile(case.source, case.compile_options);
    defer template.deinit();
    const capacity = try std.math.add(usize, case.expected.len, case.headroom);
    const output = try std.testing.allocator.alloc(u8, capacity);
    defer std.testing.allocator.free(output);
    var writer = std.Io.Writer.fixed(output);
    const rendered = template.renderWithOptions(&writer, context, case.render_options) catch |failure| {
        if (failure == error.WriteFailed) return error.FixtureOutputOverflow;
        return @as(anyerror!void, failure);
    };
    switch (rendered) {
        .success => {},
        .failure => |diagnostic| {
            std.debug.print("unexpected render diagnostic: {any}\n", .{diagnostic});
            return error.UnexpectedRenderFailure;
        },
    }
    try std.testing.expectEqualStrings(case.expected, std.Io.Writer.buffered(&writer));
}

pub fn expectCompileFailure(case: CompileFailure) anyerror!void {
    errdefer |failure| report(case, failure);
    switch (try zeft.compile(std.testing.allocator, case.source, case.compile_options)) {
        .success => |value| {
            var template = value;
            template.deinit();
            return error.ExpectedCompileFailure;
        },
        .failure => |diagnostic| try std.testing.expectEqualDeep(case.diagnostic, diagnostic),
    }
}

pub fn expectRenderFailure(case: RenderFailure, context: anytype) anyerror!void {
    errdefer |failure| report(case, failure);
    var template = try compile(case.source, case.compile_options);
    defer template.deinit();
    const capacity = try std.math.add(usize, if (case.expected_prefix) |prefix| prefix.len else case.source.len, case.headroom);
    const output = try std.testing.allocator.alloc(u8, capacity);
    defer std.testing.allocator.free(output);
    var writer = std.Io.Writer.fixed(output);
    const rendered = template.renderWithOptions(&writer, context, case.render_options) catch |failure| {
        if (failure == error.WriteFailed) return error.FixtureOutputOverflow;
        return @as(anyerror!void, failure);
    };
    switch (rendered) {
        .success => return error.ExpectedRenderFailure,
        .failure => |diagnostic| try std.testing.expectEqualDeep(case.diagnostic, diagnostic),
    }
    if (case.expected_prefix) |prefix| try std.testing.expectEqualStrings(prefix, std.Io.Writer.buffered(&writer));
}
