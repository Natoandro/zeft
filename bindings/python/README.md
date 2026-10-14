# Zeft for Python

Python package for the Zeft HTML and XML template engine. The CPython extension
compiles and renders templates, converts common Python values to engine values,
and adapts template diagnostics to Python exceptions.

## Install

Install a published release with `python -m pip install zeft` or `uv add zeft`.
To install a wheel built from a checkout:

```sh
python -m pip install bindings/python/dist/zeft-*.whl
```

Wheel installs include the native extension and do not require Zig. A source
install builds that extension locally and therefore requires Zig 0.16.0 and
the active CPython's development headers:

```sh
python -m pip install ./bindings/python
```

## Supported interpreters and platforms

The package supports CPython 3.11, 3.12, 3.13, and 3.14. It does not currently
publish PyPy wheels. Native wheels are built and import-tested for:

| Operating system | Architectures |
| --- | --- |
| Linux (GNU libc) | x86_64, aarch64 |
| macOS | x86_64, arm64 |
| Windows | x86_64 |

Each wheel is built for its CPython version and platform. Use a matching
interpreter and platform target. Linux wheels are built against the GNU libc
available on the Ubuntu 24.04 runners.

## Development

Use a supported CPython version, Zig 0.16.0, and `uv`. From the repository
root, enter the Python project directory:

```sh
cd bindings/python
uv sync --locked
uv build --wheel
uv run --locked python -c 'import zeft'
uv build --sdist
```

The project uses a `src/` layout, a committed `uv.lock`, and Hatchling for
packaging. A wheel build invokes the Zig `python-extension` build with the
active Python's include directory, copies the extension into the source
package, then packages it. The copy also makes the extension available to the
editable package installed by `uv sync`. The source distribution includes the
Zig build inputs under `engine/`; installing it builds the extension from those
sources. Build artifacts are written to `bindings/python/dist/`. Building or
consuming the Zig package does not require Python or `uv`.

From `bindings/python/`, run the focused binding tests after building the
extension with `uv run --locked python -m unittest discover -s tests`. The
`Python wheels` GitHub Actions workflow clears previous build outputs, builds
and installs a native wheel for every supported interpreter and platform, then
checks that compilation and rendering work. A separate source distribution job
builds and installs directly from the sdist in a clean environment.

## Example

After the development setup above, run the page-rendering example from
`bindings/python/`:

```sh
uv run --locked python examples/render_page.py
```

After a clean checkout, build the wheel first with `uv build --wheel` so the
native extension is available to the editable package.

It compiles one template, renders a nested list of Python dictionaries, and
uses a context manager to release the compiled template.

## Compare Python template engines

The benchmark compares an HTML escaping and loop workload with one item and a
configurable batch against Jinja2 and Mako. It reports template construction,
repeated rendering with a reused template, and construction plus rendering.
From `bindings/python/`, run the benchmark with Jinja2 and Mako added to an
ephemeral uv environment:

```sh
uv build --wheel
uv run --with jinja2 --with mako python benchmarks/compare.py
```

The two comparison engines are installed for this run without adding them to
the project's dependencies or lockfile. The wheel build makes the native Zeft
extension available to the editable package.

Use `--items`, `--iterations`, and `--rounds` to adjust the workload. The
script reports package versions and platform details, checks representative
output fragments before timing, and prints medians in nanoseconds per
operation. Timings depend on the interpreter, machine, and dependency versions;
the harness does not impose performance thresholds. It compares equivalent
HTML escaping and loop work, while each engine uses its own syntax and
configuration (`autoescape=True` for Jinja2 and Mako's `h` filter).

The engine lives in the repository's `src/` directory. Binding implementation
and packaging belong here; binding unit tests and integration tests belong in
`tests/unit/` and `tests/integration/` under this directory. Reusable engine
fixtures remain in the repository's `tests/fixtures/` catalog.
