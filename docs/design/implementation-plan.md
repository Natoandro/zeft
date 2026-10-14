# Zeft implementation plan

This plan tracks implementation tasks. Each accepted task has a stable reference and is
checked only after its implementation and verification are complete.
Task references are never reused.

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

- [ ] **ZEP-089** After ZEP-102, adapt supported Zig integers and floats to
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

- [x] **ZEP-094** Implement conditional `{:else if expression}` and loop
  `{:else}` as specified by the language contract. Verification: cover empty, nested, shadowed, break,
  and continue behavior with exact diagnostics for invalid placement.

- [x] **ZEP-095** Make null equality compatible with every value type: null
  equals null, differs from every nonnull value, and does not relax other
  cross-type equality rules. Verification: exercise both operators against all
  value tags in folded and runtime expressions.

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

- [x] **ZEP-099** Support block directives
  `{#if expression}`, `{:else if expression}`, `{:else}`, `{/if}`,
  `{#for name in expression}`, and `{/for}`. Keep `{{ expression }}`
  interpolation and the existing standalone include, break, and continue
  directives. Accept only these block forms and preserve fixture case IDs.
  Verification: cover nested blocks, mixed markup, attributes, literal content,
  mismatched and missing closing blocks, invalid branch placement, rejection
  of old forms, and exact diagnostic spans.

- [x] **ZEP-100** Bootstrap the Python binding as a standalone `uv` project
  in `bindings/python/`, with a `src/zeft/` package, typed package marker,
  reproducible dependency lock, and development instructions. Verification:
  build a source distribution and wheel, install the package with `uv`, and
  verify that it imports from the installed package.

- [x] **ZEP-101** Define the initial Python API and CPython extension boundary
  in `docs/architecture/python.md`: compile options, context conversions,
  integer ranges, diagnostics, template ownership, GIL behavior, and MVP
  exclusions. Verification: review each binding contract against the Zig
  public API and confirm that packaging remains independent of the Zig build.

- [x] **ZEP-102** Add signed 64-bit integers as a distinct runtime value
  alongside `f64`. Preserve exact integer formatting and integer arithmetic,
  and define mixed numeric operations and comparisons. Verification: cover
  boundaries, overflow diagnostics, arithmetic, comparisons, formatting, and
  existing floating-point behavior.

- [x] **ZEP-103** Build the CPython extension from the Zig project and package
  it through the Python `uv` project. Initialize `zeft._native` and add a
  native template object that owns and releases a compiled Zig template.
  Verification: build the extension, build the wheel, import it, and confirm
  that the native compile entry point returns an owning template object.

- [ ] **ZEP-104** Build platform-tagged CPython wheels in GitHub Actions for
  the supported OS, architecture, and Python matrix. Pass explicit Zig target
  triples and import-test the wheel on each supported CPython version.
  Verification: complete the matrix successfully and inspect each wheel's
  platform and ABI tags.

- [ ] **ZEP-105** Use the CPython Stable ABI beginning at Python 3.11 for the
  native extension and publish `abi3` wheels for the supported platform
  targets. Verification: build and inspect each wheel's `abi3` tag, then
  install and import it on CPython 3.11 through 3.14 on every target platform.

- [x] **ZEP-106** Complete Python template rendering with conversions for
  common Python context values and compile/render diagnostic exceptions.
  Verification: cover normal rendering, HTML escaping, invalid templates,
  value validation, and native template cleanup in focused Python tests.

- [x] **ZEP-107** Reject interpolation in executable HTML element and attribute
  contexts; validate XML attribute names, uniqueness, UTF-8, and literal
  characters. Enforce a 128-level compiler nesting limit. Verification: S-001,
  S-002, and S-004 cover unsafe contexts, XML failures, and nesting boundaries.

- [x] **ZEP-108** Make Python conversion ownership safe for partial failures,
  cycles, custom mappings, and sequence subclasses. Validate native compile
  options and retain default indentation through compilation. Verification:
  run binding regression tests with Python's debug allocator.

- [x] **ZEP-109** Persist cache diagnostic identities before child leases are
  released and retain missing-root identities through cache deinitialization.
  Verification: S-005 evicts an active child that subsequently fails an include.

- [x] **ZEP-110** Validate evaluated logical operands, support expression stacks
  and argument counts for large flat calls, and propagate callback allocation
  failures. Make all built-ins available to direct calls and let function
  registrations override piped built-ins. Verification: S-003, S-006, S-007,
  and S-009 cover short-circuiting, allocator errors, large calls, and built-ins.

- [x] **ZEP-111** Use hash lookup for larger symbol and string sets, borrow static
  lexer text, release finalization lookup storage, and compute compiled size
  once. Verification: O-003, allocation-failure tests, and compile-scaling
  benchmarks cover ownership, lookup behavior, and scaling without thresholds.

- [x] **ZEP-112** Default Python wheel and source builds to `ReleaseSafe`, allow
  explicit `ZEFT_ZIG_OPTIMIZE` overrides, and report the native build mode in
  comparison benchmarks. Select `ReleaseSafe` explicitly in wheel CI.
  Verification: build and install the default wheel, check its mode metadata,
  run binding tests, validate override handling, and record the comparison run.

- [ ] **ZEP-113** Right-size expression execution storage from compiled
  requirements and reuse render-local storage where callback/include lifetimes
  allow it, while retaining runtime safety checks. Verification: cover stack
  boundaries, large calls, short-circuiting, callback lifetimes, includes,
  allocator cleanup, and concurrent renders; compare initialization, allocations,
  rendering, compilation, and compiled size in both release modes.
  Ticket: [#1](https://github.com/Natoandro/zeft/issues/1).

- [ ] **ZEP-114** After ZEP-113, reduce Python context conversion allocations
  using render-scoped storage and safely retained Python string/key references.
  Preserve eager validation and GIL/lifetime guarantees for custom containers
  and temporary values. Verification: test partial failures, reference cleanup,
  cycles, temporary values, and mutated contexts with native memory instrumentation;
  measure static empty/full-context and dynamic rendering in both release modes.
  Ticket: [#2](https://github.com/Natoandro/zeft/issues/2).

- [ ] **ZEP-115** After ZEP-113 and ZEP-114, fuse measured common lookup and
  interpolation instruction patterns within the existing interpreter. Preserve
  evaluation order, binding scope, source spans, diagnostics, escaping, and
  streaming errors without hoisting failures or introducing JIT compilation.
  Verification: compare fused and general execution, including callbacks and
  mutable context; measure dispatch, rendering, compilation, and compiled size
  in both release modes and retain fixture coverage.
  Ticket: [#3](https://github.com/Natoandro/zeft/issues/3).

Add future work here only after its required behavior and boundaries have been
decided. Record unresolved ideas outside the implementation plan until they
are concrete enough to implement and verify.
