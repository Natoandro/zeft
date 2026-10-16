# Contributing

## Repository map

- `src/` contains the public module and implementation.
- `bindings/python/` contains the Python package, managed with `uv`.
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
uv run check-zig-line-length
```

## Releasing

Update the package version in `build.zig.zon`, commit the release changes, and
run `uv run tag-release` from a clean working tree. It creates an annotated
`v<version>` tag. Push that tag to `origin` to trigger the GitHub Release
workflow, which checks the tag against the package version and generates
release notes. `--push` pushes the current branch to `origin` before creating
and pushing the release tag, and `--bump` increments the
versions in the configured manifests, refreshes `uv.lock`, and commits them
after tagging. The bump level can be `major`, `minor`, or `patch` (the default).
Combine them to push the release tag and then make the next-version commit
locally:

```sh
uv run tag-release --push --bump
uv run tag-release --push --bump minor
```

Use `uv run bump-version [--major|--minor|--patch]` to update the package
version in the configured manifests without creating a release tag. The level
defaults to `--patch`. The file list and version patterns are in
`scripts/version_files.json`; the command then regenerates the workspace
`uv.lock` with `uv lock`.
