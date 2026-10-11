# Test fixtures

Fixture cases are Zig objects under `tests/fixtures/`. Each suite keeps its
named case arrays beside its fixture data. Successful cases list `.template`
before `.output`, followed by render parameters and options when needed.
Compile and render failures store the template and expected diagnostic. Cases
do not store source paths.

Use Zig multiline strings (`\\...`) for multiline template and output bytes.
Add a final empty multiline line when the fixture needs a trailing newline.
Use escaped Zig strings for control bytes that multiline strings cannot hold.
Keep expected output and diagnostic spans authored from requirements rather
than copying observed renderer output.

See [catalog.md](catalog.md) for stable case IDs, executable owners, and
coverage targets. Preserve case IDs; never reuse an ID removed from the
catalog. Add IDs when requirements or implementation coverage change.

## Catalog status conventions

| Status | Meaning |
| --- | --- |
| `Fixture` | At least one active golden source/output execution covers the row. |
| `Focused` | Active focused tests cover at least part of the row, but it has no dedicated golden case. |
| `Unit` | Internal representation or ownership assertions belong in focused unit tests. |
| `Benchmark` | A standalone benchmark workload exists; it is separate from correctness fixtures. |
| `Planned` | Behavior is specified, but the row has no dedicated executable coverage. |
| `Pending` | Required syntax or API is unresolved. Keep the scenario disabled until it is defined and implemented. |

These statuses identify coverage kind, not completion of every boundary case.
Architecture documents define expected behavior; this catalog tracks coverage
and does not replace those requirements.

## Executable suites

- `markup.zig`: 51 successful output cases and 21 compile failures (MK-001–MK-072).
- `control_flow.zig`: control-flow goldens, render failures, and case parameters.
- `whitespace.zig`: 38 output cases across formats, policies, and contexts.
- `expressions.zig`: 60 successful expression cases (EX-001–EX-060).
- `diagnostics.zig`: 82 compile/render failures (DG-001–DG-082).
- `cache.zig` and `lifecycle.zig`: scenario IDs and their fixture inputs/outputs.

`text.zig` holds shared exact template and output bytes referenced by the case
objects. Multiline values use Zig multiline strings, preserving source offsets,
whitespace, and final-newline differences.

Run `python3 tests/check_fixture_inventory.py` to check imported suite modules,
unique execution IDs, and that no standalone `.tmpl`, `.out`, or `.cases` files
remain. `zig build test` verifies behavior; `zig build test -Doptimize=ReleaseSafe` verifies optimized behavior.

Current inventory: **301 named registrations** and **0 standalone text fixture
files**. There are 179 named successful goldens, 68 compile-error registrations,
37 render-error registrations, and 17 scenario harnesses. A harness may execute
several compile/render operations. The counts describe registrations rather
than Zig test blocks or individual assertions.

The two comptime cases remain pending until the comptime API exists and can be
verified. Numeric and optional native fields remain unsupported by the
adapter; numeric and null expression values are exercised through literals
and callables.
