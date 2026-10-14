# Zeft implementation plan

This plan lists open implementation tasks that are not tracked by GitHub
issues. GitHub issues hold the scope and progress for ticketed work; do not
duplicate them here.

When behavior changes, update the relevant language or public API contract,
add or revise the implementation task and its verification, then implement the
change. The resulting documentation, plan, tests, and code are the record of
the decision; do not maintain a separate decision log.

## Implementation tasks

- [ ] **ZEP-088** Add optional comptime template compilation using the public
  compile options and the same logical compiled contract as runtime
  compilation. Runtime compilation remains the standard API and behavior.
  Verification: add compile-success and build-failure cases for the comptime
  API, and verify equivalent runtime and comptime inputs render identically.

- [ ] **ZEP-089** Adapt supported Zig integers and floats to
  the distinct integer and `f64` runtime values, and preserve optional values
  as their child value or null. Keep compile-time diagnostics for unsupported
  Zig types. Verification: cover root, nested, sequence, null, and concurrent
  contexts, including out-of-range unsigned values.

- [ ] **ZEP-090** Expand HTML compatibility in explicit batches: raw-text
  elements, unquoted attributes, nonvoid self-closing syntax, additional valid
  doctypes, and optional end-tag behavior. Preserve deterministic diagnostics
  rather than silently accepting malformed input. Verification: add positive
  fixtures derived from HTML syntax rules and negative boundary cases for each
  batch.

- [ ] **ZEP-091** Reimplement compact serialization as a normalization pass
  over the already parsed template. Keep pretty serialization as a separate
  pass over the same structure. Treat includes as opaque boundaries and
  preserve raw, preformatted, XML, mixed, and dynamic content. Verification:
  extend the whitespace matrix without asserting CSS-dependent visual layout.

- [ ] **ZEP-092** Add a public include-resolver interface independent of
  `TemplateCache`, then implement that interface for the cache. Verification:
  render the same include graph through the cache and a minimal custom resolver,
  including missing children, cycles, and retained lifetimes.

- [ ] **ZEP-093** Add format-tagged trusted HTML and XML values. Allow trusted
  output only in matching text contexts and reject format or attribute-context
  mismatches. Verification: cover every allowed and rejected context while
  confirming that ordinary strings remain escaped.

- [ ] **ZEP-096** Expand diagnostics with source identities, line/column
  helpers, ordered include stacks, callback failure details, and documented
  partial-output behavior. Verification: cover nested includes, multibyte
  prefixes, callback errors, and writer failures through public APIs.

- [ ] **ZEP-097** Replace separate function and filter registrations with one
  callable namespace. Treat pipe notation solely as alternate call syntax that
  supplies its input as the first argument. Migrate built-ins, diagnostics,
  public render options, expression IR, and existing callers together.
  Verification: cover direct and piped calls, overrides, name collisions,
  failures, argument order, and left-to-right pipelines.

- [ ] **ZEP-098** Generalize postfix expressions so property access and index
  access may follow any primary expression, including grouped expressions and
  call results. Verification: cover chained calls, properties, and indexes,
  their precedence, and invalid postfix syntax.

- [ ] **ZEP-104** Build platform-tagged CPython wheels in GitHub Actions for
  the supported OS, architecture, and Python matrix. Pass explicit Zig target
  triples and import-test the wheel on each supported CPython version.
  Verification: complete the matrix successfully and inspect each wheel's
  platform and ABI tags.

- [ ] **ZEP-105** Use the CPython Stable ABI beginning at Python 3.11 for the
  native extension and publish `abi3` wheels for the supported platform
  targets. Verification: build and inspect each wheel's `abi3` tag, then
  install and import it on CPython 3.11 through 3.14 on every target platform.
