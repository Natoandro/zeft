# Fixture catalog

This catalog is the coverage target for the complete suite. Status describes
active coverage, not feature implementation or completion of every boundary
case. See [README.md](README.md) for status definitions and fixture layout.

The catalog maps stable IDs to executable owners and coverage targets. Multiple rows may share a fixture;
one row is not necessarily one execution. Internal IR, symbol numbering, and
allocation assertions remain in focused tests.

## Executable suites

- **ZEP-076:** `tests/fixtures/markup.zig` defines MK-001–MK-051 as exact output
  cases; `tests/e2e_markup.zig` registers MK-052–MK-072 as compile diagnostics
  using `tests/fixtures/markup.zig`. Covers M-001–M-013 and
  E-001/E-010, including every HTML void opening form, all escaping contexts,
  XML fragments, declarations, entities, and literal comments/CDATA.

- **ZEP-078/079:** `tests/e2e_control_flow.zig` and `tests/e2e_whitespace.zig`
  register 57 named executions: 16 control-flow goldens, two runtime errors,
  one compiled-template reuse/recovery harness, and 38 whitespace goldens.
  Covers F-001–F-010 and W-001–W-007; synchronized reuse is in ZEP-082.

- **ZEP-077/080/084–086/102:** `tests/e2e_expressions.zig` registers EX-001–EX-060
  and focused signed-integer behavior; `tests/e2e_diagnostics.zig` registers
  DG-001–DG-082 (47 compile failures,
  35 runtime failures). Covers expression grammar, callbacks, operators,
  selectors, invalid markup/directives, and exact error categories/spans.
  Includes computed indexes, missing call terminators, logical jump
  destinations, and empty interpolation spans.

- **ZEP-081/082:** `tests/e2e_cache.zig` has seven named cache/include scenarios;
  `tests/e2e_lifecycle.zig` has nine lifecycle/concurrency scenarios. Covers
  K-001–K-008, R-004–R-008, and F-011 with deterministic concurrent overlap.

## Markup and serialization

| ID | Status | Fixture or scenario | Expected result |
| --- | --- | --- | --- |
| M-001 | Fixture | `text.html.static.template` | Nested HTML serializes exactly; source spelling, static attributes, and final newline are retained. |
| M-002 | Fixture | `text.html.static.template` | Backslashes remain literal; interpolation can emit delimiter text; comment contents remain literal. |
| M-003 | Fixture | `text.html.static.template` | Mixed-case void tags preserve their original opening tags and get no end tag. |
| M-004 | Fixture | `text.html.static.template` | HTML5 doctype casing and whitespace are preserved. |
| M-005 | Fixture | `tests/integration.zig` static-attribute case | Bare boolean attributes and quoted boolean-looking values remain distinct and exact. |
| M-006 | Fixture | HTML void-element table from the architecture, in `<tag>` and `<tag/>` forms | Every listed void element is accepted and preserved; children/end tags and non-void self-closing tags fail. |
| M-007 | Fixture | Parser unit cases | Comments preserve bytes; unterminated comments and unsupported declarations fail as invalid markup. |
| M-008 | Fixture | Parser unit cases | Nested elements, mixed content, source spelling, and malformed tag spans are checked. |
| M-009 | Fixture | Parser unit cases | XML name case sensitivity, quoted attributes, and empty-element spelling are checked. |
| M-010 | Fixture | `text.xml.fragment.template` | XML declaration, empty child, CDATA, and dynamic XML text/attribute escaping render exactly. |
| M-011 | Fixture | Parser unit cases | XML entity references are retained; invalid references, raw `<`, `]]>`, malformed comments, declarations, and CDATA fail. |
| M-012 | Fixture | HTML attribute interpolation with both quote styles and multiple dynamic/static segments | Escape `&<>"'` in either attribute quote style; preserve all surrounding source bytes. |
| M-013 | Fixture | XML fragment with multiple top-level text, comments, and elements | Render a fragment without imposing one-document-element validation. |

## Expressions and values

