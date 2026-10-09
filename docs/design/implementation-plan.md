# Zeft implementation plan

This plan sequences implementation of the architecture in this directory. It
starts with a small, working vertical slice and expands it into the complete
runtime-first template engine. Phase 1 exercises every compiler and renderer
boundary with a deliberately small language; it does not attempt the full
syntax or optimization set.

Every task is a checklist item with a stable, unique reference. Keep references
unchanged when editing task wording, and do not reuse a reference if a task is
removed. A task is complete only when its implementation and its listed
verification are both complete.

## Phase 0 — Establish the implementation foundation

**Outcome:** a buildable Zig package with public module boundaries and a place
to add executable specifications.

- [x] **ZEP-001** Record the supported Zig compiler version and the command used
  to build the package.
- [x] **ZEP-002** Add the Zig package/build configuration and a minimal library
  module that exports the `zeft` namespace.
- [x] **ZEP-003** Define the initial public `compile(allocator, source, options)`
  API and an owning `CompiledTemplate` type with `deinit`.
- [x] **ZEP-004** Define compile options with explicit output format and
  whitespace policy fields; set the initial implementation defaults in the
  API documentation.
- [x] **ZEP-005** Define structured compile and render error categories and a
  source-span type shared by compiler and runtime diagnostics.
- [x] **ZEP-006** Establish unit-test and integration-test module layout, with
  fixtures kept separate from implementation code.

## Phase 1 — Complete the first vertical slice

**Outcome:** compile and render one small, real markup template through every
architectural phase. Keep the language subset intentionally narrow: HTML
elements, text, one root-context identifier expression, and HTML text escaping.
Do not add conditionals, loops, XML, dynamic attributes, caching, or advanced
optimization in this phase.

The Phase 1 subset MUST support HTML only, opening and closing elements with
ASCII names beginning with a letter or underscore and continuing with letters,
digits, underscore, hyphen, colon, or period, and no attributes. Element names
match case-insensitively in this subset. Attributes, comments, declarations,
void-element behavior, XML, and interpolation inside markup constructs are
deferred to later work. Interpolation in this subset MUST be a single ASCII
identifier matching `[A-Za-z_][A-Za-z0-9_]*`; property access, literals,
operators, calls, filters, and local bindings are deferred.
The initial renderer context MUST be a generic Zig struct whose fields are
byte strings; non-string values are deferred. The initial whitespace policy
MUST support preserve; requests for other policies MUST return an
unsupported_syntax diagnostic.

The end-to-end acceptance case is a template such as
`<p>Hello, {{ name }}!</p>` rendered with `name = "<Ada>"` as
`<p>Hello, &lt;Ada&gt;!</p>`. It must travel through parsing, analysis,
lowering, optimization, finalization, and VM execution.

- [x] **ZEP-007** Define the minimal template delimiter rules needed to
  distinguish markup text from `{{ ... }}` expressions.
- [x] **ZEP-008** Implement source-span tracking for every token and AST node
  used by the vertical slice.
- [x] **ZEP-009** Implement a lexer/parser for static text, opening and closing
  HTML elements, and text-position interpolation.
- [x] **ZEP-010** Build a temporary AST with element, text, and expression
  nodes; ensure the compiled template does not retain AST pointers.
- [x] **ZEP-011** Implement the analysis phase for the vertical-slice AST,
  assigning symbol IDs to root-context identifiers and marking HTML text
  output context.
- [x] **ZEP-012** Implement a minimal expression parser for a single identifier
  lookup and lower it into expression IR.
- [x] **ZEP-013** Define the initial linear Render IR instruction set for static
  writes, expression writes, and program termination.
- [x] **ZEP-014** Lower AST nodes into Render IR and expression IR, including
  static markup serialization.
- [x] **ZEP-015** Implement the first semantics-preserving optimizer pass that
  merges adjacent static writes; run the optimizer phase even when it has no
  further work.
