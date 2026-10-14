# Python binding

The Python binding MUST live in `bindings/python/` in the engine repository
and MUST use `uv` for its development environment and dependency lock.
The import package is `zeft` and uses a `src/` layout.
The binding MUST be implemented as a CPython extension.

The Zig engine remains responsible for template compilation, execution,
escaping, and template diagnostics. Python-specific packaging, value
conversion, and exception adaptation belong in the binding. The binding MUST
NOT implement a separate template parser or renderer.

## Initial Python API

The first usable API MUST expose:

```python
import zeft

template = zeft.compile(source, *, format="html", whitespace="preserve", indentation="  ")
output = template.render(context)
template.close()
```

`source` MUST be `str`. `format` accepts `"html"` or `"xml"`;
`whitespace` accepts `"preserve"`, `"compact"`, or `"pretty"`; and
`indentation` MUST be `str`. They map to the Zig `CompileOptions`. Defaults
match the Zig API. Unknown options and values of the wrong type raise
`TypeError`; unknown option strings raise `ValueError`.

`compile()` returns an owning `Template` object. It keeps the compiled Zig
template alive until `close()` or object finalization. `close()` is idempotent;
rendering a closed template raises `ValueError`. `Template` MUST support the
context manager protocol so `with zeft.compile(...) as template:` closes the
native template on exit. Rendering and closing the same object are serialized
by the Python global interpreter lock (GIL).

`Template.render(context)` accepts a mapping with string keys. Its values may
be `None`, `bool`, `int`, `float`, `str`, nested mappings, lists, or tuples.
Strings are UTF-8 encoded for the engine; bytes are not accepted. Mapping
keys that are not strings and unsupported value types raise `TypeError`.
Booleans map to booleans, `None` to null, strings to strings, and lists and
tuples to sequences. Python integers in the signed 64-bit range map to exact
Zeft integers. Integers outside `[-2**63, 2**63 - 1]` raise
`OverflowError`. Floats map to the engine's `f64` number. A Python `bool` is
handled as a boolean before integer conversion.

Render output is returned as `str`, decoded from the engine's UTF-8 output.
The initial binding does not expose include resolvers, function or filter
callbacks, or template caches. A template that attempts an include therefore
raises `RenderError` for the engine's missing-template diagnostic.

The module MUST define `TemplateError`, `CompileError(TemplateError)`, and
`RenderError(TemplateError)`. A compile diagnostic raises `CompileError`; a
render diagnostic raises `RenderError`. Both expose a stable string `kind`
and an optional half-open byte `span` tuple `(start, end)`. Their messages
identify the diagnostic kind. Invalid Python arguments use Python's standard
`TypeError`, `ValueError`, and `OverflowError`. Native allocation failures
raise `MemoryError`.

The extension MUST keep Python context objects alive for the duration of
rendering and MUST access them only while holding the GIL. It MUST NOT retain
references to the render context after `render()` returns. Compiled template
state remains immutable between calls; context access and rendering happen
synchronously under the GIL in the initial API.

Python wheels MUST support CPython 3.11 through 3.14 on Linux x86_64 and
aarch64, macOS x86_64 and arm64, and Windows x86_64. The extension MUST use
the CPython Stable ABI with Python 3.11 as its minimum ABI version and publish
`abi3` wheels for each supported platform target. The build workflow MUST
import-test those wheels on every supported CPython version before publishing
the artifacts.

Building and consuming the Zig package MUST NOT require Python or `uv`.
Python distributions MAY be released independently of the Zig package.

Python wheel builds and extension builds from source distributions MUST default
to Zig `ReleaseSafe`. Published wheel builds MUST select `ReleaseSafe`
explicitly. Local builds MAY override the mode through `ZEFT_ZIG_OPTIMIZE`,
accepting `Debug`, `ReleaseSafe`, `ReleaseFast`, or `ReleaseSmall`. This default
does not change the Zig package's build-mode selection.
