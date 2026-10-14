# Python binding

The Python binding MUST live in `bindings/python/` in the engine repository
and MUST use `uv` for its development environment and dependency lock.
The import package is `zeft` and uses a `src/` layout.

The Zig engine remains responsible for template compilation, execution,
escaping, and template diagnostics. Python-specific packaging, value
conversion, and exception adaptation belong in the binding. The binding MUST
NOT implement a separate template parser or renderer.

Building and consuming the Zig package MUST NOT require Python or `uv`.
Python distributions MAY be released independently of the Zig package.
