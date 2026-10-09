# Zeft

Zeft is a runtime-first template compiler and renderer written in Zig. It is
designed to compile template source into an immutable `CompiledTemplate`, then
render that compiled representation against application data. See the
[normative architecture](docs/architecture/README.md) for the required design
and the [implementation plan](docs/design/implementation-plan.md) for its
phased delivery.

## Project status

The project currently compiles and renders a small HTML/XML template language:
static text, nested elements, HTML boolean and quoted attributes, XML quoted
attributes, comments, the HTML doctype, XML declarations, CDATA, and
format-specific empty-element rules. Text-position and attribute-value
interpolations support root identifiers, nested struct properties, and
non-negative literal indexes into arrays and slices. Expression operators are
specified in the architecture and remain planned. Dynamic text and attribute
values use format- and context-specific escaping; attribute values escape both
quote characters. Contexts are generic Zig structs with byte-string leaves;
pass aggregate contexts by pointer. Compile options default to HTML with
source whitespace preserved; compact and pretty modes are also available.
Pretty mode uses two spaces by default and accepts a custom indentation string
through `CompileOptions.indentation`.
See the implementation plan for the current supported subset and remaining
work.

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

The allocator passed to `compile` must remain valid until the compiled
template's `deinit`; the template owns its finalized data and does not retain
the source buffer or compile options' indentation slice. Call `deinit` exactly
once after all renders have finished. Each render owns its control-flow state
and scratch arena. The renderer releases render-local allocations through
`RenderOptions.allocator` when rendering ends, subject to that allocator's
semantics. Strings returned by registered callbacks must remain valid through
the end of that render and must be allocated from the supplied allocator when
newly created. The default allocator is thread-safe; if concurrent renders
share a custom allocator, that allocator must support concurrent use.

An immutable compiled template can be rendered concurrently as long as it is
not deinitialized during a render. Each call must have its own writer and
should use immutable context and callback data, or synchronize any shared
mutable data itself.

`TemplateCache` is an explicit, thread-safe cache. The caller supplies the
identity bytes, source bytes, and compile options; Zeft does not read files.
Submit updated source with `getOrCompile` to reload. A compile failure leaves
the last valid entry available. A returned `TemplateLease` must be deinitialized
exactly once and before its cache. Lease rendering pins that root version.

Includes use `{% include "path" %}`. The bytes inside the quotes are the exact
child identity. Populate children independently with `getOrCompile`; cache
rendering resolves the current child on each include. Missing children,
initial child compile failures, and cycles return runtime diagnostics with the
child identity and parent include span. Replaced or evicted templates remain
alive while a lease or render uses them. Include identity strings in returned
diagnostics remain valid until the cache is deinitialized.

~~~zig
var cache = zeft.TemplateCache.init(allocator);
defer cache.deinit();
var page = switch (try cache.getOrCompile("page", source, .{})) {
    .success => |lease| lease,
    .failure => return error.TemplateCompileFailed,
};
defer page.deinit();
const rendered = try page.render(&writer, .{ .name = "Ada" });
~~~

## Requirements

- Zig 0.16.0

## Build and test

```sh
zig build
zig build test
```

`zig build` builds the static library. `zig build test` runs unit and
integration tests. The public Zig module is named `zeft`.

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
- `docs/architecture/` — normative architecture requirements.
- `docs/design/implementation-plan.md` — sequenced implementation checklist.