- [x] **ZEP-016** Finalize the IR, strings, symbols, metadata, and source maps
  into allocator-owned immutable `CompiledTemplate` storage.
- [x] **ZEP-017** Implement a render-local VM that executes the initial Render
  IR and writes static bytes directly to a caller-provided writer.
- [x] **ZEP-018** Implement root-context identifier lookup and HTML text
  escaping for dynamic values.
- [x] **ZEP-019** Add the end-to-end acceptance test above, plus tests for
  repeated rendering, compile-time syntax failure, writer failure propagation,
  and template deinitialization.

## Phase 2 — Complete structured markup parsing

**Outcome:** parse the markup structures required by the architecture without
turning the renderer into a markup parser.

- [x] **ZEP-020** Extend the AST and parser to represent attributes and their
  names, quoting style, and value segments.
- [x] **ZEP-021** Support interpolation within attribute values and preserve
  each expression's attribute output context.
- [x] **ZEP-022** Implement HTML boolean attributes and HTML void-element
  serialization rules.
- [x] **ZEP-023** Implement comments, declarations, and the static markup
  constructs selected for the initial HTML grammar.
- [x] **ZEP-024** Validate balanced elements and report malformed markup with
  source locations.
- [x] **ZEP-025** Add XML format parsing and serialization rules, including
  case-sensitive names and XML empty-element behavior.
- [x] **ZEP-026** Test text and attribute escaping in both HTML and XML formats.
- [x] **ZEP-027** Add parser tests for nested elements, mixed text and markup,
  quoted attributes, malformed nesting, and source spans.
- [x] **ZEP-028** Verify static HTML/XML markup is fully serialized before
  rendering and that the runtime contains no markup parsing path.

## Phase 3 — Expand expression compilation and evaluation

**Outcome:** expressions are compiled independently from template structure
and run through expression IR without reparsing source text.

- [x] **ZEP-029** Specify expression precedence, associativity, literal forms,
  and supported operators in the language documentation.
- [x] **ZEP-031** Add property access and non-negative literal sequence indexes
  to expression parsing, analysis, and evaluation.
- [x] **ZEP-033** Define the runtime `Value` representation for null,
  booleans, numbers, strings, sequences, and objects.
- [x] **ZEP-034** Implement the initial adapter boundary for nested Zig
  structs, arrays/slices, and byte-string leaves.
- [x] **ZEP-030** Extend the expression AST and parser to cover the specified
  literals, unary operators, binary operators, and grouped expressions.
- [x] **ZEP-032** Implement short-circuit evaluation for logical operators.
- [x] **ZEP-035** Define filter and function registration and invocation
  contracts, then implement the initial built-in set.
- [x] **ZEP-036** Map expression instructions to source spans and report
  property, operand, filter, and function failures at the originating source.
- [x] **ZEP-037** Add expression unit tests, including precedence,
  short-circuit behavior, property access, missing values, and runtime errors.

The expression implementation covers the specified access, literal, operator,
short-circuit, function, and filter forms through compiled expression IR.

## Phase 4 — Add branches, loops, and lexical scopes

**Outcome:** `{% if expression %}`, `{% else %}`, `{% endif %}`,
`{% for name in expression %}`, `{% endfor %}`, `{% break %}`, and
`{% continue %}` lower to explicit control flow and execute with isolated
render-local state. There is no `else if`; loops alone create lexical scopes,
and inner loop bindings shadow outer and root names.

- [x] **ZEP-038** Specify conditional, loop, loop-control, and scope syntax and
  their compile-time validation rules.
- [x] **ZEP-039** Add conditional and loop nodes to the template AST, retaining
  source spans for delimiters and bodies.
- [x] **ZEP-040** Analyze lexical bindings and resolve loop-local names to
  local slots where statically known.
- [x] **ZEP-041** Add conditional branch and jump instructions with validated
  destinations to Render IR.
