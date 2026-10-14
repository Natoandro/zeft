//! Exact compile/render diagnostic fixtures (ZEP-080).
const std = @import("std");
const zeft = @import("zeft");
const fixtures = @import("../fixture_runner.zig");

fn fail(_: std.mem.Allocator, _: ?*const anyopaque, _: []const zeft.Value) anyerror!zeft.Value {
    return error.DeliberateFixtureFailure;
}

const registrations = [_]zeft.Registration{.{ .name = "fail", .callback = fail }};

pub const compile_failure_cases = [_]fixtures.CompileFailure{
    .{
        .id = "DG-001",
        .template = "{{ \t\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 7,
                .end = 7,
            },
        },
    },
    .{
        .id = "DG-002",
        .template = "{{ \t'a\\q'\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 7,
                .end = 8,
            },
        },
    },
    .{
        .id = "DG-003",
        .template = "{{ \t'a\nb'\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 6,
                .end = 7,
            },
        },
    },
    .{
        .id = "DG-004",
        .template = "{{ \t'abc\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 8,
                .end = 8,
            },
        },
    },
    .{
        .id = "DG-005",
        .template = "{{ \t1.\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 6,
                .end = 6,
            },
        },
    },
    .{
        .id = "DG-006",
        .template = "{{ \t1e+\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 7,
                .end = 7,
            },
        },
    },
    .{
        .id = "DG-007",
        .template = "{{ \t0x10\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 5,
                .end = 8,
            },
        },
    },
    .{
        .id = "DG-008",
        .template = "{{ \t.5\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 4,
                .end = 5,
            },
        },
    },
    .{
        .id = "DG-009",
        .template = "{{ \tobj.\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 8,
                .end = 8,
            },
        },
    },
    .{
        .id = "DG-010",
        .template = "{{ \titems[]\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 10,
                .end = 11,
            },
        },
    },
    .{
        .id = "DG-011",
        .template = "{{ \titems[1\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 11,
                .end = 11,
            },
        },
    },
    .{
        .id = "DG-012",
        .template = "{{ \titems[1 +]\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 13,
                .end = 14,
            },
        },
    },
    .{
        .id = "DG-013",
        .template = "{{ \t1 +\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 7,
                .end = 7,
            },
        },
    },
    .{
        .id = "DG-014",
        .template = "{{ \t1 ^ 2\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 6,
                .end = 9,
            },
        },
    },
    .{
        .id = "DG-015",
        .template = "{{ \ttrue & false\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 9,
                .end = 16,
            },
        },
    },
    .{
        .id = "DG-016",
        .template = "{{ \t(1 + 2\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 10,
                .end = 10,
            },
        },
    },
    .{
        .id = "DG-017",
        .template = "{{ \tlength(,)\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 11,
                .end = 12,
            },
        },
    },
    .{
        .id = "DG-018",
        .template = "{{ \tlength(1\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 12,
                .end = 12,
            },
        },
    },
    .{
        .id = "DG-019",
        .template = "{{ \tvalue |\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 11,
                .end = 11,
            },
        },
    },
    .{
        .id = "DG-020",
        .template = "{{ \tvalue | upper(,)\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 18,
                .end = 19,
            },
        },
    },
    .{
        .id = "DG-021",
        .template = "\xc3\xa9\xf0\x9f\x99\x82{{ \t1 +\r\n }}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 13,
                .end = 13,
            },
        },
    },
    .{
        .id = "DG-022",
        .template = "\xc3\xa9{{ missing",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 2,
                .end = 12,
            },
        },
    },
    .{
        .id = "DG-023",
        .template = "{#if true",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .syntax,
            .span = .{
                .start = 0,
                .end = 9,
            },
        },
    },
    .{
        .id = "DG-024",
        .template = "<div>",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 5,
            },
        },
    },
    .{
        .id = "DG-025",
        .template = "<div></span>",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 5,
                .end = 12,
            },
        },
    },
    .{
        .id = "DG-026",
        .template = "<p a=x></p>",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 7,
            },
        },
    },
    .{
        .id = "DG-027",
        .template = "<1root/>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 8,
            },
        },
    },
    .{
        .id = "DG-028",
        .template = "<root>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 6,
            },
        },
    },
    .{
        .id = "DG-029",
        .template = "<?xml encoding='UTF-8' version='1.0'?>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 38,
            },
        },
    },
    .{
        .id = "DG-030",
        .template = "<?xml version='1.0' encoding='8UTF'?>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 37,
            },
        },
    },
    .{
        .id = "DG-031",
        .template = "<?xml version='1.0' standalone='maybe'?>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 40,
            },
        },
    },
    .{
        .id = "DG-032",
        .template = "<?xml version='1.0' version='1.0'?>",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 35,
            },
        },
    },
    .{
        .id = "DG-033",
        .template = "\xc3\xa9\xf0\x9f\x99\x82&bad;",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 6,
                .end = 7,
            },
        },
    },
    .{
        .id = "DG-034",
        .template = "<!-- x",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 6,
            },
        },
    },
    .{
        .id = "DG-035",
        .template = "<![CDATA[x",
        .compile_options = .{ .format = .xml },
        .diagnostic = .{
            .kind = .invalid_markup,
            .span = .{
                .start = 0,
                .end = 10,
            },
        },
    },
    .{
        .id = "DG-036",
        .template = "{% mystery %}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .syntax,
            .span = .{
                .start = 0,
                .end = 13,
            },
        },
    },
    .{
        .id = "DG-037",
        .template = "{#if true}a{:else}b{:else}c{/if}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_construct,
            .span = .{
                .start = 19,
                .end = 26,
            },
        },
    },
    .{
        .id = "DG-038",
        .template = "{#if true}x{/for}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_construct,
            .span = .{
                .start = 11,
                .end = 17,
            },
        },
    },
    .{
        .id = "DG-039",
        .template = "{#for x in items}x{/if}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_construct,
            .span = .{
                .start = 18,
                .end = 23,
            },
        },
    },
    .{
        .id = "DG-040",
        .template = "{#if true}x",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_construct,
            .span = .{
                .start = 0,
                .end = 10,
            },
        },
    },
    .{
        .id = "DG-041",
        .template = "{#for x in items}x",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_construct,
            .span = .{
                .start = 0,
                .end = 17,
            },
        },
    },
    .{
        .id = "DG-042",
        .template = "{% break %}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_construct,
            .span = .{
                .start = 0,
                .end = 11,
            },
        },
    },
    .{
        .id = "DG-043",
        .template = "{% continue %}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_construct,
            .span = .{
                .start = 0,
                .end = 14,
            },
        },
    },
    .{
        .id = "DG-044",
        .template = "{:else}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_construct,
            .span = .{
                .start = 0,
                .end = 7,
            },
        },
    },
    .{
        .id = "DG-045",
        .template = "{/if}",
        .compile_options = .{ .format = .html },
        .diagnostic = .{
            .kind = .invalid_construct,
            .span = .{
                .start = 0,
                .end = 5,
            },
        },
    },
    .{
        .id = "DG-070",
        .template = "<p a=\"{{ \t\r\n }}\"></p>",
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 13,
                .end = 13,
            },
        },
    },
    .{
        .id = "DG-071",
        .template = "{{}}",
        .diagnostic = .{
            .kind = .invalid_expression,
            .span = .{
                .start = 2,
                .end = 2,
            },
        },
    },
};

