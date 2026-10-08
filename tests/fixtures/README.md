# Test fixtures

Fixtures are golden inputs for end-to-end compilation and rendering. Keep
template source (`.tmpl`) and exact expected output (`.out`) separate from test
runner code. A fixture is enabled when `tests/integration.zig` embeds it in the
active golden-fixture test.

See [catalog.md](catalog.md) for the planned fixture inventory. It records
current executable fixtures and the future scenarios that still need concrete
template syntax or runtime APIs.

## Enabled fixture groups

| Group | Coverage |
| --- | --- |
| `html/static` | Nested markup, exact static attributes, void elements, doctype, comments, and text delimiter escapes |
| `html/dynamic` | Text and quoted-attribute interpolation with HTML escaping |
| `html/expressions` | Property and index access, operators, short-circuiting, and built-in filters/functions |
| `html/control-flow` | Conditional branches, loop bindings, root-name restoration, and lexical scope |
| `xml/fragment` | XML declaration, fragments, empty elements, CDATA, entity preservation, and XML escaping |

Context values are supplied by the Zig test because fixtures intentionally
contain only template language input and expected bytes. The fixture test
compiles each source with its declared format and compares the complete output
byte-for-byte. Focused parser, diagnostic, and lifecycle assertions remain in
the Zig test files when they need to inspect internal structures or error
spans.

The architecture documents define expected behavior. The catalog tracks
fixture coverage and does not replace those requirements.