- [x] **ZEP-042** Implement `LOOP_BEGIN` and `LOOP_NEXT` lowering and VM
  execution, including empty iterables.
- [x] **ZEP-043** Implement nested render-local scopes and loop state without
  mutating the compiled template.
- [x] **ZEP-044** Define behavior for nested loops, shadowed names, and
  conditionals inside loops.
- [x] **ZEP-045** Add compile diagnostics for invalid control-flow constructs
  and malformed block nesting.
- [x] **ZEP-046** Add integration tests for true/false branches, empty and
  non-empty loops, nested scopes, shadowing, and concurrent renders of one
  compiled template.

## Phase 5 — Implement whitespace and format policies

**Outcome:** preserve, compact, and pretty output are compile-time policies
that respect markup and text semantics.

- [x] **ZEP-047** Specify preserve-mode behavior for source whitespace and
  dynamic boundaries.
- [x] **ZEP-048** Implement compact-mode whitespace normalization in the
  compiler and serializer.
- [x] **ZEP-049** Implement pretty-mode structural indentation in lowering or
  static serialization.
- [x] **ZEP-050** Preserve whitespace in whitespace-sensitive elements and
  meaningful inline text boundaries in every applicable mode.
- [x] **ZEP-051** Add whitespace tests for `pre`-like content, form text,
  inline elements, and dynamic loop output.
- [x] **ZEP-052** Ensure format and whitespace settings are retained as
  compiled metadata and distinguish compiled outputs.
- [x] **ZEP-053** Add golden-output fixtures for representative HTML and XML
  templates in every supported whitespace mode.

## Phase 6 — Finish runtime diagnostics and lifecycle guarantees

**Outcome:** the renderer has explicit error behavior, safe immutable template
reuse, and well-defined allocation lifetimes.

- [x] **ZEP-054** Make missing-variable behavior an error by default and test
  its source location and error category.
- [x] **ZEP-055** Define runtime errors for non-iterable values, invalid
  property access, invalid operands, and filter/function failures.
- [x] **ZEP-056** Ensure writer failures propagate without being replaced by
  template errors.
- [x] **ZEP-057** Verify compile temporaries are released after finalization
  and persistent template storage remains valid until `deinit`.
- [x] **ZEP-058** Verify every render owns its program counter, scopes, and loop
  iterators, and that concurrent renders do not share mutable state.
- [x] **ZEP-059** Document allocator requirements and the lifetime rules for
  compiled templates and render-local scratch data.

## Phase 7 — Add explicit cache and independently compiled includes

**Outcome:** applications can reuse compiled templates and reload changed
sources without putting filesystem or cache behavior inside `compile()`.

- [x] **ZEP-060** Define `TemplateCache` ownership, identity, get-or-compile,
  and deinitialization APIs.
- [x] **ZEP-061** Include source content, compile options, and compiler/IR
  version in cache identity.
- [x] **ZEP-062** Implement explicit reload through get-or-compile and replace
  a cached entry only after changed source compiles successfully.
- [x] **ZEP-063** Add template include syntax and lower includes to calls with
  stable child-template identities.
- [x] **ZEP-064** Resolve the current independently compiled child through the
  cache for each render.
- [x] **ZEP-065** Keep cached entries alive while active renders reference
  them, including during replacement and eviction.
- [x] **ZEP-066** Specify and implement include-cycle behavior, and report
  missing includes and child compile failures with dependency context.
- [x] **ZEP-067** Add tests for cache hits, option-sensitive identities,
  changed source, failed reload preservation, changed child templates, and
  concurrent access.

## Phase 8 — Add measured compiler optimizations

**Outcome:** measure compiler and renderer costs, then improve the costs that
the measurements identify while preserving the architecture and behavior
already established by tests.

- [x] **ZEP-068** Add benchmark fixtures for compile time, render time,
  allocations, write-call count, and compiled-template size.
- [x] **ZEP-069** Implement constant expression folding with source-map
  preservation.
