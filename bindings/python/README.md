# Zeft for Python

Python package for the Zeft HTML and XML template engine. The package is a
bootstrap scaffold: compilation and rendering are not yet exposed to Python.

## Development

Use Python 3.11 or newer and `uv`. From the repository root:

```sh
uv sync --project bindings/python --locked
uv run --project bindings/python --locked python -c 'import zeft'
uv build --project bindings/python
```

The project uses a `src/` layout, a committed `uv.lock`, and Hatchling for
packaging. Build artifacts are written to `bindings/python/dist/`. Python
packaging is independent of the root Zig build.

The engine lives in the repository's `src/` directory. Binding implementation
and packaging belong here; binding unit tests and integration tests belong in
`tests/unit/` and `tests/integration/` under this directory. Reusable engine
fixtures remain in the repository's `tests/fixtures/` catalog.
