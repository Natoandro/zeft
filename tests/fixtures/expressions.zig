//! Expression and native context golden fixtures (ZEP-077).
const std = @import("std");
const zeft = @import("zeft");
const fixtures = @import("../fixture_runner.zig");

pub const SuccessCase = struct { fixture: fixtures.Success, params: Context };

pub const success_cases = [_]SuccessCase{
    .{
        .fixture = .{
            .id = "EX-001",
            .template = "{{ 7 + 3 }}|{{ 7 - 3 }}|{{ 7 * 3 }}|{{ 8 / 2 }}|{{ 8 % 3 }}",
            .output = "10|4|21|4|2",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-002",
            .template = "{{ 2 < 3 }}|{{ 2 <= 2 }}|{{ 3 > 2 }}|{{ 3 >= 3 }}|{{ 2 == 2 }}|{{ 2 != 3 }}",
            .output = "true|true|true|true|true|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-003",
            .template = "{{ 3 < 2 }}|{{ 3 <= 2 }}|{{ 2 > 3 }}|{{ 2 >= 3 }}|{{ 2 == 3 }}|{{ 2 != 2 }}",
            .output = "false|false|false|false|false|false",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-004",
            .template = "{{ true && true }}|{{ true && false }}|{{ false || true }}|{{ false || false }}",
            .output = "true|false|true|false",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-005",
            .template = "{{ true || false && false }}|{{ (true || false) && false }}",
            .output = "true|false",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-006",
            .template = "{{ false && true == false }}|{{ (false && true) == false }}",
            .output = "false|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-007",
            .template = "{{ true == 2 < 3 }}|{{ 3 > 2 == true }}",
            .output = "true|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-008",
            .template = "{{ 2 < 1 + 2 }}|{{ 5 - 2 >= 3 }}",
            .output = "true|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-009",
            .template = "{{ 1 + 2 * 3 }}|{{ (1 + 2) * 3 }}|{{ 12 / 3 - 1 }}",
            .output = "7|9|3",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-010",
            .template = "{{ -2 * 3 }}|{{ 2 * -3 }}|{{ -(-2) * 3 }}",
            .output = "-6|-6|6",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-011",
            .template = "{{ !!true }}|{{ !!!true }}|{{ --2 }}|{{ ---2 }}",
            .output = "true|false|2|-2",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-012",
            .template = "{{ 10 - 3 - 2 }}|{{ 24 / 4 / 2 }}|{{ 20 % 6 % 3 }}",
            .output = "5|3|2",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-013",
            .template = "{{ 10 - 3 + 2 }}|{{ 24 / 4 * 2 }}|{{ 5 + 3 - 2 }}",
            .output = "9|12|6",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-014",
            .template = "{{ ((2 + 3) * (7 - 3)) / 2 }}|{{ !(false || (true && false)) }}",
            .output = "10|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-015",
            .template = "{{ 0 }}|{{ 0007 }}|{{ 123 }}",
            .output = "0|7|123",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-016",
            .template = "{{ 0.5 }}|{{ 12.25 }}|{{ 001.50 }}",
            .output = "0.5|12.25|1.5",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-017",
            .template = "{{ 1e2 }}|{{ 2E2 }}|{{ 3e+2 }}|{{ 4E+1 }}",
            .output = "100|200|300|40",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-018",
            .template = "{{ 5e-1 }}|{{ 5E-2 }}|{{ 1.25e2 }}",
            .output = "0.5|0.05|125",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-019",
            .template = "{{ '\\\\\\'\\\"\\n\\r\\t' }}",
            .output = "\\'\"\n\r\t",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-020",
            .template = "{{ \"double\" }}|{{ 'single' }}|{{ \"\" }}|{{ '' }}",
            .output = "double|single||",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-021",
            .template = "{{ name }}|{{ Name }}|{{ _name2 }}|{{ TRUE }}|{{ False }}|{{ Null }}",
            .output = "ada|Grace|under|uppercase|mixed|identifier",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-022",
            .template = "{{ name }}|{{ name }}|{{ Name }}|{{ name }}",
            .output = "ada|ada|Grace|ada",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-023",
            .template = "{{ true }}|{{ false }}|{{ !flag }}|{{ flag }}",
            .output = "true|false|false|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-024",
            .template = "{{ profile.user.name }}|{{ profile.user.label }}",
            .output = "Ada|engineer",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-025",
            .template = "{{ people[0].name }}|{{ people[1].name }}|{{ aliases[0] }}|{{ aliases[1] }}",
            .output = "Ada|Grace|first|second",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-026",
            .template = "{{ people[1 - 1].name }}|{{ aliases[1 + 0] }}",
            .output = "Ada|second",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-027",
            .template = "{{ aliases[number() - 1] }}|{{ people[length(aliases) - 2].name }}",
            .output = "second|Ada",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-028",
            .template = "{{ groups[1][0].name }}|{{ groups[0][1].name }}",
            .output = "Katherine|Grace",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-029",
            .template = "{{ fixed }}|{{ name }}|{{ profile.user.name }}",
            .output = "byte|ada|Ada",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-030",
            .template = "{{ flags[0] }}|{{ flags[1] }}",
            .output = "true|false",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-031",
            .template = "{{ false && absent }}|{{ true || absent }}",
            .output = "false|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-032",
            .template = "{{ false && profile.absent }}|{{ true || people[99].name }}",
            .output = "false|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-033",
            .template = "{{ false && fail() }}|{{ true || fail() }}",
            .output = "false|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-034",
            .template = "{{ true || name | fail }}|{{ false && name | fail }}",
            .output = "true|false",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-035",
            .template = "{{ length(name) }}|{{ length(aliases) }}|{{ length(people) }}|{{ length('\xc3\xa9') }}",
            .output = "3|2|2|2",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-036",
            .template = "{{ name | upper }}|{{ Name | lower }}|{{ '\xc3\xa9\xc3\x9faZ' | upper }}|{{ '\xc3\x89\xc3\x9fAZ' | lower }}",
            .output = "ADA|grace|\xc3\xa9\xc3\x9fAZ|\xc3\x89\xc3\x9faz",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-037",
            .template = "{{ ' \\t\\r\\n hello \\n\\r\\t ' | trim }}|{{ ' a b ' | trim }}",
            .output = "hello|a b",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-038",
            .template = "{{ null | default('fallback') }}|{{ '' | default('empty') }}|{{ name | default('other') }}",
            .output = "fallback|empty|ada",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-039",
            .template = "{{ '  aDa  ' | trim | upper | lower }}",
            .output = "ada",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-040",
            .template = "{{ number() }}|{{ greeting() }}",
            .output = "2|hello",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-041",
            .template = "{{ join('a', 'b', 'c') }}",
            .output = "abc",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-042",
            .template = "{{ join(greeting(), join(' ' , Name)) }}",
            .output = "hello Grace",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-043",
            .template = "{{ name | append }}|{{ name | append() }}",
            .output = "ada!|ada!",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-044",
            .template = "{{ name | append('-', Name) }}",
            .output = "ada-Grace",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-045",
            .template = "{{ name | append('x') | append('y') }}",
            .output = "adaxy",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-046",
            .template = "{{ name | append(join('-', greeting())) }}",
            .output = "ada-hello",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-047",
            .template = "{{ configured() }}|{{ name | configured }}",
            .output = "user-data|user-data",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-048",
            .template = "{{ length(name) }}",
            .output = "99",
            .render_options = override_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-049",
            .template = "{{ name | upper }}",
            .output = "ada!",
            .render_options = override_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-050",
            .template = "{{ true || true | negate }}|{{ (true || true) | negate }}",
            .output = "true|false",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-051",
            .template = "{{ number() + 3 }}|{{ number() - 3 }}|{{ number() * 3 }}|{{ number() / 2 }}|{{ number() % 2 }}",
            .output = "5|-1|6|1|0",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-052",
            .template = "{{ number() < 3 }}|{{ number() <= 2 }}|{{ number() > 1 }}|{{ number() >= 2 }}|{{ number() == 2 }}|{{ number() != 3 }}",
            .output = "true|true|true|true|true|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-053",
            .template = "{{ name == 'ada' }}|{{ name != Name }}|{{ flag == true }}|{{ null == null }}",
            .output = "true|true|true|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-054",
            .template = "{{ aliases[length(name) - 3] }}",
            .output = "first",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-055",
            .template = "{{ !flags[0] }}|{{ !people[0].active }}",
            .output = "false|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-056",
            .template = "{{ false && (1 + 2 == 3) }}|{{ true || (2 * 3 == 6) }}|{{ (false && 1 == 2) || true }}",
            .output = "false|true|true",
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-057",
            .template = "{{ (true || false) && (false || true) }}|{{ (false && true) || (true && true) }}",
            .output = "true|true",
            .render_options = render_options,
        },
        .params = .{},
    },

    .{
        .fixture = .{
            .id = "EX-058",
            .template =
            \\{{ 'four' | length }}:{{ 'four' | length() }}:{{ people | length }}:{{ 'left' | join('right') | upper }}:{{ 'x' | configured }}
            \\
            ,
            .output =
            \\4:4:2:LEFTRIGHT:user-data
            \\
            ,
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-059",
            .template =
            \\{{ 'x' | choose }}:{{ choose() }}
            \\
            ,
            .output =
            \\filter:function
            \\
            ,
            .render_options = render_options,
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "EX-060",
            .template =
            \\a{{ null }}b:{{ null | default('fallback') }}
            \\
            ,
            .output =
            \\ab:fallback
            \\
            ,
            .render_options = render_options,
        },
        .params = .{},
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
