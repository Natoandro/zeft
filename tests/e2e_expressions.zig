//! Expression and native context golden fixtures (ZEP-077).
const std = @import("std");
const zeft = @import("zeft");
const fixtures = @import("fixture_runner.zig");

pub const success_cases = [_]fixtures.Success{
    .{
        .id = "EX-001",
        .path = "fixtures/expressions/arithmetic-all.tmpl",
        .expected_path = "fixtures/expressions/arithmetic-all.out",
        .source = @embedFile("fixtures/expressions/arithmetic-all.tmpl"),
        .expected = @embedFile("fixtures/expressions/arithmetic-all.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-002",
        .path = "fixtures/expressions/comparison-all.tmpl",
        .expected_path = "fixtures/expressions/comparison-all.out",
        .source = @embedFile("fixtures/expressions/comparison-all.tmpl"),
        .expected = @embedFile("fixtures/expressions/comparison-all.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-003",
        .path = "fixtures/expressions/comparison-false.tmpl",
        .expected_path = "fixtures/expressions/comparison-false.out",
        .source = @embedFile("fixtures/expressions/comparison-false.tmpl"),
        .expected = @embedFile("fixtures/expressions/comparison-false.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-004",
        .path = "fixtures/expressions/logical-all.tmpl",
        .expected_path = "fixtures/expressions/logical-all.out",
        .source = @embedFile("fixtures/expressions/logical-all.tmpl"),
        .expected = @embedFile("fixtures/expressions/logical-all.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-005",
        .path = "fixtures/expressions/precedence-or-and.tmpl",
        .expected_path = "fixtures/expressions/precedence-or-and.out",
        .source = @embedFile("fixtures/expressions/precedence-or-and.tmpl"),
        .expected = @embedFile("fixtures/expressions/precedence-or-and.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-006",
        .path = "fixtures/expressions/precedence-and-equal.tmpl",
        .expected_path = "fixtures/expressions/precedence-and-equal.out",
        .source = @embedFile("fixtures/expressions/precedence-and-equal.tmpl"),
        .expected = @embedFile("fixtures/expressions/precedence-and-equal.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-007",
        .path = "fixtures/expressions/precedence-equal-compare.tmpl",
        .expected_path = "fixtures/expressions/precedence-equal-compare.out",
        .source = @embedFile("fixtures/expressions/precedence-equal-compare.tmpl"),
        .expected = @embedFile("fixtures/expressions/precedence-equal-compare.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-008",
        .path = "fixtures/expressions/precedence-compare-add.tmpl",
        .expected_path = "fixtures/expressions/precedence-compare-add.out",
        .source = @embedFile("fixtures/expressions/precedence-compare-add.tmpl"),
        .expected = @embedFile("fixtures/expressions/precedence-compare-add.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-009",
        .path = "fixtures/expressions/precedence-add-multiply.tmpl",
        .expected_path = "fixtures/expressions/precedence-add-multiply.out",
        .source = @embedFile("fixtures/expressions/precedence-add-multiply.tmpl"),
        .expected = @embedFile("fixtures/expressions/precedence-add-multiply.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-010",
        .path = "fixtures/expressions/precedence-multiply-unary.tmpl",
        .expected_path = "fixtures/expressions/precedence-multiply-unary.out",
        .source = @embedFile("fixtures/expressions/precedence-multiply-unary.tmpl"),
        .expected = @embedFile("fixtures/expressions/precedence-multiply-unary.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-011",
        .path = "fixtures/expressions/unary-associativity.tmpl",
        .expected_path = "fixtures/expressions/unary-associativity.out",
        .source = @embedFile("fixtures/expressions/unary-associativity.tmpl"),
        .expected = @embedFile("fixtures/expressions/unary-associativity.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-012",
        .path = "fixtures/expressions/binary-associativity.tmpl",
        .expected_path = "fixtures/expressions/binary-associativity.out",
        .source = @embedFile("fixtures/expressions/binary-associativity.tmpl"),
        .expected = @embedFile("fixtures/expressions/binary-associativity.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-013",
        .path = "fixtures/expressions/mixed-associativity.tmpl",
        .expected_path = "fixtures/expressions/mixed-associativity.out",
        .source = @embedFile("fixtures/expressions/mixed-associativity.tmpl"),
        .expected = @embedFile("fixtures/expressions/mixed-associativity.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-014",
        .path = "fixtures/expressions/grouping-nested.tmpl",
        .expected_path = "fixtures/expressions/grouping-nested.out",
        .source = @embedFile("fixtures/expressions/grouping-nested.tmpl"),
        .expected = @embedFile("fixtures/expressions/grouping-nested.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-015",
        .path = "fixtures/expressions/numbers-integer.tmpl",
        .expected_path = "fixtures/expressions/numbers-integer.out",
        .source = @embedFile("fixtures/expressions/numbers-integer.tmpl"),
        .expected = @embedFile("fixtures/expressions/numbers-integer.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-016",
        .path = "fixtures/expressions/numbers-decimal.tmpl",
        .expected_path = "fixtures/expressions/numbers-decimal.out",
        .source = @embedFile("fixtures/expressions/numbers-decimal.tmpl"),
        .expected = @embedFile("fixtures/expressions/numbers-decimal.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-017",
        .path = "fixtures/expressions/numbers-exponent.tmpl",
        .expected_path = "fixtures/expressions/numbers-exponent.out",
        .source = @embedFile("fixtures/expressions/numbers-exponent.tmpl"),
        .expected = @embedFile("fixtures/expressions/numbers-exponent.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-018",
        .path = "fixtures/expressions/numbers-negative-exponent.tmpl",
        .expected_path = "fixtures/expressions/numbers-negative-exponent.out",
        .source = @embedFile("fixtures/expressions/numbers-negative-exponent.tmpl"),
        .expected = @embedFile("fixtures/expressions/numbers-negative-exponent.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-019",
        .path = "fixtures/expressions/string-six-escapes.tmpl",
        .expected_path = "fixtures/expressions/string-six-escapes.out",
        .source = @embedFile("fixtures/expressions/string-six-escapes.tmpl"),
        .expected = @embedFile("fixtures/expressions/string-six-escapes.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-020",
        .path = "fixtures/expressions/string-quotes.tmpl",
        .expected_path = "fixtures/expressions/string-quotes.out",
        .source = @embedFile("fixtures/expressions/string-quotes.tmpl"),
        .expected = @embedFile("fixtures/expressions/string-quotes.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-021",
        .path = "fixtures/expressions/identifier-case.tmpl",
        .expected_path = "fixtures/expressions/identifier-case.out",
        .source = @embedFile("fixtures/expressions/identifier-case.tmpl"),
        .expected = @embedFile("fixtures/expressions/identifier-case.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-022",
        .path = "fixtures/expressions/identifier-repeated.tmpl",
        .expected_path = "fixtures/expressions/identifier-repeated.out",
        .source = @embedFile("fixtures/expressions/identifier-repeated.tmpl"),
        .expected = @embedFile("fixtures/expressions/identifier-repeated.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-023",
        .path = "fixtures/expressions/boolean-literals.tmpl",
        .expected_path = "fixtures/expressions/boolean-literals.out",
        .source = @embedFile("fixtures/expressions/boolean-literals.tmpl"),
        .expected = @embedFile("fixtures/expressions/boolean-literals.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-024",
        .path = "fixtures/expressions/nested-properties.tmpl",
        .expected_path = "fixtures/expressions/nested-properties.out",
        .source = @embedFile("fixtures/expressions/nested-properties.tmpl"),
        .expected = @embedFile("fixtures/expressions/nested-properties.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-025",
        .path = "fixtures/expressions/arrays-slices.tmpl",
        .expected_path = "fixtures/expressions/arrays-slices.out",
        .source = @embedFile("fixtures/expressions/arrays-slices.tmpl"),
        .expected = @embedFile("fixtures/expressions/arrays-slices.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-026",
        .path = "fixtures/expressions/dynamic-index-literal.tmpl",
        .expected_path = "fixtures/expressions/dynamic-index-literal.out",
        .source = @embedFile("fixtures/expressions/dynamic-index-literal.tmpl"),
        .expected = @embedFile("fixtures/expressions/dynamic-index-literal.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-027",
        .path = "fixtures/expressions/dynamic-index-call.tmpl",
        .expected_path = "fixtures/expressions/dynamic-index-call.out",
        .source = @embedFile("fixtures/expressions/dynamic-index-call.tmpl"),
        .expected = @embedFile("fixtures/expressions/dynamic-index-call.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-028",
        .path = "fixtures/expressions/nested-index.tmpl",
        .expected_path = "fixtures/expressions/nested-index.out",
        .source = @embedFile("fixtures/expressions/nested-index.tmpl"),
        .expected = @embedFile("fixtures/expressions/nested-index.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-029",
        .path = "fixtures/expressions/string-adapters.tmpl",
        .expected_path = "fixtures/expressions/string-adapters.out",
        .source = @embedFile("fixtures/expressions/string-adapters.tmpl"),
        .expected = @embedFile("fixtures/expressions/string-adapters.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-030",
        .path = "fixtures/expressions/sequence-boolean-adapter.tmpl",
        .expected_path = "fixtures/expressions/sequence-boolean-adapter.out",
        .source = @embedFile("fixtures/expressions/sequence-boolean-adapter.tmpl"),
        .expected = @embedFile("fixtures/expressions/sequence-boolean-adapter.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-031",
        .path = "fixtures/expressions/short-circuit-root.tmpl",
        .expected_path = "fixtures/expressions/short-circuit-root.out",
        .source = @embedFile("fixtures/expressions/short-circuit-root.tmpl"),
        .expected = @embedFile("fixtures/expressions/short-circuit-root.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-032",
        .path = "fixtures/expressions/short-circuit-access.tmpl",
        .expected_path = "fixtures/expressions/short-circuit-access.out",
        .source = @embedFile("fixtures/expressions/short-circuit-access.tmpl"),
        .expected = @embedFile("fixtures/expressions/short-circuit-access.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-033",
        .path = "fixtures/expressions/short-circuit-call.tmpl",
        .expected_path = "fixtures/expressions/short-circuit-call.out",
        .source = @embedFile("fixtures/expressions/short-circuit-call.tmpl"),
        .expected = @embedFile("fixtures/expressions/short-circuit-call.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-034",
        .path = "fixtures/expressions/short-circuit-filter.tmpl",
        .expected_path = "fixtures/expressions/short-circuit-filter.out",
        .source = @embedFile("fixtures/expressions/short-circuit-filter.tmpl"),
        .expected = @embedFile("fixtures/expressions/short-circuit-filter.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-035",
        .path = "fixtures/expressions/builtin-length.tmpl",
        .expected_path = "fixtures/expressions/builtin-length.out",
        .source = @embedFile("fixtures/expressions/builtin-length.tmpl"),
        .expected = @embedFile("fixtures/expressions/builtin-length.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-036",
        .path = "fixtures/expressions/builtin-case.tmpl",
        .expected_path = "fixtures/expressions/builtin-case.out",
        .source = @embedFile("fixtures/expressions/builtin-case.tmpl"),
        .expected = @embedFile("fixtures/expressions/builtin-case.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-037",
        .path = "fixtures/expressions/builtin-trim.tmpl",
        .expected_path = "fixtures/expressions/builtin-trim.out",
        .source = @embedFile("fixtures/expressions/builtin-trim.tmpl"),
        .expected = @embedFile("fixtures/expressions/builtin-trim.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-038",
        .path = "fixtures/expressions/builtin-default.tmpl",
        .expected_path = "fixtures/expressions/builtin-default.out",
        .source = @embedFile("fixtures/expressions/builtin-default.tmpl"),
        .expected = @embedFile("fixtures/expressions/builtin-default.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-039",
        .path = "fixtures/expressions/builtin-pipeline.tmpl",
        .expected_path = "fixtures/expressions/builtin-pipeline.out",
        .source = @embedFile("fixtures/expressions/builtin-pipeline.tmpl"),
        .expected = @embedFile("fixtures/expressions/builtin-pipeline.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-040",
        .path = "fixtures/expressions/function-zero.tmpl",
        .expected_path = "fixtures/expressions/function-zero.out",
        .source = @embedFile("fixtures/expressions/function-zero.tmpl"),
        .expected = @embedFile("fixtures/expressions/function-zero.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-041",
        .path = "fixtures/expressions/function-many.tmpl",
        .expected_path = "fixtures/expressions/function-many.out",
        .source = @embedFile("fixtures/expressions/function-many.tmpl"),
        .expected = @embedFile("fixtures/expressions/function-many.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-042",
        .path = "fixtures/expressions/function-nested.tmpl",
        .expected_path = "fixtures/expressions/function-nested.out",
        .source = @embedFile("fixtures/expressions/function-nested.tmpl"),
        .expected = @embedFile("fixtures/expressions/function-nested.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-043",
        .path = "fixtures/expressions/filter-zero.tmpl",
        .expected_path = "fixtures/expressions/filter-zero.out",
        .source = @embedFile("fixtures/expressions/filter-zero.tmpl"),
        .expected = @embedFile("fixtures/expressions/filter-zero.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-044",
        .path = "fixtures/expressions/filter-many.tmpl",
        .expected_path = "fixtures/expressions/filter-many.out",
        .source = @embedFile("fixtures/expressions/filter-many.tmpl"),
        .expected = @embedFile("fixtures/expressions/filter-many.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-045",
        .path = "fixtures/expressions/filter-pipeline-order.tmpl",
        .expected_path = "fixtures/expressions/filter-pipeline-order.out",
        .source = @embedFile("fixtures/expressions/filter-pipeline-order.tmpl"),
        .expected = @embedFile("fixtures/expressions/filter-pipeline-order.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-046",
        .path = "fixtures/expressions/filter-nested-call.tmpl",
        .expected_path = "fixtures/expressions/filter-nested-call.out",
        .source = @embedFile("fixtures/expressions/filter-nested-call.tmpl"),
        .expected = @embedFile("fixtures/expressions/filter-nested-call.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-047",
        .path = "fixtures/expressions/registration-user-data.tmpl",
        .expected_path = "fixtures/expressions/registration-user-data.out",
        .source = @embedFile("fixtures/expressions/registration-user-data.tmpl"),
        .expected = @embedFile("fixtures/expressions/registration-user-data.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-048",
        .path = "fixtures/expressions/function-override.tmpl",
        .expected_path = "fixtures/expressions/function-override.out",
        .source = @embedFile("fixtures/expressions/function-override.tmpl"),
        .expected = @embedFile("fixtures/expressions/function-override.out"),
        .render_options = override_options,
    },
    .{
        .id = "EX-049",
        .path = "fixtures/expressions/filter-override.tmpl",
        .expected_path = "fixtures/expressions/filter-override.out",
        .source = @embedFile("fixtures/expressions/filter-override.tmpl"),
        .expected = @embedFile("fixtures/expressions/filter-override.out"),
        .render_options = override_options,
    },
    .{
        .id = "EX-050",
        .path = "fixtures/expressions/filter-or-precedence.tmpl",
        .expected_path = "fixtures/expressions/filter-or-precedence.out",
        .source = @embedFile("fixtures/expressions/filter-or-precedence.tmpl"),
        .expected = @embedFile("fixtures/expressions/filter-or-precedence.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-051",
        .path = "fixtures/expressions/runtime-arithmetic.tmpl",
        .expected_path = "fixtures/expressions/runtime-arithmetic.out",
        .source = @embedFile("fixtures/expressions/runtime-arithmetic.tmpl"),
        .expected = @embedFile("fixtures/expressions/runtime-arithmetic.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-052",
        .path = "fixtures/expressions/runtime-comparison.tmpl",
        .expected_path = "fixtures/expressions/runtime-comparison.out",
        .source = @embedFile("fixtures/expressions/runtime-comparison.tmpl"),
        .expected = @embedFile("fixtures/expressions/runtime-comparison.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-053",
        .path = "fixtures/expressions/same-type-equality.tmpl",
        .expected_path = "fixtures/expressions/same-type-equality.out",
        .source = @embedFile("fixtures/expressions/same-type-equality.tmpl"),
        .expected = @embedFile("fixtures/expressions/same-type-equality.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-054",
        .path = "fixtures/expressions/index-root-symbol.tmpl",
        .expected_path = "fixtures/expressions/index-root-symbol.out",
        .source = @embedFile("fixtures/expressions/index-root-symbol.tmpl"),
        .expected = @embedFile("fixtures/expressions/index-root-symbol.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-055",
        .path = "fixtures/expressions/unary-selectors.tmpl",
        .expected_path = "fixtures/expressions/unary-selectors.out",
        .source = @embedFile("fixtures/expressions/unary-selectors.tmpl"),
        .expected = @embedFile("fixtures/expressions/unary-selectors.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-056",
        .path = "fixtures/expressions/short-circuit-folded-branch.tmpl",
        .expected_path = "fixtures/expressions/short-circuit-folded-branch.out",
        .source = @embedFile("fixtures/expressions/short-circuit-folded-branch.tmpl"),
        .expected = @embedFile("fixtures/expressions/short-circuit-folded-branch.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-057",
        .path = "fixtures/expressions/short-circuit-nested-branches.tmpl",
        .expected_path = "fixtures/expressions/short-circuit-nested-branches.out",
        .source = @embedFile("fixtures/expressions/short-circuit-nested-branches.tmpl"),
        .expected = @embedFile("fixtures/expressions/short-circuit-nested-branches.out"),
        .render_options = render_options,
    },

    .{
        .id = "EX-058",
        .path = "fixtures/expressions/function-pipeline.tmpl",
        .expected_path = "fixtures/expressions/function-pipeline.out",
        .source = @embedFile("fixtures/expressions/function-pipeline.tmpl"),
        .expected = @embedFile("fixtures/expressions/function-pipeline.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-059",
        .path = "fixtures/expressions/callable-name-collision.tmpl",
        .expected_path = "fixtures/expressions/callable-name-collision.out",
        .source = @embedFile("fixtures/expressions/callable-name-collision.tmpl"),
        .expected = @embedFile("fixtures/expressions/callable-name-collision.out"),
        .render_options = render_options,
    },
    .{
        .id = "EX-060",
        .path = "fixtures/expressions/null-interpolation.tmpl",
        .expected_path = "fixtures/expressions/null-interpolation.out",
        .source = @embedFile("fixtures/expressions/null-interpolation.tmpl"),
        .expected = @embedFile("fixtures/expressions/null-interpolation.out"),
        .render_options = render_options,
    },
};
const Person = struct { name: []const u8, label: []const u8 = "", active: bool = false };
const Context = struct {
    name: []const u8 = "ada",
    Name: []const u8 = "Grace",
    _name2: []const u8 = "under",
    TRUE: []const u8 = "uppercase",
    False: []const u8 = "mixed",
    Null: []const u8 = "identifier",
    flag: bool = true,
    flags: [2]bool = .{ true, false },
    fixed: [4]u8 = "byte".*,
    profile: struct { user: Person } = .{ .user = .{ .name = "Ada", .label = "engineer" } },
    people: [2]Person = .{ .{ .name = "Ada" }, .{ .name = "Grace" } },
    aliases: []const []const u8 = &.{ "first", "second" },
    groups: [2][2]Person = .{
        .{
            .{ .name = "Ada" },
            .{ .name = "Grace" },
        },
        .{
            .{ .name = "Katherine" },
            .{ .name = "Dorothy" },
        },
    },
};

fn number(
    _: std.mem.Allocator,
    _: ?*const anyopaque,
    args: []const zeft.Value,
) anyerror!zeft.Value {
    if (args.len != 0) return error.InvalidArguments;
    return .{ .number = 2 };
}

fn greeting(
    _: std.mem.Allocator,
    _: ?*const anyopaque,
    args: []const zeft.Value,
) anyerror!zeft.Value {
    if (args.len != 0) return error.InvalidArguments;
    return .{ .string = "hello" };
}

fn join(
    allocator: std.mem.Allocator,
    _: ?*const anyopaque,
    args: []const zeft.Value,
) anyerror!zeft.Value {
    var output: std.ArrayList(u8) = .empty;
    defer output.deinit(allocator);
    for (args) |arg| {
        if (arg != .string) return error.InvalidArguments;
        try output.appendSlice(allocator, arg.string);
    }
    return .{ .string = try output.toOwnedSlice(allocator) };
}

fn append(
    allocator: std.mem.Allocator,
    callback_data: ?*const anyopaque,
    args: []const zeft.Value,
) anyerror!zeft.Value {
    if (args.len == 0) return error.InvalidArguments;
    if (args.len != 1) return join(allocator, callback_data, args);
    const extra = [_]zeft.Value{ args[0], .{ .string = "!" } };
    return join(allocator, callback_data, &extra);
}

const UserData = struct { value: []const u8 };
const user_data = UserData{ .value = "user-data" };
fn configured(
    _: std.mem.Allocator,
    data_pointer: ?*const anyopaque,
    _: []const zeft.Value,
) anyerror!zeft.Value {
    const raw_data = data_pointer orelse return error.MissingUserData;
    const data: *const UserData = @ptrCast(@alignCast(raw_data));
    return .{ .string = data.value };
}
fn fail(_: std.mem.Allocator, _: ?*const anyopaque, _: []const zeft.Value) anyerror!zeft.Value {
    return error.DeliberateFailure;
}
fn overrideLength(
    _: std.mem.Allocator,
    _: ?*const anyopaque,
    args: []const zeft.Value,
) anyerror!zeft.Value {
    if (args.len != 1) return error.InvalidArguments;
    return .{ .number = 99 };
}
fn functionChoice(
    _: std.mem.Allocator,
    _: ?*const anyopaque,
    _: []const zeft.Value,
) anyerror!zeft.Value {
    return .{ .string = "function" };
}
fn filterChoice(
    _: std.mem.Allocator,
    _: ?*const anyopaque,
    _: []const zeft.Value,
) anyerror!zeft.Value {
    return .{ .string = "filter" };
}

const functions = [_]zeft.Registration{
    .{ .name = "number", .callback = number },
    .{ .name = "greeting", .callback = greeting },
    .{ .name = "join", .callback = join },
    .{ .name = "configured", .callback = configured, .user_data = &user_data },
    .{ .name = "fail", .callback = fail },
    .{ .name = "choose", .callback = functionChoice },
};
fn negate(
    _: std.mem.Allocator,
    _: ?*const anyopaque,
    args: []const zeft.Value,
) anyerror!zeft.Value {
    if (args.len != 1 or args[0] != .boolean) return error.InvalidArguments;
    return .{ .boolean = !args[0].boolean };
}

const filters = [_]zeft.Registration{
    .{ .name = "negate", .callback = negate },
    .{ .name = "append", .callback = append },
    .{ .name = "configured", .callback = configured, .user_data = &user_data },
    .{ .name = "fail", .callback = fail },
    .{ .name = "choose", .callback = filterChoice },
};
const override_functions = functions ++ [_]zeft.Registration{.{
    .name = "length",
    .callback = overrideLength,
}};
const override_filters = filters ++ [_]zeft.Registration{.{ .name = "upper", .callback = append }};
const render_options: zeft.RenderOptions = .{
    .allocator = std.testing.allocator,
    .functions = &functions,
    .filters = &filters,
};
const override_options: zeft.RenderOptions = .{
    .allocator = std.testing.allocator,
    .functions = &override_functions,
    .filters = &override_filters,
};

test "expression fixtures compile and render exact output" {
    const context: Context = .{};
    var failures: usize = 0;
    for (success_cases) |case| {
        fixtures.expectSuccess(case, &context) catch {
            failures += 1;
        };
    }
    try std.testing.expectEqual(@as(usize, 0), failures);
}
