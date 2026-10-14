# Zeft for Python

Python package for the Zeft HTML and XML template engine. The CPython extension
currently provides a minimal compile entry point that returns a native owning
template object. Rendering and the complete documented API are still pending.

## Development

Use Python 3.11 or newer and `uv`. From the repository root:

```sh
uv sync --project bindings/python --locked
uv run --project bindings/python --locked python -c 'import zeft'
uv build --project bindings/python
```

The project uses a `src/` layout, a committed `uv.lock`, and Hatchling for
packaging. Building a wheel invokes the Zig `python-extension` build with the
active Python's include directory, then packages the resulting extension. The
source distribution includes the Zig build inputs under `engine/` so wheels
can be built from the source distribution.
Build artifacts are written to `bindings/python/dist/`. Building or consuming
the Zig package does not require Python or `uv`.

The engine lives in the repository's `src/` directory. Binding implementation
and packaging belong here; binding unit tests and integration tests belong in
`tests/unit/` and `tests/integration/` under this directory. Reusable engine
fixtures remain in the repository's `tests/fixtures/` catalog.