| ID | Status | Fixture or scenario | Expected result |
| --- | --- | --- | --- |
| E-001 | Fixture | `text.html.dynamic.template` | HTML text and attribute contexts escape the same value according to their distinct rules. |
| E-002 | Fixture | `text.html.expressions.template` | Nested property/index access, precedence, short-circuiting, filters, and escaping compose in one render. |
| E-003 | Fixture | `tests/integration.zig` expression cases | Integer arithmetic, grouping, boolean literal, string newline escape, unary not, precedence, and logical short-circuit behavior. |
| E-004 | Fixture | `tests/integration.zig` access cases | Struct fields, arrays/slices, property chains, zero-based indexes, missing properties, and out-of-range indexes. |
| E-005 | Fixture | Built-in callable case | `length` for strings/sequences; `upper`, `lower`, `trim`, and `default` behavior. |
| E-006 | Fixture | Registered callable cases | Render-local registrations, built-in override, scratch allocation, callback failures, and source spans. |
| E-007 | Fixture | Expression table for every binary operator and precedence boundary | Verify `||`, `&&`, equality, comparisons, additive, and multiplicative precedence; all binary operators associate left-to-right. |
| E-008 | Fixture | Expression table for numeric syntax and string escapes | Accept specified decimal/exponent forms and six escapes; reject unknown escapes, unescaped line breaks, and malformed numbers. `null`, `true`, and `false` are reserved case-sensitively; other case spellings remain identifiers. |
| E-009 | Fixture | Function/filter syntax table: no args, multiple args, nested calls, filter arguments and pipelines | Parse zero or more arguments; execute left-to-right pipelines, including registered and built-in functions with the piped value first; filters take precedence over same-name functions in pipe syntax; report callable arity/type errors at call sites. |
| E-010 | Fixture | Expression output matrix for HTML/XML text/attributes | Test `&`, `<`, `>`, `"`, and `'` for each output context and format. |
| E-011 | Fixture | Root names repeated and in different case | Repeated case-sensitive roots reuse symbols; distinct names resolve independently and missing roots fail by default. |
| E-012 | Fixture | Supported native bool/string/array/slice/struct adapters; numeric/null literals and callback values | Verify supported value operations, property lookup, indexing, and invalid operation categories. Native numeric/optional fields remain unsupported. |
| E-013 | Fixture | Direct null/sequence/object interpolation, nonnull cross-type equality, division/modulo by zero | Null emits no bytes; sequences and objects fail direct interpolation; nonnull cross-type equality and division/modulo by zero return `invalid_operand`. |
| E-014 | Planned | Equality and inequality between null and every value tag | Null equals null and differs from every nonnull value; implement and enable with ZEP-095. |
| E-015 | Planned | Direct and piped calls through one registration namespace | Both forms resolve the same callable, with the piped value supplied first; implement and enable with ZEP-097. |
| E-016 | Planned | Properties and indexes following grouped expressions and calls | Postfix operations compose uniformly and retain their precedence; implement and enable with ZEP-098. |
| E-017 | Focused | `tests/e2e_expressions.zig`: signed integer render and arithmetic cases | Preserve i64 boundaries and decimal formatting, detect overflow, promote exact integral floats to i64 for mixed arithmetic, promote other mixed operations to f64, always divide as f64, and apply the same promotion rule to comparisons. |
| DG-083 | Focused | `tests/e2e_expressions.zig`: signed integer overflow case | Integer overflow returns `invalid_operand`. |

## Compile diagnostics

| ID | Status | Fixture or scenario | Expected result |
| --- | --- | --- | --- |
| C-001 | Fixture | `tests/integration.zig` and parser unit cases | Unterminated interpolation and malformed HTML/XML return categorized diagnostics before render. |
| C-002 | Fixture | Parser unit cases | Mismatched/unmatched end tags point to the full end tag; malformed tags point from `<` through `>` or EOF; unclosed elements point to the opening tag. |
| C-003 | Fixture | Invalid-expression table for each literal, selector, operator, call, and delimiter rule | Return invalid-expression/syntax category and half-open source span for the invalid token. |
| C-004 | Fixture | Invalid-markup table for HTML declarations, XML declarations/entities/comments/CDATA, and attributes | Return invalid-markup category and prescribed markup token span. |
| C-005 | Fixture | Control-flow integration diagnostics | Unknown directive and invalid nesting return categorized diagnostics at source spans. |

