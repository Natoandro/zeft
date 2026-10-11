const runner = @import("../fixture_runner.zig");
pub const Context = struct {
    name: []const u8 = "Ada",
    show: bool = true,
    items: []const []const u8 = &.{},
};
pub const Case = struct { fixture: runner.Success, params: Context };
pub const success_cases = [_]Case{
    .{
        .fixture = .{
            .id = "W/structural-html-preserve",
            .template = (
                \\
                \\<root>
                \\
            ) ++ "\t" ++ (
                \\<a>A</a>
                \\ <b>B</b>
                \\</root>
                \\
            ),
            .output = (
                \\
                \\<root>
                \\
            ) ++ "\t" ++ (
                \\<a>A</a>
                \\ <b>B</b>
                \\</root>
                \\
            ),
            .compile_options = .{
                .format = .html,
                .whitespace = .preserve,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/structural-html-compact",
            .template = (
                \\
                \\<root>
                \\
            ) ++ "\t" ++ (
                \\<a>A</a>
                \\ <b>B</b>
                \\</root>
                \\
            ),
            .output = "<root><a>A</a><b>B</b></root>",
            .compile_options = .{
                .format = .html,
                .whitespace = .compact,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/structural-html-pretty",
            .template = (
                \\
                \\<root>
                \\
            ) ++ "\t" ++ (
                \\<a>A</a>
                \\ <b>B</b>
                \\</root>
                \\
            ),
            .output =
            \\<root>
            \\  <a>A</a>
            \\  <b>B</b>
            \\</root>
            \\
            ,
            .compile_options = .{
                .format = .html,
                .whitespace = .pretty,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/structural-xml-preserve",
            .template = (
                \\
                \\<root>
                \\
            ) ++ "\t" ++ (
                \\<a>A</a>
                \\ <b>B</b>
                \\</root>
                \\
            ),
            .output = (
                \\
                \\<root>
                \\
            ) ++ "\t" ++ (
                \\<a>A</a>
                \\ <b>B</b>
                \\</root>
                \\
            ),
            .compile_options = .{
                .format = .xml,
                .whitespace = .preserve,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/structural-xml-compact",
            .template = (
                \\
                \\<root>
                \\
            ) ++ "\t" ++ (
                \\<a>A</a>
                \\ <b>B</b>
                \\</root>
                \\
            ),
            .output = "<root><a>A</a><b>B</b></root>",
            .compile_options = .{
                .format = .xml,
                .whitespace = .compact,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/structural-xml-pretty",
            .template = (
                \\
                \\<root>
                \\
            ) ++ "\t" ++ (
                \\<a>A</a>
                \\ <b>B</b>
                \\</root>
                \\
            ),
            .output =
            \\<root>
            \\  <a>A</a>
            \\  <b>B</b>
            \\</root>
            \\
            ,
            .compile_options = .{
                .format = .xml,
                .whitespace = .pretty,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/mixed-html-preserve",
            .template = "<p> " ++ "\t" ++ (
                \\Hello {{ name }} <b> bold </b> world 
                \\</p>
            ),
            .output = "<p> " ++ "\t" ++ (
                \\Hello Ada <b> bold </b> world 
                \\</p>
            ),
            .compile_options = .{
                .format = .html,
                .whitespace = .preserve,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/mixed-html-compact",
            .template = "<p> " ++ "\t" ++ (
                \\Hello {{ name }} <b> bold </b> world 
                \\</p>
            ),
            .output = "<p> Hello Ada <b> bold </b> world </p>",
            .compile_options = .{
                .format = .html,
                .whitespace = .compact,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/mixed-html-pretty",
            .template = "<p> " ++ "\t" ++ (
                \\Hello {{ name }} <b> bold </b> world 
                \\</p>
            ),
            .output = "<p> " ++ "\t" ++ (
                \\Hello Ada <b> bold </b> world 
                \\</p>
                \\
            ),
            .compile_options = .{
                .format = .html,
                .whitespace = .pretty,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/mixed-xml-preserve",
            .template = "<p> " ++ "\t" ++ (
                \\Hello {{ name }} <b> bold </b> world 
                \\</p>
            ),
            .output = "<p> " ++ "\t" ++ (
                \\Hello Ada <b> bold </b> world 
                \\</p>
            ),
            .compile_options = .{
                .format = .xml,
                .whitespace = .preserve,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/mixed-xml-compact",
            .template = "<p> " ++ "\t" ++ (
                \\Hello {{ name }} <b> bold </b> world 
                \\</p>
            ),
            .output = "<p> Hello Ada <b> bold </b> world </p>",
            .compile_options = .{
                .format = .xml,
                .whitespace = .compact,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/mixed-xml-pretty",
            .template = "<p> " ++ "\t" ++ (
                \\Hello {{ name }} <b> bold </b> world 
                \\</p>
            ),
            .output = "<p> " ++ "\t" ++ (
                \\Hello Ada <b> bold </b> world 
                \\</p>
                \\
            ),
            .compile_options = .{
                .format = .xml,
                .whitespace = .pretty,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/generated-html-preserve",
            .template = "<root>{#if show}<a>A</a>{:else}<b>B</b>{/if}{#for item in items}<c>{{ item }}</c>{/for}</root>",
            .output = "<root><a>A</a><c>X</c><c>Y</c></root>",
            .compile_options = .{
                .format = .html,
                .whitespace = .preserve,
            },
        },
        .params = .{ .items = &.{
            "X",
            "Y",
        } },
    },
    .{
        .fixture = .{
            .id = "W/generated-html-compact",
            .template = "<root>{#if show}<a>A</a>{:else}<b>B</b>{/if}{#for item in items}<c>{{ item }}</c>{/for}</root>",
            .output = "<root><a>A</a><c>X</c><c>Y</c></root>",
            .compile_options = .{
                .format = .html,
                .whitespace = .compact,
            },
        },
        .params = .{ .items = &.{
            "X",
            "Y",
        } },
    },
    .{
        .fixture = .{
            .id = "W/generated-html-pretty",
            .template = "<root>{#if show}<a>A</a>{:else}<b>B</b>{/if}{#for item in items}<c>{{ item }}</c>{/for}</root>",
            .output =
            \\<root>
            \\  <a>A</a>
            \\  <c>X</c>
            \\  <c>Y</c>
            \\</root>
            \\
            ,
            .compile_options = .{
                .format = .html,
                .whitespace = .pretty,
            },
        },
        .params = .{ .items = &.{
            "X",
            "Y",
        } },
    },
    .{
        .fixture = .{
            .id = "W/generated-xml-preserve",
            .template = "<root>{#if show}<a>A</a>{:else}<b>B</b>{/if}{#for item in items}<c>{{ item }}</c>{/for}</root>",
            .output = "<root><a>A</a><c>X</c><c>Y</c></root>",
            .compile_options = .{
                .format = .xml,
                .whitespace = .preserve,
            },
        },
        .params = .{ .items = &.{
            "X",
            "Y",
        } },
    },
    .{
        .fixture = .{
            .id = "W/generated-xml-compact",
            .template = "<root>{#if show}<a>A</a>{:else}<b>B</b>{/if}{#for item in items}<c>{{ item }}</c>{/for}</root>",
            .output = "<root><a>A</a><c>X</c><c>Y</c></root>",
            .compile_options = .{
                .format = .xml,
                .whitespace = .compact,
            },
        },
        .params = .{ .items = &.{
            "X",
            "Y",
        } },
    },
    .{
        .fixture = .{
            .id = "W/generated-xml-pretty",
            .template = "<root>{#if show}<a>A</a>{:else}<b>B</b>{/if}{#for item in items}<c>{{ item }}</c>{/for}</root>",
            .output =
            \\<root>
            \\  <a>A</a>
            \\  <c>X</c>
            \\  <c>Y</c>
            \\</root>
            \\
            ,
            .compile_options = .{
                .format = .xml,
                .whitespace = .pretty,
            },
        },
        .params = .{ .items = &.{
            "X",
            "Y",
        } },
    },
    .{
        .fixture = .{
            .id = "W/sensitive-names-html-preserve",
            .template = "<root><pre> a" ++ "\t" ++ (
                \\ 
                \\b </pre><textarea> c
            ) ++ "\t" ++ (
                \\ 
                \\d </textarea><script> e
            ) ++ "\t" ++ (
                \\ 
                \\f </script><style> g
            ) ++ "\t" ++ (
                \\ 
                \\h </style></root>
            ),
            .output = "<root><pre> a" ++ "\t" ++ (
                \\ 
                \\b </pre><textarea> c
            ) ++ "\t" ++ (
                \\ 
                \\d </textarea><script> e
            ) ++ "\t" ++ (
                \\ 
                \\f </script><style> g
            ) ++ "\t" ++ (
                \\ 
                \\h </style></root>
            ),
            .compile_options = .{
                .format = .html,
                .whitespace = .preserve,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/sensitive-names-html-compact",
            .template = "<root><pre> a" ++ "\t" ++ (
                \\ 
                \\b </pre><textarea> c
            ) ++ "\t" ++ (
                \\ 
                \\d </textarea><script> e
            ) ++ "\t" ++ (
                \\ 
                \\f </script><style> g
            ) ++ "\t" ++ (
                \\ 
                \\h </style></root>
            ),
            .output = "<root><pre> a" ++ "\t" ++ (
                \\ 
                \\b </pre><textarea> c
            ) ++ "\t" ++ (
                \\ 
                \\d </textarea><script> e
            ) ++ "\t" ++ (
                \\ 
                \\f </script><style> g
            ) ++ "\t" ++ (
                \\ 
                \\h </style></root>
            ),
            .compile_options = .{
                .format = .html,
                .whitespace = .compact,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/sensitive-names-html-pretty",
            .template = "<root><pre> a" ++ "\t" ++ (
                \\ 
                \\b </pre><textarea> c
            ) ++ "\t" ++ (
                \\ 
                \\d </textarea><script> e
            ) ++ "\t" ++ (
                \\ 
                \\f </script><style> g
            ) ++ "\t" ++ (
                \\ 
                \\h </style></root>
            ),
            .output = (
                \\<root>
                \\  <pre> a
            ) ++ "\t" ++ (
                \\ 
                \\b </pre>
                \\  <textarea> c
            ) ++ "\t" ++ (
                \\ 
                \\d </textarea>
                \\  <script> e
            ) ++ "\t" ++ (
                \\ 
                \\f </script>
                \\  <style> g
            ) ++ "\t" ++ (
                \\ 
                \\h </style>
                \\</root>
                \\
            ),
            .compile_options = .{
                .format = .html,
                .whitespace = .pretty,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/sensitive-names-xml-preserve",
            .template = "<root><pre> a" ++ "\t" ++ (
                \\ 
                \\b </pre><textarea> c
            ) ++ "\t" ++ (
                \\ 
                \\d </textarea><script> e
            ) ++ "\t" ++ (
                \\ 
                \\f </script><style> g
            ) ++ "\t" ++ (
                \\ 
                \\h </style></root>
            ),
            .output = "<root><pre> a" ++ "\t" ++ (
                \\ 
                \\b </pre><textarea> c
            ) ++ "\t" ++ (
                \\ 
                \\d </textarea><script> e
            ) ++ "\t" ++ (
                \\ 
                \\f </script><style> g
            ) ++ "\t" ++ (
                \\ 
                \\h </style></root>
            ),
            .compile_options = .{
                .format = .xml,
                .whitespace = .preserve,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/sensitive-names-xml-compact",
            .template = "<root><pre> a" ++ "\t" ++ (
                \\ 
                \\b </pre><textarea> c
            ) ++ "\t" ++ (
                \\ 
                \\d </textarea><script> e
            ) ++ "\t" ++ (
                \\ 
                \\f </script><style> g
            ) ++ "\t" ++ (
                \\ 
                \\h </style></root>
            ),
            .output = "<root><pre> a b </pre><textarea> c d </textarea><script> e f </script><style> g h </style></root>",
            .compile_options = .{
                .format = .xml,
                .whitespace = .compact,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/sensitive-names-xml-pretty",
            .template = "<root><pre> a" ++ "\t" ++ (
                \\ 
                \\b </pre><textarea> c
            ) ++ "\t" ++ (
                \\ 
                \\d </textarea><script> e
            ) ++ "\t" ++ (
                \\ 
                \\f </script><style> g
            ) ++ "\t" ++ (
                \\ 
                \\h </style></root>
            ),
            .output = (
                \\<root>
                \\  <pre> a
            ) ++ "\t" ++ (
                \\ 
                \\b </pre>
                \\  <textarea> c
            ) ++ "\t" ++ (
                \\ 
                \\d </textarea>
                \\  <script> e
            ) ++ "\t" ++ (
                \\ 
                \\f </script>
                \\  <style> g
            ) ++ "\t" ++ (
                \\ 
                \\h </style>
                \\</root>
                \\
            ),
            .compile_options = .{
                .format = .xml,
                .whitespace = .pretty,
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/custom-indent-html-pretty",
            .template = "<root><a>A</a><b>B</b></root>",
            .output = (
                \\<root>
                \\
            ) ++ "\t" ++ (
                \\<a>A</a>
                \\
            ) ++ "\t" ++ (
                \\<b>B</b>
                \\</root>
                \\
            ),
            .compile_options = .{
                .format = .html,
                .whitespace = .pretty,
                .indentation = "\t",
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/custom-indent-xml-pretty",
            .template = "<root><a>A</a><b>B</b></root>",
            .output = (
                \\<root>
                \\
            ) ++ "\t" ++ (
                \\<a>A</a>
                \\
            ) ++ "\t" ++ (
                \\<b>B</b>
                \\</root>
                \\
            ),
            .compile_options = .{
                .format = .xml,
                .whitespace = .pretty,
                .indentation = "\t",
            },
        },
        .params = .{},
    },
    .{
        .fixture = .{
            .id = "W/empty-dynamic-html-preserve",
            .template = "<p>left {{ name }} right</p>",
            .output = "<p>left  right</p>",
            .compile_options = .{
                .format = .html,
                .whitespace = .preserve,
            },
        },
        .params = .{ .name = "" },
    },
    .{
        .fixture = .{
            .id = "W/empty-dynamic-html-compact",
            .template = "<p>left {{ name }} right</p>",
            .output = "<p>left  right</p>",
            .compile_options = .{
                .format = .html,
                .whitespace = .compact,
            },
        },
        .params = .{ .name = "" },
    },
    .{
        .fixture = .{
            .id = "W/empty-dynamic-html-pretty",
            .template = "<p>left {{ name }} right</p>",
            .output =
            \\<p>left  right</p>
            \\
            ,
            .compile_options = .{
                .format = .html,
                .whitespace = .pretty,
            },
        },
        .params = .{ .name = "" },
    },
    .{
        .fixture = .{
            .id = "W/empty-dynamic-xml-preserve",
            .template = "<p>left {{ name }} right</p>",
            .output = "<p>left  right</p>",
            .compile_options = .{
                .format = .xml,
                .whitespace = .preserve,
            },
        },
        .params = .{ .name = "" },
    },
    .{
        .fixture = .{
            .id = "W/empty-dynamic-xml-compact",
            .template = "<p>left {{ name }} right</p>",
            .output = "<p>left  right</p>",
            .compile_options = .{
                .format = .xml,
                .whitespace = .compact,
            },
        },
        .params = .{ .name = "" },
    },
    .{
        .fixture = .{
            .id = "W/empty-dynamic-xml-pretty",
            .template = "<p>left {{ name }} right</p>",
            .output =
            \\<p>left  right</p>
            \\
            ,
            .compile_options = .{
                .format = .xml,
                .whitespace = .pretty,
            },
        },
        .params = .{ .name = "" },
    },
    .{
        .fixture = .{
            .id = "W/generated-empty-html-preserve",
            .template = "<root>{#if show}<a>A</a>{:else}<b>B</b>{/if}{#for item in items}<c>{{ item }}</c>{/for}</root>",
            .output = "<root><b>B</b></root>",
            .compile_options = .{
                .format = .html,
                .whitespace = .preserve,
            },
        },
        .params = .{ .show = false },
    },
    .{
        .fixture = .{
            .id = "W/generated-empty-html-compact",
            .template = "<root>{#if show}<a>A</a>{:else}<b>B</b>{/if}{#for item in items}<c>{{ item }}</c>{/for}</root>",
            .output = "<root><b>B</b></root>",
            .compile_options = .{
                .format = .html,
                .whitespace = .compact,
            },
        },
        .params = .{ .show = false },
    },
    .{
        .fixture = .{
            .id = "W/generated-empty-html-pretty",
            .template = "<root>{#if show}<a>A</a>{:else}<b>B</b>{/if}{#for item in items}<c>{{ item }}</c>{/for}</root>",
            .output =
            \\<root>
            \\  <b>B</b>
            \\</root>
            \\
            ,
            .compile_options = .{
                .format = .html,
                .whitespace = .pretty,
            },
        },
        .params = .{ .show = false },
    },
    .{
        .fixture = .{
            .id = "W/generated-empty-xml-preserve",
            .template = "<root>{#if show}<a>A</a>{:else}<b>B</b>{/if}{#for item in items}<c>{{ item }}</c>{/for}</root>",
            .output = "<root><b>B</b></root>",
            .compile_options = .{
                .format = .xml,
                .whitespace = .preserve,
            },
        },
        .params = .{ .show = false },
    },
    .{
        .fixture = .{
            .id = "W/generated-empty-xml-compact",
            .template = "<root>{#if show}<a>A</a>{:else}<b>B</b>{/if}{#for item in items}<c>{{ item }}</c>{/for}</root>",
            .output = "<root><b>B</b></root>",
            .compile_options = .{
                .format = .xml,
                .whitespace = .compact,
            },
        },
        .params = .{ .show = false },
    },
    .{
        .fixture = .{
            .id = "W/generated-empty-xml-pretty",
            .template = "<root>{#if show}<a>A</a>{:else}<b>B</b>{/if}{#for item in items}<c>{{ item }}</c>{/for}</root>",
            .output =
            \\<root>
            \\  <b>B</b>
            \\</root>
            \\
            ,
            .compile_options = .{
                .format = .xml,
                .whitespace = .pretty,
            },
        },
        .params = .{ .show = false },
    },
};
