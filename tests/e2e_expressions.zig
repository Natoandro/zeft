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
    try fixtures.expectSuccessCases(expression_cases.success_cases);
}
