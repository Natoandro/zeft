# Zeft

Zeft is a runtime-first template compiler and renderer written in Zig. It is
designed to compile template source into an immutable `CompiledTemplate`, then
render that compiled representation against application data. See the
[normative architecture](docs/architecture/README.md) for the required design
and the [implementation plan](docs/design/implementation-plan.md) for its
phased delivery.

## Project status

The project currently has its package foundation and public API scaffold in
place. The parser and renderer are not implemented yet: `compile()` currently
returns an `unsupported_syntax` diagnostic for every source. The first
implementation milestone is a complete vertical slice that parses and renders
a small HTML template with an escaped context value.

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
