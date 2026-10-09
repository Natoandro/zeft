# Zeft

Zeft is an HTML and XML template engine written in Zig. It compiles templates
at runtime into an immutable representation that can be rendered repeatedly
against application data.

## Features

- Structured HTML and XML parsing with context-aware escaping
- Expressions, property and index access, functions, and filters
- Conditionals, loops, lexical bindings, `break`, and `continue`
- Preserve, compact, and pretty whitespace policies
- Thread-safe template caching, explicit reloads, and includes
- Structured compile and render diagnostics with source spans

## Format support

Zeft currently supports structured HTML with paired and void elements, quoted
and boolean attributes, comments, and the HTML5 doctype. XML support includes
fragments, quoted attributes, declarations, comments, CDATA, predefined
entities, and empty-element syntax.

Current HTML limitations include unquoted attribute values, optional end tags,
nonvoid self-closing syntax, doctypes other than the HTML5 form, browser-style
error recovery, and complete raw-text handling for elements such as `script`
and `style`. Dynamic tag and attribute names, trusted raw output, generalized
postfix expressions, a unified callable API, numeric and
optional native context fields, and comptime compilation are also not
implemented yet. See the
[implementation plan](docs/design/implementation-plan.md) for future work.

Blocks use `{#if expression}`, `{:else if expression}`, `{:else}`, and
`{/if}`, or `{#for name in expression}`, optional `{:else}`, and `{/for}`.
Standalone include, break, and continue directives use `{% ... %}`.

See the [architecture](docs/architecture/README.md) for the language and API
contracts.

## Example

~~~zig
pub fn renderExample(allocator: std.mem.Allocator, writer: *std.Io.Writer) !void {
    const result = try zeft.compile(allocator, "<p>Hello, {{ name }}!</p>", .{});
    var template = switch (result) {
        .success => |value| value,
        .failure => return error.TemplateCompileFailed,
    };
    defer template.deinit();

    const rendered = try template.render(writer, .{ .name = "<Ada>" });
    switch (rendered) {
        .success => {},
        .failure => return error.TemplateRenderFailed,
    }
}
~~~

Compilation syntax/markup failures and runtime template failures are returned
as diagnostic results. Writer failures propagate as Zig errors.

Compiled templates own their finalized data and must be deinitialized. See
[the public API](docs/architecture/public-api.md) and
[caching and ownership](docs/architecture/caching-and-ownership.md) for value
semantics, allocator lifetimes, concurrency, callbacks, caching, and includes.

## Requirements

- Zig 0.16.0

## Build and test

```sh
zig build
zig build test
```

`zig build` builds the static library. `zig build test` runs unit and
integration tests. The public Zig module is named `zeft`.

## Use as a dependency

Add the current `main` branch to an application's `build.zig.zon` with
`zig fetch`:

```sh
zig fetch --save-exact=zeft 'git+https://github.com/Natoandro/zeft.git#main'
```

Then import the public module from the application's `build.zig`:

```zig
const zeft_dep = b.dependency("zeft", .{
    .target = target,
    .optimize = optimize,
});
const zeft = zeft_dep.module("zeft");

const app = b.addExecutable(.{
    .name = "my-app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "zeft", .module = zeft }},
    }),
});
```

Application source can then use `const zeft = @import("zeft");`. The module
provides the compiler, compiled template, renderer, and template cache APIs.

## Benchmark

Run the standalone compiler and renderer benchmark with:

```sh
zig build -Doptimize=ReleaseFast bench
```

It reports compile and render timing, allocator activity, writer calls, output
bytes, and finalized template size for small, large, dynamic, and control-flow
workloads. It has no performance thresholds; see
[`docs/design/benchmark-results.md`](docs/design/benchmark-results.md) for
the measurement method and current results.

## Repository layout

- `src/` — public module and implementation.
- `tests/unit.zig` — unit specifications.
- `tests/integration.zig` — end-to-end specifications.
- `tests/fixtures/` — template and expected-output fixtures.
- `tests/fixtures/catalog.md` — suite coverage inventory.
- `docs/architecture/` — normative architecture requirements.
- `docs/design/internals.md` — current non-normative implementation design.
- `docs/design/implementation-plan.md` — sequenced implementation checklist.