- [x] **ZEP-070** Implement dead-branch and empty-operation elimination.
- [x] **ZEP-071** Implement jump threading and branch simplification while
  validating all instruction destinations after each pass.
- [x] **ZEP-072** Intern repeated symbols and strings in finalized template
  storage.
- [x] **ZEP-073** Optimize static markup serialization and adjacent writes
  using benchmark evidence.

## Phase 9 — Complete fixture-driven end-to-end coverage

**Outcome:** a large, traceable suite exercises the public compile/render and
cache APIs against the specified architecture, covering successful output and
failures. Compiler-internal assertions remain in unit tests. Comptime cases
T-001 and T-002 remain pending until their public API is defined.

### Coverage and fixture structure

The starting inventory is eight `.tmpl` files and fourteen file-backed golden
render cases. Most diagnostics, lifecycle, and cache scenarios currently use
inline Zig sources. Catalog status currently mixes executable golden cases
with focused tests; reconcile that distinction before expanding the suite.

Use explicit Zig case descriptors to embed fixture files and declare case IDs,
compile options, typed contexts, render registrations, and expected outcomes.
Keep template input and exact successful output in `.tmpl` and `.out` files.
Keep expected diagnostic categories and half-open byte spans in descriptors;
avoid introducing a new context or expectation serialization language. Give
each executable case a unique ID, retaining the existing catalog IDs as
coverage references when several cases verify one requirement. Report both
the case ID and fixture path when a case fails.

Organize reusable inputs under `tests/fixtures/` by behavior: HTML, XML,
expressions, control flow, whitespace, compile errors, render errors, and
includes. Keep suite code under `tests/`, with `tests/integration.zig` importing
the case groups. Cache scenarios need explicit sequences of public API calls;
lifecycle and concurrency scenarios need dedicated Zig harnesses.

Target approximately 150–220 named executions initially, including option and
context variants. This is a sizing estimate, not a completion criterion.
Every applicable catalog requirement needs positive, negative, and boundary
coverage where those outcomes are specified. Avoid multiplying every feature
by every option; use full matrices for escaping and whitespace and selected
combinations elsewhere. Expected results must come from requirements and be
reviewed independently of the renderer's actual output.

### Implementation sequence

- [x] **ZEP-074** Audit every catalog row against normative requirements and
  actual executable tests. Record the owning test/fixture and concrete gaps;
  distinguish fixture coverage, focused test coverage, and pending features.
  Preserve all existing IDs. Remove stale implementation-status prose in this
  plan where it contradicts completed tasks, after confirming current code.
  Verification: every catalog row has an accurate coverage mapping.
- [x] **ZEP-075** Extract shared fixture helpers and introduce explicit named
  descriptors for successful renders, compile failures, and render failures.
  Support typed native contexts and callback registrations. Replace the fixed
  1,024-byte golden-output buffer with a writer sized to expected output plus
  headroom, reporting overflow as a case failure. Migrate existing goldens
  without changing their expected bytes. Verification: all fourteen existing
  golden executions remain active and failure reports identify the case.
- [x] **ZEP-076** Expand markup and escaping fixtures (M-001–M-013, E-001,
  E-010). Cover all fourteen HTML void tags in both opening forms, mixed case,
  boolean versus quoted attributes, both attribute quote styles, multiple
  interpolation segments, delimiter escapes, comments and doctypes. Cover XML
  fragments, case-sensitive names, empty-element spelling, declarations,
  entities, and literal CDATA. Exercise all five escape-sensitive characters
  in HTML/XML text and both attribute quote styles. Verification: exact bytes
  and corresponding invalid-markup cases through the public compiler.
