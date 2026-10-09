# Test fixtures

Fixtures are golden inputs for end-to-end compilation and rendering. Keep
template source (`.tmpl`) and exact expected output (`.out`) separate from test
runner code. An active golden fixture is embedded by an executable integration
case and compares the complete output byte-for-byte.

See [catalog.md](catalog.md) for the coverage inventory, stable case IDs,
executable owners, and remaining scenarios. Architecture documents define
expected behavior; the catalog tracks coverage and does not replace those
requirements.

## Catalog status conventions

| Status | Meaning |
| --- | --- |
| `Fixture` | At least one active golden source/output execution covers the row. The audit lists remaining boundaries. |
| `Focused` | Active focused tests cover at least part of the row, but it has no dedicated golden coverage. This may include parser tests rather than public compile/render tests. |
| `Unit` | Internal representation or ownership assertions belong in focused unit tests. |
| `Benchmark` | A standalone benchmark workload exists; it is separate from correctness fixtures. |
| `Planned` | Behavior is specified, but the row has no dedicated executable coverage. This does not imply the feature is unimplemented. |
| `Pending` | Required syntax or API is unresolved. Keep the scenario disabled until it is defined and implemented. |

These statuses identify coverage kind, not complete verification of every
scenario in a row. Mark new cases active only after their behavior is
implemented and verified. Preserve case IDs; never reuse an ID removed from
the catalog. Add IDs when requirements or implementation coverage change.

## Active golden layout

Paths below are fixture basenames, not directories. Each source is paired
with exact expected output; option variants share source and have distinct
output files.

| Source basename | Output basename(s) | Coverage |
| --- | --- | --- |
| `html/static` | `html/static` | Nested markup, exact static attributes, void elements, doctype, comments, and text delimiter escapes |
| `html/dynamic` | `html/dynamic` | Text and quoted-attribute interpolation with HTML escaping |
| `html/expressions` | `html/expressions` | Property and index access, operators, short-circuiting, and built-in filters/functions |
| `html/control-flow` | `html/control-flow` | Conditional branches, loop bindings, root-name restoration, and lexical scope |
| `xml/fragment` | `xml/fragment` | XML declaration, empty elements, CDATA, entity preservation, and XML escaping |
| `html/whitespace` | `html/whitespace-{preserve,compact,pretty}` | HTML policies, inline boundaries, and whitespace-sensitive elements |
| `xml/whitespace` | `xml/whitespace-{preserve,compact,pretty}` | XML policies, element-only formatting, and mixed content |
| `html/whitespace-dynamic` | `html/whitespace-dynamic-{preserve,compact,pretty}` | Dynamic and loop output boundaries across policies |

The initial inventory has eight source files and fourteen source/output
executions. Fourteen executions do not mean fourteen catalog requirements;
one execution may cover multiple IDs, and one ID may require multiple cases.

Context values and callable registrations are supplied by Zig tests because
fixtures contain only template input and expected bytes. Compile and render
diagnostics compare categories and exact half-open byte spans in named test
cases. Lifecycle, writer-error, concurrency, and internal IR assertions need
focused Zig harnesses rather than output files alone.

Expected bytes and diagnostic spans must be authored from requirements and
reviewed independently of observed renderer output. Preserve final-newline
and whitespace differences in `.out` files. Pending comptime cases have no
invented API or executable fixtures.
