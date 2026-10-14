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
configuration (`autoescape=True` for Jinja2 and `default_filters=["h"]` for
Mako).

### Sample results

Measured on an AMD Ryzen 5 5600G with Python 3.11.12, Linux
6.12.63+deb13-amd64 (x86_64), and glibc 2.41, using the commands above.
The Zeft extension uses Zig's default Debug build mode. Each timing is the
median of seven rounds of 2,000 operations, after up to 100 warmup operations
per measurement. Representative output checks passed for all engines.

Times are nanoseconds per operation; lower is better. Compilation includes
template construction and cleanup. Rendering reuses a compiled template and
includes the Python binding's context conversion for Zeft. Compile + render
constructs, renders, and releases a template on every operation.

| Items | Engine | Version | Compile | Render | Compile + render |
| --- | --- | --- | ---: | ---: | ---: |
| 1 | Zeft | 0.1.0 | 43,413 | 11,173 | 71,877 |
| 1 | Jinja2 | 3.1.6 | 602,156 | 7,201 | 562,392 |
| 1 | Mako | 1.4.3 | 518,222 | 8,551 | 581,938 |
| 100 | Zeft | 0.1.0 | 43,635 | 158,369 | 220,554 |
| 100 | Jinja2 | 3.1.6 | 543,675 | 155,294 | 718,432 |
| 100 | Mako | 1.4.3 | 511,966 | 80,760 | 631,978 |

For this workload, Zeft compiles about 12–14 times faster than Jinja2 and Mako.
Compile + render is about 8 times faster with one item and 2.9–3.3 times faster
with 100 items. Reused-template rendering is slower than both engines with
one item; with 100 items, it is close to Jinja2 and about 2 times slower than
Mako. These observations cover this escaping and loop workload;
they do not establish performance across other templates or machines.

The engine lives in the repository's `src/` directory. Binding implementation
and packaging belong here; binding unit tests and integration tests belong in
`tests/unit/` and `tests/integration/` under this directory. Reusable engine
fixtures remain in the repository's `tests/fixtures/` catalog.