## Control flow and scopes

The scenarios use `{#if expression}`, `{:else if expression}`, `{:else}`,
`{/if}`, `{#for name in expression}`, `{/for}`, `{% break %}`, and
`{% continue %}`.

| ID | Status | Scenario | Expected result |
| --- | --- | --- | --- |
| F-001 | Fixture | Control-flow fixture and focused cases | True/false conditions emit only the selected branch. |
| F-002 | Fixture | Control-flow fixture and focused cases | Alternate branch and nested conditions preserve document order. |
| F-003 | Fixture | Control-flow integration cases | Empty loops emit nothing; non-empty loops emit once per item. |
| F-004 | Fixture | `text.html.control_flow.template` | Loop local resolves before root context and expires after its body. |
| F-005 | Fixture | Control-flow integration cases | Nested loops keep independent iteration state and bindings. |
| F-006 | Fixture | Control-flow integration cases | Inner loop shadows outer name; outer binding is visible again afterward. |
| F-007 | Fixture | `text.html.control_flow.template` | Root variable with the loop binding's name is visible before and after the loop. |
| F-008 | Fixture | Control-flow integration cases | Non-sequence input returns `non_iterable` at the loop expression span. |
| F-009 | Fixture | Control-flow integration cases | `continue`/`break` target innermost loop; reject invalid placement. |
| F-010 | Fixture | Control-flow fixture and focused cases | Branch/loop combinations keep explicit destinations and local scopes. |
| F-011 | Focused | Control-flow integration cases | Repeated renders keep state isolated; compiled template remains immutable. |

## Whitespace policies

The whitespace golden fixtures exercise preserve, compact, and pretty output
for both HTML and XML. Compact golden files omit a final newline where
element-only document formatting whitespace is removed.

| ID | Status | Scenario | Expected result |
| --- | --- | --- | --- |
| W-001 | Fixture | `text.html.whitespace.template` preserve output | Preserve source whitespace exactly. |
| W-002 | Fixture | `text.html.whitespace_compact.output` and `text.xml.whitespace_compact.output` | Remove formatting whitespace in element-only content and collapse ordinary text runs. |
| W-003 | Fixture | `text.html.whitespace_pretty.output` and `text.xml.whitespace_pretty.output` | Format nested element-only content with two-space indentation; mixed content stays inline. |
| W-004 | Fixture | `text.html.whitespace.template` in all modes | Preserve whitespace in `pre`, `textarea`, `script`, and `style`. |
| W-005 | Fixture | HTML whitespace fixture and dynamic boundary integration case | Retain form text and meaningful inline boundaries. |
| W-006 | Fixture | `text.html.whitespace_dynamic.template` golden outputs and pretty loop integration cases | Preserve inline boundaries for empty/repeated output and indent loop-generated elements. |
| W-007 | Fixture | All whitespace golden cases and configurable-indentation case | Outputs distinguish policies and custom indentation is used in pretty mode. |

## Runtime errors and lifecycle

| ID | Status | Scenario | Expected result |
| --- | --- | --- | --- |
| R-001 | Fixture | Invalid property/index access, invalid operand, and local selector spans | Return the correct runtime category and originating selector/operator span. |
| R-002 | Fixture | Unknown/failing filters and functions | Return filter/function failure at the call site. |
| R-003 | Fixture | Missing root variable | Return `missing_variable` by default at the identifier span; source before the expression does not shift the reported span. |
| R-004 | Focused | Writer that fails during static and dynamic writes | Propagate the original Zig writer error without converting it to a template diagnostic. |
| R-005 | Focused | Compile with tracked allocator, render, deinitialize | Temporary compile allocations are released; persistent data lives until deinit and is released once. |
| R-006 | Focused | Reuse one template sequentially and concurrently across branches, loops, and registered callbacks | Each render owns its program counter, scopes, loop state, and scratch arena; output does not cross-contaminate. |
| R-007 | Focused | Callable returns scratch-allocated bytes | Result remains valid through render output; all render allocations are released when the call ends. |
| R-008 | Focused | `tests/integration.zig` source-lifetime case | Free source immediately after compile, then render; compiled template has no dependency on source or temporary AST storage. |

