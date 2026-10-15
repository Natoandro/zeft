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
const direct_callables = [_]zeft.Registration{
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

const pipe_callables = [_]zeft.Registration{
    .{ .name = "negate", .callback = negate },
    .{ .name = "append", .callback = append },
};
const callables = direct_callables ++ pipe_callables;
const override_callables = callables ++ [_]zeft.Registration{.{
    .name = "length",
    .callback = overrideLength,
}};
const override_callables_with_upper = override_callables ++ [_]zeft.Registration{.{
    .name = "upper",
    .callback = append,
}};
const render_options: zeft.RenderOptions = .{
    .allocator = std.testing.allocator,
    .callables = &callables,
};
const override_options: zeft.RenderOptions = .{
    .allocator = std.testing.allocator,
    .callables = &override_callables_with_upper,
};

test "expression fixtures compile and render exact output" {
    try fixtures.expectSuccessCases(expression_cases.success_cases);
}

fn identity(
    _: std.mem.Allocator,
    _: ?*const anyopaque,
    args: []const zeft.Value,
) anyerror!zeft.Value {
    if (args.len != 1) return error.InvalidArguments;
    return args[0];
}

fn trustedValue(
    _: std.mem.Allocator,
    pointer: ?*const anyopaque,
    args: []const zeft.Value,
) anyerror!zeft.Value {
    if (args.len != 0) return error.InvalidArguments;
    const raw = pointer orelse return error.MissingValue;
    const value: *const zeft.Value = @ptrCast(@alignCast(raw));
    return value.*;
}

test "postfix selectors follow grouped expressions and call results" {
    const compiled = try zeft.compile(
        std.testing.allocator,
        "{{ (profile.user).name }}|{{ identity(profile.user).label }}|" ++
            "{{ identity(people)[1].name }}",
        .{},
    );
    var template = switch (compiled) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();

    const registrations = [_]zeft.Registration{.{ .name = "identity", .callback = identity }};
    var output: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.renderWithOptions(&writer, &Context{}, .{
        .allocator = std.testing.allocator,
        .callables = &registrations,
    });
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings("Ada|engineer|Grace", std.Io.Writer.buffered(&writer));
}

test "native numbers and optionals adapt through root nested and sequence values" {
    const NativeContext = struct {
        signed: i16 = -12,
        unsigned: u32 = 42,
        single: f32 = 1.5,
        absent: ?i64 = null,
        nested: struct { value: ?u8 = 7 } = .{},
        sequence: [2]?i32 = .{ 9, null },
    };
    const compiled = try zeft.compile(
        std.testing.allocator,
        "{{ signed }}|{{ unsigned }}|{{ single }}|{{ absent }}|" ++
            "{{ nested.value }}|{{ sequence[0] }}|{{ sequence[1] }}",
        .{},
    );
    var template = switch (compiled) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    var output: [128]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, &NativeContext{});
    try std.testing.expectEqual(zeft.RenderResult.success, rendered);
    try std.testing.expectEqualStrings(
        "-12|42|1.5||7|9|",
        std.Io.Writer.buffered(&writer),
    );
}

test "out of range unsigned native values report invalid_operand" {
    const OverflowContext = struct { value: u64 };
    const compiled = try zeft.compile(std.testing.allocator, "{{ value }}", .{});
    var template = switch (compiled) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    var output: [32]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const rendered = try template.render(&writer, &OverflowContext{
        .value = std.math.maxInt(u64),
    });
    try std.testing.expect(rendered == .failure);
    try std.testing.expectEqual(zeft.RenderErrorKind.invalid_operand, rendered.failure.kind);
}

const NativeValueWorker = struct {
    template: *const zeft.CompiledTemplate,
    value: i64,
    expected: []const u8,
    failed: bool = false,

    fn run(self: *NativeValueWorker) void {
        var output: [32]u8 = undefined;
        var writer = std.Io.Writer.fixed(&output);
        const ContextType = struct { value: i64 };
        const rendered = self.template.render(&writer, &ContextType{ .value = self.value }) catch {
            self.failed = true;
            return;
        };
        self.failed = rendered != .success or
            !std.mem.eql(u8, std.Io.Writer.buffered(&writer), self.expected);
    }
};

test "native numeric contexts adapt independently during concurrent renders" {
    const compiled = try zeft.compile(std.testing.allocator, "{{ value }}", .{});
    var template = switch (compiled) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer template.deinit();
    var workers = [_]NativeValueWorker{
        .{ .template = &template, .value = -7, .expected = "-7" },
        .{ .template = &template, .value = 0, .expected = "0" },
        .{ .template = &template, .value = 19, .expected = "19" },
        .{ .template = &template, .value = 42, .expected = "42" },
    };
    var threads: [workers.len]std.Thread = undefined;
    for (&workers, 0..) |*worker, index| {
        threads[index] = try std.Thread.spawn(.{}, NativeValueWorker.run, .{worker});
    }
    for (threads) |thread| thread.join();
    for (workers) |worker| try std.testing.expect(!worker.failed);
}

