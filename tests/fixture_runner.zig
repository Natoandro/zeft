//! Public-API fixture assertions shared by integration suites.
const std = @import("std");
const zeft = @import("zeft");

pub const Success = struct {
    id: []const u8,
    template: []const u8,
    output: []const u8,
    compile_options: zeft.CompileOptions = .{},
    render_options: zeft.RenderOptions = .{ .allocator = std.testing.allocator },
    headroom: usize = 256,
};

pub const CompileFailure = struct {
    id: []const u8,
    template: []const u8,
    compile_options: zeft.CompileOptions = .{},
    diagnostic: zeft.CompileDiagnostic,
};

pub const RenderFailure = struct {
    id: []const u8,
    template: []const u8,
    compile_options: zeft.CompileOptions = .{},
    render_options: zeft.RenderOptions = .{ .allocator = std.testing.allocator },
    diagnostic: zeft.RenderDiagnostic,
    expected_prefix: ?[]const u8 = null,
    headroom: usize = 256,
};

fn caseId(case: anytype) []const u8 {
    if (@TypeOf(case) == []const u8) return case;
    if (@hasField(@TypeOf(case), "fixture")) return case.fixture.id;
    return case.id;
}

pub fn expectUniqueIds(groups: anytype) anyerror!void {
    @setEvalBranchQuota(1_000_000);
    inline for (groups, 0..) |left_group, left_group_index| {
        inline for (left_group, 0..) |left, left_index| {
            inline for (groups, 0..) |right_group, right_group_index| {
                if (right_group_index < left_group_index) continue;
                inline for (right_group, 0..) |right, right_index| {
                    if (right_group_index == left_group_index and right_index <= left_index) {
                        continue;
                    }
                    const left_id = caseId(left);
                    const right_id = caseId(right);
                    if (std.mem.eql(u8, left_id, right_id)) {
                        std.debug.print("duplicate fixture ID: {s}\n", .{left_id});
                        return error.DuplicateFixtureId;
                    }
                }
            }
        }
    }
}

pub fn expectSuccessCases(cases: anytype) anyerror!void {
    var failures: usize = 0;
    for (cases) |case| {
        expectSuccess(case.fixture, &case.params) catch {
            failures += 1;
        };
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

pub fn expectCompileFailureCases(cases: anytype) anyerror!void {
    var failures: usize = 0;
    for (cases) |case| {
        expectCompileFailure(case) catch {
            failures += 1;
        };
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

pub fn expectRenderFailureCases(cases: anytype) anyerror!void {
    var failures: usize = 0;
    for (cases) |case| {
        expectRenderFailure(case.fixture, &case.params) catch {
            failures += 1;
        };
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}

fn report(case: anytype, failure: anyerror) void {
    std.debug.print("\nfixture {s}: {s}\n", .{ case.id, @errorName(failure) });
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
    var template = try compile(case.template, case.compile_options);
    defer template.deinit();
    const capacity = try std.math.add(usize, case.output.len, case.headroom);
    const output = try std.testing.allocator.alloc(u8, capacity);
    defer std.testing.allocator.free(output);
    var writer = std.Io.Writer.fixed(output);
    const rendered = template.renderWithOptions(
        &writer,
        context,
        case.render_options,
    ) catch |failure| {
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
    try std.testing.expectEqualStrings(case.output, std.Io.Writer.buffered(&writer));
}

pub fn expectCompileFailure(case: CompileFailure) anyerror!void {
    errdefer |failure| report(case, failure);
    switch (try zeft.compile(std.testing.allocator, case.template, case.compile_options)) {
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
    var template = try compile(case.template, case.compile_options);
    defer template.deinit();
    const capacity = try std.math.add(
        usize,
        if (case.expected_prefix) |prefix| prefix.len else case.template.len,
        case.headroom,
    );
    const output = try std.testing.allocator.alloc(u8, capacity);
    defer std.testing.allocator.free(output);
    var writer = std.Io.Writer.fixed(output);
    const rendered = template.renderWithOptions(
        &writer,
        context,
        case.render_options,
    ) catch |failure| {
        if (failure == error.WriteFailed) return error.FixtureOutputOverflow;
        return @as(anyerror!void, failure);
    };
    switch (rendered) {
        .success => return error.ExpectedRenderFailure,
        .failure => |diagnostic| {
            try std.testing.expectEqual(case.diagnostic.kind, diagnostic.kind);
            try std.testing.expectEqual(case.diagnostic.span, diagnostic.span);
            if (case.diagnostic.include_identity) |expected| {
                try std.testing.expectEqualStrings(expected, diagnostic.include_identity.?);
            }
            if (case.diagnostic.include_parent_identity) |expected| {
                try std.testing.expectEqualStrings(expected, diagnostic.include_parent_identity.?);
            }
            if (case.diagnostic.source_identity) |expected| {
                try std.testing.expectEqualStrings(expected, diagnostic.source_identity.?);
            }
            if (case.diagnostic.callback_error) |expected| {
                try std.testing.expectEqualStrings(expected, diagnostic.callback_error.?);
            }
            if (case.diagnostic.include_compile_diagnostic) |expected| {
                const actual = diagnostic.include_compile_diagnostic.?;
                try std.testing.expectEqual(expected.kind, actual.kind);
                try std.testing.expectEqual(expected.span, actual.span);
            }
        },
    }
    if (case.expected_prefix) |prefix| try std.testing.expectEqualStrings(
        prefix,
        std.Io.Writer.buffered(&writer),
    );
}
