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
- [ ] **ZEP-035** Define filter and function registration and invocation
  contracts, then implement the initial built-in set.
- [ ] **ZEP-036** Map expression instructions to source spans and report
  property, operand, filter, and function failures at the originating source.
- [x] **ZEP-037** Add expression unit tests, including precedence,
  short-circuit behavior, property access, missing values, and runtime errors.

The expression grammar specifies the target language. The current expression
implementation accepts identifier/property/index access only; operator
compilation and evaluation remain in ZEP-030 and ZEP-032.

## Phase 4 — Add branches, loops, and lexical scopes

**Outcome:** conditional and iterative template constructs lower to explicit
linear control flow and execute with isolated render-local state.

- [ ] **ZEP-038** Specify conditional, loop, loop-control, and scope syntax and
  their compile-time validation rules.
- [ ] **ZEP-039** Add conditional and loop nodes to the template AST, retaining
  source spans for delimiters and bodies.
- [ ] **ZEP-040** Analyze lexical bindings and resolve loop-local names to
  local slots where statically known.
- [ ] **ZEP-041** Add conditional branch and jump instructions with validated
  destinations to Render IR.
- [ ] **ZEP-042** Implement `LOOP_BEGIN` and `LOOP_NEXT` lowering and VM
  execution, including empty iterables.
- [ ] **ZEP-043** Implement nested render-local scopes and loop state without
  mutating the compiled template.
- [ ] **ZEP-044** Define behavior for nested loops, shadowed names, and
  conditionals inside loops.
- [ ] **ZEP-045** Add compile diagnostics for invalid control-flow constructs
  and malformed block nesting.
- [ ] **ZEP-046** Add integration tests for true/false branches, empty and
  non-empty loops, nested scopes, shadowing, and concurrent renders of one
  compiled template.

## Phase 5 — Implement whitespace and format policies

**Outcome:** preserve, compact, and pretty output are compile-time policies
that respect markup and text semantics.

- [ ] **ZEP-047** Specify preserve-mode behavior for source whitespace and
  dynamic boundaries.
- [ ] **ZEP-048** Implement compact-mode whitespace normalization in the
  compiler and serializer.
- [ ] **ZEP-049** Implement pretty-mode structural indentation in lowering or
  static serialization.
- [ ] **ZEP-050** Preserve whitespace in whitespace-sensitive elements and
  meaningful inline text boundaries in every applicable mode.
- [ ] **ZEP-051** Add whitespace tests for `pre`-like content, form text,
  inline elements, and dynamic loop output.
- [ ] **ZEP-052** Ensure format and whitespace settings are retained as
  compiled metadata and distinguish compiled outputs.
- [ ] **ZEP-053** Add golden-output fixtures for representative HTML and XML
  templates in every supported whitespace mode.

## Phase 6 — Finish runtime diagnostics and lifecycle guarantees

**Outcome:** the renderer has explicit error behavior, safe immutable template
reuse, and well-defined allocation lifetimes.

- [ ] **ZEP-054** Make missing-variable behavior an error by default and test
  its source location and error category.
- [ ] **ZEP-055** Define runtime errors for non-iterable values, invalid
  property access, invalid operands, and filter/function failures.
- [ ] **ZEP-056** Ensure writer failures propagate without being replaced by
  template errors.
- [ ] **ZEP-057** Verify compile temporaries are released after finalization
  and persistent template storage remains valid until `deinit`.
- [ ] **ZEP-058** Verify every render owns its program counter, scopes, and loop
  iterators, and that concurrent renders do not share mutable state.
- [ ] **ZEP-059** Document allocator requirements and the lifetime rules for
  compiled templates and render-local scratch data.

## Phase 7 — Add explicit cache and independently compiled includes

**Outcome:** applications can reuse compiled templates and reload changed
sources without putting filesystem or cache behavior inside `compile()`.

- [ ] **ZEP-060** Define `TemplateCache` ownership, identity, get-or-compile,
  and deinitialization APIs.
- [ ] **ZEP-061** Include source content, compile options, and compiler/IR
  version in cache identity.
- [ ] **ZEP-062** Implement development reload detection and replace a cached
  entry only after changed source compiles successfully.
- [ ] **ZEP-063** Add template include syntax and lower includes to calls with
  stable child-template identities.
- [ ] **ZEP-064** Resolve the current independently compiled child through the
  cache for each render.
- [ ] **ZEP-065** Keep cached entries alive while active renders reference
  them, including during replacement and eviction.
- [ ] **ZEP-066** Specify and implement include-cycle behavior, and report
  missing includes and child compile failures with dependency context.
- [ ] **ZEP-067** Add tests for cache hits, option-sensitive identities,
  changed source, failed reload preservation, changed child templates, and
  concurrent access.

## Phase 8 — Add measured compiler optimizations

**Outcome:** improve compiled size and render cost while preserving the
architecture and behavior already established by tests.

- [ ] **ZEP-068** Add benchmark fixtures for compile time, render time,
  allocations, write-call count, and compiled-template size.
- [ ] **ZEP-069** Implement constant expression folding with source-map
  preservation.
- [ ] **ZEP-070** Implement dead-branch and empty-operation elimination.
- [ ] **ZEP-071** Implement jump threading and branch simplification while
  validating all instruction destinations after each pass.
- [ ] **ZEP-072** Intern repeated symbols and strings in finalized template
  storage.
- [ ] **ZEP-073** Optimize static markup serialization and adjacent writes
  using benchmark evidence.
- [ ] **ZEP-074** Record before-and-after benchmark results and retain an
  optimization only when it improves a measured target without semantic
  regressions.

## Phase 9 — Add comptime compilation

**Outcome:** comptime compilation produces the same logical compiled format
consumed by the runtime renderer.

- [ ] **ZEP-075** Identify Zig compile-time restrictions that affect parsing,
  analysis, lowering, optimization, and finalization.
- [ ] **ZEP-076** Implement a comptime entry point for embedded template source
  using the shared compiler architecture.
- [ ] **ZEP-077** Verify runtime-compiled and comptime-compiled templates have
  equivalent output, escaping, control flow, and diagnostics for shared
  fixtures.
- [ ] **ZEP-078** Document comptime limitations and keep them separate from the
  runtime `compile()` contract.

## Completion policy

Implement phases in order. A later phase may begin only when the preceding
phase's outcome and verification items are complete. Phase 1 is the first
usable product slice; later phases add breadth and optimization without
changing its compile-once/render-many contract. Update the architecture
documents whenever implementation reveals a required change to a normative
contract; make that change explicit before coding against it.