test "trusted HTML and XML output requires a matching text context" {
    const html = zeft.Value{ .trusted_html = "<b>&</b>" };
    const xml = zeft.Value{ .trusted_xml = "<b>&amp;</b>" };
    const html_registration = [_]zeft.Registration{.{
        .name = "value",
        .callback = trustedValue,
        .user_data = &html,
    }};
    const xml_registration = [_]zeft.Registration{.{
        .name = "value",
        .callback = trustedValue,
        .user_data = &xml,
    }};

    const html_compiled = try zeft.compile(std.testing.allocator, "{{ value() }}", .{});
    var html_template = switch (html_compiled) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer html_template.deinit();
    var output: [64]u8 = undefined;
    var writer = std.Io.Writer.fixed(&output);
    const html_result = try html_template.renderWithOptions(&writer, .{}, .{
        .allocator = std.testing.allocator,
        .callables = &html_registration,
    });
    try std.testing.expectEqual(zeft.RenderResult.success, html_result);
    try std.testing.expectEqualStrings("<b>&</b>", std.Io.Writer.buffered(&writer));

    const mismatch_result = try html_template.renderWithOptions(&writer, .{}, .{
        .allocator = std.testing.allocator,
        .callables = &xml_registration,
    });
    try std.testing.expect(mismatch_result == .failure);
    try std.testing.expectEqual(
        zeft.RenderErrorKind.invalid_operand,
        mismatch_result.failure.kind,
    );

    const attribute_compiled = try zeft.compile(
        std.testing.allocator,
        "<p title=\"{{ value() }}\"></p>",
        .{},
    );
    var attribute_template = switch (attribute_compiled) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer attribute_template.deinit();
    const attribute_result = try attribute_template.renderWithOptions(&writer, .{}, .{
        .allocator = std.testing.allocator,
        .callables = &html_registration,
    });
    try std.testing.expect(attribute_result == .failure);
    try std.testing.expectEqual(
        zeft.RenderErrorKind.invalid_operand,
        attribute_result.failure.kind,
    );

    const xml_compiled = try zeft.compile(
        std.testing.allocator,
        "{{ value() }}",
        .{ .format = .xml },
    );
    var xml_template = switch (xml_compiled) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer xml_template.deinit();
    var xml_output: [64]u8 = undefined;
    var xml_writer = std.Io.Writer.fixed(&xml_output);
    const xml_result = try xml_template.renderWithOptions(&xml_writer, .{}, .{
        .allocator = std.testing.allocator,
        .callables = &xml_registration,
    });
    try std.testing.expectEqual(zeft.RenderResult.success, xml_result);
    try std.testing.expectEqualStrings(
        "<b>&amp;</b>",
        std.Io.Writer.buffered(&xml_writer),
    );
    const xml_mismatch = try xml_template.renderWithOptions(&xml_writer, .{}, .{
        .allocator = std.testing.allocator,
        .callables = &html_registration,
    });
    try std.testing.expect(xml_mismatch == .failure);
    try std.testing.expectEqual(
        zeft.RenderErrorKind.invalid_operand,
        xml_mismatch.failure.kind,
    );

    const xml_attribute_compiled = try zeft.compile(
        std.testing.allocator,
        "<p title=\"{{ value() }}\"/>",
        .{ .format = .xml },
    );
    var xml_attribute_template = switch (xml_attribute_compiled) {
        .success => |value| value,
        .failure => return error.UnexpectedCompileFailure,
    };
    defer xml_attribute_template.deinit();
    const xml_attribute_result = try xml_attribute_template.renderWithOptions(
        &xml_writer,
        .{},
        .{
            .allocator = std.testing.allocator,
            .callables = &xml_registration,
        },
    );
    try std.testing.expect(xml_attribute_result == .failure);
    try std.testing.expectEqual(
        zeft.RenderErrorKind.invalid_operand,
        xml_attribute_result.failure.kind,
    );
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
        .callables = &registrations,
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
        .callables = &registration,
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
        .{ .allocator = std.testing.allocator, .callables = &registration },
    );
    try std.testing.expect(exact_float_result == .failure);
    try std.testing.expectEqual(
        zeft.RenderErrorKind.invalid_operand,
        exact_float_result.failure.kind,
    );
}
