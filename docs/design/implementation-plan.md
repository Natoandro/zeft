# Zeft implementation plan

This plan tracks future work. Each accepted task has a stable reference and is
checked only after its implementation and verification are complete.
References `ZEP-001` through `ZEP-087` are complete and preserved in Git
history; references are never reused.

When behavior changes, update the relevant language or public API contract,
add or revise the implementation task and its verification, then implement the
change. The resulting documentation, plan, tests, and code are the record of
the decision; do not maintain a separate decision log.

## Future work

- [ ] **ZEP-088** Add optional comptime template compilation using the public
  compile options and the same logical compiled contract as runtime
  compilation. Runtime compilation remains the standard API and behavior.
  Verification: add compile-success and build-failure cases for the comptime
  API, and verify equivalent runtime and comptime inputs render identically.

- [ ] **ZEP-089** Extend native value adaptation to integers, floats, and
  optionals with compile-time diagnostics for unsupported Zig types.
  Verification: cover root, nested, sequence, null, and concurrent contexts.

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

- [ ] **ZEP-094** Implement `{% elif %}` and loop `{% else %}` as specified by
  the language contract. Verification: cover empty, nested, shadowed, break,
  and continue behavior with exact diagnostics for invalid placement.

- [ ] **ZEP-095** Make null equality compatible with every value type: null
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

Add future work here only after its required behavior and boundaries have been
decided. Record unresolved ideas outside the implementation plan until they
are concrete enough to implement and verify.
