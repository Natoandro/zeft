# Contributing

## Repository map

- `src/` contains the public module and implementation.
- `tests/unit.zig` contains unit specifications.
- `tests/integration.zig` contains end-to-end specifications.
- `tests/fixtures/` contains reusable template and expected-output fixtures.
- `tests/fixtures/catalog.md` tracks suite coverage; its
  [README](tests/fixtures/README.md) describes fixture layout and status.
- `docs/architecture/` contains normative architecture requirements.
- `docs/design/internals.md` describes the current implementation.
- `docs/design/implementation-plan.md` tracks implementation sequencing and
  progress.

## Making changes

Treat `docs/architecture/` as the source of required behavior and system
boundaries. Keep `docs/design/internals.md` aligned with material changes to
the implementation, and update the implementation plan when its tasks change
or are completed. Do not introduce product or architecture behavior that the
requirements have not settled.

Keep unit tests, integration tests, and reusable fixtures in their respective
`tests/` locations. Preserve fixture case IDs, add catalog entries when
coverage changes, and enable cases only after their behavior is implemented
and verified.

## Build and verify

The project supports Zig 0.16.0. For implementation changes, format changed
Zig files and run the build and test suite:

```sh
zig fmt path/to/changed.zig
zig build
zig build test
```

Keep Zig source lines at or below 100 characters. To check staged Zig files,
run:

```sh
python3 scripts/check_zig_line_length.py
```