## Cache, includes, optimization, and comptime

| ID | Status | Scenario | Expected result |
| --- | --- | --- | --- |
| K-001 | Focused | Same identity/source/options requested twice | Second request hits the explicit cache and returns equivalent compiled behavior. |
| K-002 | Focused | Same source with different format or whitespace options | Entries do not alias when output-affecting options differ. |
| K-003 | Focused | Same identity with changed source | Successful reload replaces the entry and next render sees new output. |
| K-004 | Focused | Changed source fails compilation | Last valid cached template remains available. |
| K-005 | Focused | Parent includes child, then child changes | Next parent render resolves the independently compiled current child without recompiling parent static content. |
| K-006 | Focused | Missing/invalid child and include cycle | Return explicit errors with dependency context; never substitute stale child content. |
| K-007 | Focused | Evict/replace while render is active | Active render keeps its compiled entry alive until completion. |
| K-008 | Focused | Concurrent cache lookup and rendering | Cache publication and reference accounting remain safe across concurrent callers. |
| O-001 | Unit | `src/compiler/optimize.zig` optimizer cases | Constant folding preserves spans; empty writes and unreachable branches are removed; jump targets remain valid. |
| O-002 | Unit | `src/zeft.zig` finalization case | Repeated strings and symbol names share finalized storage while preserving output. |
| B-001 | Benchmark | `bench/main.zig` small, large, dynamic, and control-flow cases | `zig build -Doptimize=ReleaseFast bench` reports compile/render time, allocator activity, write calls, and compiled size without thresholds. |
| T-001 | Pending | Same supported fixture compiled at runtime and comptime | Produce equivalent logical program and identical rendered bytes. |
| T-002 | Pending | Diagnostics for shared invalid fixtures | Runtime/comptime entry points report equivalent categories and spans where supported. |

Comptime cases remain pending until the API direction recorded in the
architecture is implemented and compile-failure verification is available.

## Block syntax coverage

| ID | Status | Executable owner | Expected result |
| --- | --- | --- | --- |
| F-012 | Focused | `tests/e2e_control_flow.zig`: else-if chains evaluate only conditions needed to select a branch | Select the first true condition and skip later conditions and bodies. |
| F-013 | Focused | `tests/e2e_control_flow.zig`: loop else restores enclosing bindings and skips after break continue and exhaustion | Empty sequences run else in enclosing scope; nonempty loops bypass else. Nested shadowing and outer loop controls retain their targets. |
| C-006 | Focused | `tests/e2e_control_flow.zig`: block branches and closing tokens report exact invalid placement spans | Reject invalid branches, closes, incomplete blocks, and percent-delimited block forms at exact spans. |
| M-014 | Focused | `tests/e2e_control_flow.zig`: block syntax preserves literal markup attributes and quoted closing characters | Literal attribute/comment/CDATA delimiters remain bytes; quoted braces do not terminate block expressions. Whitespace policies format all branches. |

## Value coverage boundaries

Numbers and null values are covered through specified literal and callback
operations. Native adapters currently support booleans, byte strings, structs,
arrays, and slices; numeric and optional fields are not accepted by the adapter.
Direct null interpolation and direct sequence/object interpolation are covered
by EX-060 and DG-075–DG-076. Nonnull cross-type equality and zero-divisor
arithmetic are covered by DG-077–DG-078 and DG-081–DG-082. DG-079–DG-080 record
the current null-comparison failure until ZEP-095 implements E-014. Numeric and
optional native fields remain unsupported by the adapter.

## Fixture inventory

The registered suite has 301 named executions. Fixture case arrays and their
template/output values live in `tests/fixtures/*.zig`. The integration test
binary checks that execution IDs are unique across suites. All registered cases
run in the integration test binary. LC-009 and EX-029 retain
fixed byte-array storage through root pointer/value and nested context adapters.
The executable suite mapping above identifies the current suite owners.

T-001/T-002 remain pending until
the comptime API exists. No fixture invents expectations for these cases.
