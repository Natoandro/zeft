//! Expression and native context golden fixtures (ZEP-077).
const std = @import("std");
const zeft = @import("zeft");
const fixtures = @import("fixture_runner.zig");
const expression_cases = @import("fixtures/expressions.zig");

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
    return .{ .float = 2 };
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
    return .{ .float = 99 };
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
    try fixtures.expectSuccessCases(expression_cases.success_cases);
}

fn numericConstant(
    _: std.mem.Allocator,
    pointer: ?*const anyopaque,
    args: []const zeft.Value,
) anyerror!zeft.Value {
    if (args.len != 0) return error.InvalidArguments;
    const raw = pointer orelse return error.MissingValue;
    const value: *const zeft.Value = @ptrCast(@alignCast(raw));
    return value.*;
}

test "signed integers preserve exact values and numeric semantics" {
    const min_value = zeft.Value{ .integer = std.math.minInt(i64) };
    const max_value = zeft.Value{ .integer = std.math.maxInt(i64) };
    const precise_int = zeft.Value{ .integer = 9007199254740993 };
    const rounded_float = zeft.Value{ .float = 9007199254740992 };
    const one = zeft.Value{ .integer = 1 };
    const three = zeft.Value{ .integer = 3 };
    const registrations = [_]zeft.Registration{
        .{ .name = "min", .callback = numericConstant, .user_data = &min_value },
        .{ .name = "max", .callback = numericConstant, .user_data = &max_value },
        .{ .name = "precise", .callback = numericConstant, .user_data = &precise_int },
        .{ .name = "rounded", .callback = numericConstant, .user_data = &rounded_float },
        .{ .name = "one", .callback = numericConstant, .user_data = &one },
        .{ .name = "three", .callback = numericConstant, .user_data = &three },
    };
    const source = "{{ min() }}|{{ max() }}|{{ min() + one() }}|{{ max() - one() }}|" ++
        "{{ one() * three() }}|{{ max() % three() }}|" ++
        "{{ min() < rounded() }}|{{ precise() > rounded() }}|" ++
        "{{ precise() == rounded() }}|{{ max() < 9223372036854775808 }}|" ++
        "{{ min() == -9223372036854775808 }}|{{ max() + 0.5 }}|" ++
        "{{ one() + 0.5 }}|{{ 7 / 2 }}|{{ 5.0 + 2 }}";
    const compiled = try zeft.compile(std.testing.allocator, source, .{});
    var template = switch (compiled) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    var output: [512]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.renderWithOptions(&writer, .{}, .{
        .allocator = std.testing.allocator,
        .functions = &registrations,
    });
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings(
        "-9223372036854775808|9223372036854775807|-9223372036854775807|" ++
            "9223372036854775806|3|1|true|true|false|" ++
            "false|true|9223372036854776000|1.5|3.5|7",
        std.Io.Writer.buffered(&writer),
    );
}

test "signed integer overflow reports invalid_operand" {
    const max_value = zeft.Value{ .integer = std.math.maxInt(i64) };
    const one = zeft.Value{ .integer = 1 };
    const registration = [_]zeft.Registration{
        .{ .name = "max", .callback = numericConstant, .user_data = &max_value },
        .{ .name = "one", .callback = numericConstant, .user_data = &one },
    };
    const compiled = try zeft.compile(std.testing.allocator, "{{ max() + one() }}", .{});
    var template = switch (compiled) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    var output: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.renderWithOptions(&writer, .{}, .{
        .allocator = std.testing.allocator,
        .functions = &registration,
    });
    try std.testing.expect(rendered == .failure);
    try std.testing.expectEqual(zeft.RenderErrorKind.invalid_operand, rendered.failure.kind);

    const exact_float_source = try zeft.compile(
        std.testing.allocator,
        "{{ max() + 1.0 }}",
        .{},
    );
    var exact_float_template = switch (exact_float_source) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer exact_float_template.deinit();
    var exact_float_output: [32]u8 = undefined;
    var exact_float_writer = std.Io.Writer.fixed(&exact_float_output);
    const exact_float_result = try exact_float_template.renderWithOptions(
        &exact_float_writer,
        .{},
        .{ .allocator = std.testing.allocator, .functions = &registration },
    );
    try std.testing.expect(exact_float_result == .failure);
    try std.testing.expectEqual(
        zeft.RenderErrorKind.invalid_operand,
        exact_float_result.failure.kind,
    );
}
