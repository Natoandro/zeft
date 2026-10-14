# Zeft for Python

Python package for the Zeft HTML and XML template engine. The CPython extension
compiles and renders templates, converts common Python values to engine values,
and adapts template diagnostics to Python exceptions.

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

The focused binding tests can be run after building the extension with
`python3 -m unittest discover -s bindings/python/tests`. The `Python wheels`
GitHub Actions workflow builds CPython 3.11 through 3.14
for Linux x86_64/aarch64, macOS x86_64/arm64, and Windows x86_64. Each job
passes an explicit Zig target, installs the wheel, and checks that the native
compile entry point imports and returns a template.

The engine lives in the repository's `src/` directory. Binding implementation
and packaging belong here; binding unit tests and integration tests belong in
`tests/unit/` and `tests/integration/` under this directory. Reusable engine
fixtures remain in the repository's `tests/fixtures/` catalog.