pub const RenderParams = struct {
    value: []const u8 = "text",
    obj: struct { name: []const u8 } = .{ .name = "Ada" },
    items: []const []const u8 = &.{ "a", "b" },
};
pub const RenderCase = struct { fixture: fixtures.RenderFailure, params: RenderParams };

pub const render_failure_cases = [_]RenderCase{
    .{
        .fixture = .{
            .id = "DG-046",
            .template = "{{ absent }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .missing_variable,
                .span = .{
                    .start = 3,
                    .end = 9,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-047",
            .template = "{{ VALUE }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .missing_variable,
                .span = .{
                    .start = 3,
                    .end = 8,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-048",
            .template = "{{ obj.absent }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .invalid_property_access,
                .span = .{
                    .start = 6,
                    .end = 13,
                },
            },
        },
        .params = .{},
    },

    .{
        .fixture = .{
            .id = "DG-049",
            .template = "{{ value.name }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .invalid_property_access,
                .span = .{
                    .start = 8,
                    .end = 13,
                },
            },
        },
        .params = .{},
    },

    .{
        .fixture = .{
            .id = "DG-050",
            .template = "{{ items[9] }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .invalid_property_access,
                .span = .{
                    .start = 8,
                    .end = 11,
                },
            },
        },
        .params = .{},
    },

    .{
        .fixture = .{
            .id = "DG-051",
            .template = "{{ items['x'] }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .invalid_property_access,
                .span = .{
                    .start = 8,
                    .end = 13,
                },
            },
        },
        .params = .{},
    },

    .{
        .fixture = .{
            .id = "DG-052",
            .template = "{{ value[0] }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .invalid_property_access,
                .span = .{
                    .start = 8,
                    .end = 11,
                },
            },
        },
        .params = .{},
    },

    .{
        .fixture = .{
            .id = "DG-053",
            .template = "{{ 'a' - 1 }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .invalid_operand,
                .span = .{
                    .start = 7,
                    .end = 8,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-054",
            .template = "{{ !value }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .invalid_operand,
                .span = .{
                    .start = 3,
                    .end = 4,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-055",
            .template = "{{ -value }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .invalid_operand,
                .span = .{
                    .start = 3,
                    .end = 4,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-056",
            .template = "{{ value && true }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .invalid_operand,
                .span = .{
                    .start = 3,
                    .end = 8,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-057",
            .template = "{{ unknown(value) }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .function_failure,
                .span = .{
                    .start = 3,
                    .end = 17,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-058",
            .template = "{{ LENGTH(value) }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .function_failure,
                .span = .{
                    .start = 3,
                    .end = 16,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-059",
            .template = "{{ length() }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .function_failure,
                .span = .{
                    .start = 3,
                    .end = 11,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-060",
            .template = "{{ length(1) }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .function_failure,
                .span = .{
                    .start = 3,
                    .end = 12,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-061",
            .template = "{{ fail(value) }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .function_failure,
                .span = .{
                    .start = 3,
                    .end = 14,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-062",
            .template = "{{ value | unknown }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .filter_failure,
                .span = .{
                    .start = 11,
                    .end = 18,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-063",
            .template = "{{ value | UPPER }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .filter_failure,
                .span = .{
                    .start = 11,
                    .end = 16,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-064",
            .template = "{{ value | upper('x') }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .filter_failure,
                .span = .{
                    .start = 11,
                    .end = 21,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-065",
            .template = "{{ 1 | upper }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .filter_failure,
                .span = .{
                    .start = 7,
                    .end = 12,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-066",
            .template = "{{ value | fail }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .filter_failure,
                .span = .{
                    .start = 11,
                    .end = 15,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-067",
            .template = "\xc3\xa9\xf0\x9f\x99\x82{{ \t absent \r\n }}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .missing_variable,
                .span = .{
                    .start = 11,
                    .end = 17,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-068",
            .template = "{#if value}yes{/if}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .invalid_operand,
                .span = .{
                    .start = 5,
                    .end = 10,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-069",
            .template = "{#for x in value}x{/for}",
            .render_options = .{
                .allocator = std.testing.allocator,
                .functions = &registrations,
                .filters = &registrations,
            },
            .diagnostic = .{
                .kind = .non_iterable,
                .span = .{
                    .start = 11,
                    .end = 16,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-72",
            .template = "{{ items[-1] }}",
            .diagnostic = .{
                .kind = .invalid_property_access,
                .span = .{
                    .start = 8,
                    .end = 12,
                },
            },
        },
        .params = .{},
    },

    .{
        .fixture = .{
            .id = "DG-73",
            .template = "{{ items[1.5] }}",
            .diagnostic = .{
                .kind = .invalid_property_access,
                .span = .{
                    .start = 8,
                    .end = 13,
                },
            },
        },
        .params = .{},
    },

    .{
        .fixture = .{
            .id = "DG-74",
            .template = "{{ items[1e300] }}",
            .diagnostic = .{
                .kind = .invalid_property_access,
                .span = .{
                    .start = 8,
                    .end = 15,
                },
            },
        },
        .params = .{},
    },

    .{
        .fixture = .{
            .id = "DG-075",
            .template =
            \\{{ items }}
            \\
            ,
            .diagnostic = .{
                .kind = .invalid_operand,
                .span = .{
                    .start = 0,
                    .end = 11,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-076",
            .template =
            \\{{ obj }}
            \\
            ,
            .diagnostic = .{
                .kind = .invalid_operand,
                .span = .{
                    .start = 0,
                    .end = 9,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-077",
            .template =
            \\{{ 1 == '1' }}
            \\
            ,
            .diagnostic = .{
                .kind = .invalid_operand,
                .span = .{
                    .start = 5,
                    .end = 7,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-078",
            .template =
            \\{{ 1 != '1' }}
            \\
            ,
            .diagnostic = .{
                .kind = .invalid_operand,
                .span = .{
                    .start = 5,
                    .end = 7,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-081",
            .template =
            \\{{ 5 / 0 }}
            \\
            ,
            .diagnostic = .{
                .kind = .invalid_operand,
                .span = .{
                    .start = 5,
                    .end = 6,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "DG-082",
            .template =
            \\{{ 5 % -0 }}
            \\
            ,
            .diagnostic = .{
                .kind = .invalid_operand,
                .span = .{
                    .start = 5,
                    .end = 6,
                },
            },
        },
        .params = .{},
    },
};
