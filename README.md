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

## Requirements

- Zig 0.16.0

## Build and test

```sh
zig build
zig build test
```

`zig build` builds the static library. `zig build test` runs unit and
integration tests. The public Zig module is named `zeft`.

## Repository layout

- `src/` — public module and implementation.
- `tests/unit.zig` — unit specifications.
- `tests/integration.zig` — end-to-end specifications.
- `tests/fixtures/` — template and expected-output fixtures.
- `docs/architecture/` — normative architecture requirements.
- `docs/design/implementation-plan.md` — sequenced implementation checklist.
