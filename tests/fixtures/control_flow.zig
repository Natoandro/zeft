const std = @import("std");
const zeft = @import("zeft");
const runner = @import("../fixture_runner.zig");
const Item = struct { name: []const u8, enabled: bool };
const Group = struct { name: []const u8, items: []const Item };
pub const Context = struct {
    show: bool = true,
    inner: bool = true,
    item: []const u8 = "root",
    items: []const Item = &.{},
    groups: []const Group = &.{},
};
const items = [_]Item{
    .{
        .name = "A",
        .enabled = true,
    },
    .{
        .name = "B",
        .enabled = false,
    },
    .{
        .name = "C",
        .enabled = true,
    },
};
const groups = [_]Group{ .{ .name = "outer1", .items = &items }, .{ .name = "outer2", .items = &.{} } };
pub const Case = struct { fixture: runner.Success, params: Context };

pub const success_cases = [_]Case{
    .{
        .fixture = .{
            .id = "F/branch-tt",
            .template = "before:{#if show}{#if inner}TT{:else}TF{/if}{:else}{#if inner}FT{:else}FF{/if}{/if}:after",
            .output = "before:TT:after",
        },
        .params = .{
            .show = true,
            .inner = true,
        },
    },
    .{
        .fixture = .{
            .id = "F/branch-tf",
            .template = "before:{#if show}{#if inner}TT{:else}TF{/if}{:else}{#if inner}FT{:else}FF{/if}{/if}:after",
            .output = "before:TF:after",
        },
        .params = .{
            .show = true,
            .inner = false,
        },
    },
    .{
        .fixture = .{
            .id = "F/branch-ft",
            .template = "before:{#if show}{#if inner}TT{:else}TF{/if}{:else}{#if inner}FT{:else}FF{/if}{/if}:after",
            .output = "before:FT:after",
        },
        .params = .{
            .show = false,
            .inner = true,
        },
    },
    .{
        .fixture = .{
            .id = "F/branch-ff",
            .template = "before:{#if show}{#if inner}TT{:else}TF{/if}{:else}{#if inner}FT{:else}FF{/if}{/if}:after",
            .output = "before:FF:after",
        },
        .params = .{
            .show = false,
            .inner = false,
        },
    },
    .{
        .fixture = .{
            .id = "F/loop-empty",
            .template = "{{ item }}:{#for item in items}[{{ item.name }}]{/for}:{{ item }}",
            .output = "root::root",
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "F/loop-single",
            .template = "{{ item }}:{#for item in items}[{{ item.name }}]{/for}:{{ item }}",
            .output = "root:[A]:root",
        },
        .params = .{ .items = items[0..1] },
    },

    .{
        .fixture = .{
            .id = "F/loop-multiple",
            .template = "{{ item }}:{#for item in items}[{{ item.name }}]{/for}:{{ item }}",
            .output = "root:[A][B][C]:root",
        },
        .params = .{ .items = &items },
    },

    .{
        .fixture = .{
            .id = "F/nested-shadow",
            .template = "{{ item }}:{#for item in groups}{{ item.name }}({#for item in item.items}{{ item.name }}{/for}){{ item.name }};{/for}:{{ item }}",
            .output = "root:outer1(ABC)outer1;outer2()outer2;:root",
        },
        .params = .{ .groups = &groups },
    },

    .{
        .fixture = .{
            .id = "F/nested-independent",
            .template = "{#for group in groups}[{#for item in group.items}{{ group.name }}={{ item.name }};{/for}]{/for}",
            .output = "[outer1=A;outer1=B;outer1=C;][]",
        },
        .params = .{ .groups = &groups },
    },

    .{
        .fixture = .{
            .id = "F/continue-in-branch",
            .template = "{#for item in items}{#if !item.enabled}{% continue %}{/if}{{ item.name }}{/for}:{{ item }}",
            .output = "AC:root",
        },
        .params = .{ .items = &items },
    },

    .{
        .fixture = .{
            .id = "F/break-in-branch",
            .template = "{#for item in items}{#if !item.enabled}{% break %}{/if}{{ item.name }}{/for}:{{ item }}",
            .output = "A:root",
        },
        .params = .{ .items = &items },
    },

    .{
        .fixture = .{
            .id = "F/nested-break",
            .template = "{#for item in groups}{{ item.name }}:{#for item in item.items}{{ item.name }}{% break %}{/for}:{{ item.name }};{/for}",
            .output = "outer1:A:outer1;outer2::outer2;",
        },
        .params = .{ .groups = &groups },
    },

    .{
        .fixture = .{
            .id = "F/nested-continue",
            .template = "{#for group in groups}{{ group.name }}:{#for item in group.items}{#if !item.enabled}{% continue %}{/if}{{ item.name }}{/for};{/for}",
            .output = "outer1:AC;outer2:;",
        },
        .params = .{ .groups = &groups },
    },

    .{
        .fixture = .{
            .id = "F/branch-loop-skips-error",
            .template = "{#if show}{#for item in items}{{ item.name }}{/for}{:else}{{ absent }}{/if}",
            .output = "ABC",
        },
        .params = .{ .items = &items },
    },

    .{
        .fixture = .{
            .id = "F/empty-loop-skips-error",
            .template = "{#for item in items}{{ absent }}{/for}done",
            .output = "done",
        },
        .params = .{},
    },

    .{
        .fixture = .{
            .id = "F/local-index",
            .template = "{#for group in groups}{#if length(group.items) > 0}{{ group.items[1].name }}{/if}{/for}",
            .output = "B",
        },
        .params = .{ .groups = &groups },
    },
};
pub const FailureParams = struct {
    show: []const u8 = "wrong",
    items: bool = true,
};
pub const FailureCase = struct { fixture: runner.RenderFailure, params: FailureParams };

pub const failure_cases = [_]FailureCase{
    .{
        .fixture = .{
            .id = "F/condition-type",
            .template = "{#if show}yes{/if}",
            .diagnostic = .{
                .kind = .invalid_operand,
                .span = .{
                    .start = 5,
                    .end = 9,
                },
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "F/iterable-type",
            .template = "{#for item in items}{{ item }}{/for}",
            .diagnostic = .{
                .kind = .non_iterable,
                .span = .{
                    .start = 14,
                    .end = 19,
                },
            },
        },
        .params = .{},
    },
};
pub const harness_ids = [_][]const u8{"F/reuse-failure-recovery"};