- [ ] **ZEP-077** Expand expression/value fixtures (E-002–E-009, E-011–E-012).
  Cover every operator, adjacent precedence levels, associativity, grouping,
  numeric forms, all six string escapes, literal/name case sensitivity,
  dynamic indexes, nested access, and short-circuit skipping of failing
  accesses/calls. Exercise built-in and registered calls, argument counts,
  nested calls, pipelines, overrides, and native value adapters. Use context
  operands as well as literals so optimizer folding cannot replace all VM
  coverage. Verification: output and specified failure categories/spans.
- [ ] **ZEP-078** Expand control-flow fixtures (F-001–F-011). Cover both
  branches, nested conditions, empty/single/multiple-item loops, nested loops,
  root and outer-binding restoration, break/continue in nested branches, and
  selectors on local values. Reuse compiled templates across differing
  contexts, including a failed render followed by success. Verification:
  exact output, runtime condition/iterable errors, and invalid nesting cases.
- [ ] **ZEP-079** Expand whitespace fixtures (W-001–W-007). Exercise all three
  policies in both formats, element-only and mixed content, empty dynamic
  output, conditional/loop-generated siblings, custom indentation, and every
  HTML whitespace-sensitive element. Verify XML names do not inherit HTML
  sensitivity. Verification: independently authored byte-exact goldens,
  including leading/trailing spaces, tabs, and final-newline differences.
- [ ] **ZEP-080** Complete compile/render diagnostic fixture tables
  (C-001–C-005, R-001–R-003, and failures from earlier groups). Cover malformed
  delimiters, literal syntax, selectors, operators, calls, declarations,
  entities, comments, CDATA, attributes, and directives. Cover missing names,
  invalid selectors/operands/conditions/iterables, unknown callables, invalid
  arity/types, and callback failures. Add leading multibyte source text to
  representative cases to verify byte offsets. Verification: exact category
  and half-open span; compile failures never proceed to rendering. Assert
  partial output only where the architecture defines that behavior.
- [ ] **ZEP-081** Add fixture-backed cache/include scenarios (K-001–K-008).
  Cover hits, distinct identities, all output-affecting options including
  indentation, reload success/failure, nested/repeated includes, changed child
  output without parent recompilation, missing roots/children, initial child
  compile failure, cycles, and retained leases across replacement/eviction.
  Verification: output plus dependency identities, directive spans, child
  diagnostics, and specified lease/version behavior through public APIs.
- [ ] **ZEP-082** Complete dedicated lifecycle and concurrency integration
  harnesses (R-004–R-008, F-011, K-007–K-008). Reuse representative fixture
  inputs for writer failures in static/dynamic/include output, freed source
  and option buffers, scratch cleanup on success and failures, and overlapping
  renders/reloads/evictions. Use synchronization to establish overlap rather
  than timing sleeps. Retain allocator-failure checks and internal optimizer
  assertions in their appropriate focused tests. Verification: original writer
  errors, allocation cleanup, valid retained storage, and isolated outputs.
- [ ] **ZEP-083** Audit suite completeness and update fixture documentation.
  Ensure every registered input/output exists, every enabled fixture is
  registered, IDs are unique, and catalog paths/statuses match execution.
  Record actual fixture and execution counts and remaining pending API cases.
  Verification: run `zig fmt` on changed Zig files, `zig build`, and
  `zig build test`; also run the suite in ReleaseSafe to check behavior with
  optimization enabled. Check each task only after its verification passes.

For each batch, format changed Zig files and run `zig build` and
`zig build test` before marking coverage enabled. If a fixture exposes a
clear implementation defect against the architecture, fix it with that
regression case. If expected behavior requires a new product or architecture
decision, ask in the conversation before defining the fixture. Do not derive
goldens automatically from current renderer output or silently weaken an
expectation to make a test pass.

## Completion policy

Implement phases in order. A later phase may begin only when the preceding
phase's outcome and verification items are complete. Phase 1 is the first
usable product slice; later phases add breadth and optimization without
changing its compile-once/render-many contract. Update the architecture
documents whenever implementation reveals a required change to a normative
contract; make that change explicit before coding against it.
