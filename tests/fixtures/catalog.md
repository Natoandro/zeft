# Fixture catalog

This catalog is the coverage target for the complete suite. `Enabled` means an
executable golden fixture currently runs from `tests/integration.zig`.
`Defined` means the behavior and expected result are specified here, but its
fixture is disabled until the implementation exists. For features whose
template syntax or API is still open in the implementation plan, the scenario
is recorded without inventing a syntax or an expected byte sequence.

Run one golden case for every row when its implementation is enabled. Keep
compiler-internal checks (IR shape, symbol numbering, source spans, allocation
ownership) in unit tests because their assertions are not rendered output.

## Markup and serialization

| ID | Status | Fixture or scenario | Expected result |
| --- | --- | --- | --- |
| M-001 | Enabled | `html/static.tmpl` | Nested HTML serializes exactly; source spelling, static attributes, and final newline are retained. |
| M-002 | Enabled | `html/static.tmpl` | `\{{` emits `{{`; `\\` emits one backslash; comment contents remain literal. |
| M-003 | Enabled | `html/static.tmpl` | Mixed-case void tags preserve their original opening tags and get no end tag. |
| M-004 | Enabled | `html/static.tmpl` | HTML5 doctype casing and whitespace are preserved. |
| M-005 | Existing test | `tests/integration.zig` static-attribute case | Bare boolean attributes and quoted boolean-looking values remain distinct and exact. |
| M-006 | Defined | HTML void-element table from the architecture, in `<tag>` and `<tag/>` forms | Every listed void element is accepted and preserved; children/end tags and non-void self-closing tags fail. |
| M-007 | Existing tests | Parser unit cases | Comments preserve bytes; unterminated comments and unsupported declarations fail as invalid markup. |
| M-008 | Existing tests | Parser unit cases | Nested elements, mixed content, source spelling, and malformed tag spans are checked. |
| M-009 | Existing tests | Parser unit cases | XML name case sensitivity, quoted attributes, and empty-element spelling are checked. |
| M-010 | Enabled | `xml/fragment.tmpl` | XML declaration, empty child, CDATA, and dynamic XML text/attribute escaping render exactly. |
| M-011 | Existing tests | Parser unit cases | XML entity references are retained; invalid references, raw `<`, `]]>`, malformed comments, declarations, and CDATA fail. |
| M-012 | Defined | HTML attribute interpolation with both quote styles and multiple dynamic/static segments | Escape `&<>"'` in either attribute quote style; preserve all surrounding source bytes. |
| M-013 | Defined | XML fragment with multiple top-level text, comments, and elements | Render a fragment without imposing one-document-element validation. |

## Expressions and values

| ID | Status | Fixture or scenario | Expected result |
| --- | --- | --- | --- |
| E-001 | Enabled | `html/dynamic.tmpl` | HTML text and attribute contexts escape the same value according to their distinct rules. |
| E-002 | Enabled | `html/expressions.tmpl` | Nested property/index access, precedence, short-circuiting, filters, and escaping compose in one render. |
| E-003 | Existing test | `tests/integration.zig` expression cases | Integer arithmetic, grouping, boolean literal, string newline escape, unary not, precedence, and logical short-circuit behavior. |
| E-004 | Existing tests | `tests/integration.zig` access cases | Struct fields, arrays/slices, property chains, zero-based indexes, missing properties, and out-of-range indexes. |
| E-005 | Existing test | Built-in callable case | `length` for strings/sequences; `upper`, `lower`, `trim`, and `default` behavior. |
| E-006 | Existing test | Registered callable cases | Render-local registrations, built-in override, scratch allocation, callback failures, and source spans. |
| E-007 | Defined | Expression table for every binary operator and precedence boundary | Verify `||`, `&&`, equality, comparisons, additive, and multiplicative precedence; all binary operators associate left-to-right. |
| E-008 | Defined | Expression table for numeric syntax and string escapes | Accept specified decimal/exponent forms and six escapes; reject unknown escapes, unescaped line breaks, and malformed numbers. `null`, `true`, and `false` are reserved case-sensitively; other case spellings remain identifiers. |
| E-009 | Defined | Function/filter syntax table: no args, multiple args, nested calls, filter arguments and pipelines | Parse zero or more arguments; execute left-to-right pipelines; report callable arity/type errors at call sites. |
| E-010 | Defined | Expression output matrix for HTML/XML text/attributes | Test `&`, `<`, `>`, `"`, and `'` for each output context and format. |
| E-011 | Defined | Root names repeated and in different case | Repeated case-sensitive roots reuse symbols; distinct names resolve independently and missing roots fail by default. |
| E-012 | Defined | Dynamic values across null, bool, number, string, sequence, and object adapters | Verify supported value rendering, property lookup, indexing, and invalid operation categories. |

## Compile diagnostics

| ID | Status | Fixture or scenario | Expected result |
| --- | --- | --- | --- |
| C-001 | Existing tests | `tests/integration.zig` and parser unit cases | Unterminated interpolation and malformed HTML/XML return categorized diagnostics before render. |
| C-002 | Existing tests | Parser unit cases | Mismatched/unmatched end tags point to the full end tag; malformed tags point from `<` through `>` or EOF; unclosed elements point to the opening tag. |
| C-003 | Defined | Invalid-expression table for each literal, selector, operator, call, and delimiter rule | Return invalid-expression/syntax category and half-open source span for the invalid token. |
| C-004 | Defined | Invalid-markup table for HTML declarations, XML declarations/entities/comments/CDATA, and attributes | Return invalid-markup category and prescribed markup token span. |
| C-005 | Enabled | Control-flow integration diagnostics | Unknown directive and invalid nesting return categorized diagnostics at source spans. |

## Control flow and scopes

The scenarios below use the syntax specified by ZEP-038: `{% if expression %}`,
`{% else %}`, `{% endif %}`, `{% for name in expression %}`, `{% endfor %}`,
`{% break %}`, and `{% continue %}`.

| ID | Status | Scenario | Expected result |
| --- | --- | --- | --- |
| F-001 | Enabled | Control-flow fixture and focused cases | True/false conditions emit only the selected branch. |
| F-002 | Enabled | Control-flow fixture and focused cases | Alternate branch and nested conditions preserve document order. |
| F-003 | Enabled | Control-flow integration cases | Empty loops emit nothing; non-empty loops emit once per item. |
| F-004 | Enabled | `html/control-flow.tmpl` | Loop local resolves before root context and expires after its body. |
| F-005 | Enabled | Control-flow integration cases | Nested loops keep independent iteration state and bindings. |
| F-006 | Enabled | Control-flow integration cases | Inner loop shadows outer name; outer binding is visible again afterward. |
| F-007 | Enabled | `html/control-flow.tmpl` | Root variable with the loop binding's name is visible before and after the loop. |
| F-008 | Enabled | Control-flow integration cases | Non-sequence input returns `non_iterable` at the loop expression span. |
| F-009 | Enabled | Control-flow integration cases | `continue`/`break` target innermost loop; reject invalid placement. |
| F-010 | Enabled | Control-flow fixture and focused cases | Branch/loop combinations keep explicit destinations and local scopes. |
| F-011 | Enabled | Control-flow integration cases | Repeated renders keep state isolated; compiled template remains immutable. |

## Whitespace policies

The whitespace golden fixtures exercise preserve, compact, and pretty output
for both HTML and XML. Compact golden files omit a final newline where
element-only document formatting whitespace is removed.

| ID | Status | Scenario | Expected result |
| --- | --- | --- | --- |
| W-001 | Enabled | `html/whitespace.tmpl` preserve output | Preserve source whitespace exactly. |
| W-002 | Enabled | `html/whitespace-compact.out` and `xml/whitespace-compact.out` | Remove formatting whitespace in element-only content and collapse ordinary text runs. |
| W-003 | Enabled | `html/whitespace-pretty.out` and `xml/whitespace-pretty.out` | Format nested element-only content with two-space indentation; mixed content stays inline. |
| W-004 | Enabled | `html/whitespace.tmpl` in all modes | Preserve whitespace in `pre`, `textarea`, `script`, and `style`. |
| W-005 | Enabled | HTML whitespace fixture and dynamic boundary integration case | Retain form text and meaningful inline boundaries. |
| W-006 | Enabled | `html/whitespace-dynamic.tmpl` golden outputs and pretty loop integration cases | Preserve inline boundaries for empty/repeated output and indent loop-generated elements. |
| W-007 | Enabled | All whitespace golden cases and configurable-indentation case | Outputs distinguish policies and custom indentation is used in pretty mode. |

## Runtime errors and lifecycle

| ID | Status | Scenario | Expected result |
| --- | --- | --- | --- |
| R-001 | Existing tests | Invalid property/index access, invalid operand, and local selector spans | Return the correct runtime category and originating selector/operator span. |
| R-002 | Existing tests | Unknown/failing filters and functions | Return filter/function failure at the call site. |
| R-003 | Existing tests | Missing root variable | Return `missing_variable` by default at the identifier span; source before the expression does not shift the reported span. |
| R-004 | Existing tests | Writer that fails during static and dynamic writes | Propagate the original Zig writer error without converting it to a template diagnostic. |
| R-005 | Existing tests | Compile with tracked allocator, render, deinitialize | Temporary compile allocations are released; persistent data lives until deinit and is released once. |
| R-006 | Existing tests | Reuse one template sequentially and concurrently across branches, loops, and registered callbacks | Each render owns its program counter, scopes, loop state, and scratch arena; output does not cross-contaminate. |
| R-007 | Existing tests | Callable returns scratch-allocated bytes | Result remains valid through render output; all render allocations are released when the call ends. |
| R-008 | Existing test | `tests/integration.zig` source-lifetime case | Free source immediately after compile, then render; compiled template has no dependency on source or temporary AST storage. |

## Cache, includes, optimization, and comptime

| ID | Status | Scenario | Expected result |
| --- | --- | --- | --- |
| K-001 | Enabled | Same identity/source/options requested twice | Second request hits the explicit cache and returns equivalent compiled behavior. |
| K-002 | Enabled | Same source with different format or whitespace options | Entries do not alias when output-affecting options differ. |
| K-003 | Enabled | Same identity with changed source | Successful reload replaces the entry and next render sees new output. |
| K-004 | Enabled | Changed source fails compilation | Last valid cached template remains available. |
| K-005 | Enabled | Parent includes child, then child changes | Next parent render resolves the independently compiled current child without recompiling parent static content. |
| K-006 | Enabled | Missing/invalid child and include cycle | Return explicit errors with dependency context; never substitute stale child content. |
| K-007 | Enabled | Evict/replace while render is active | Active render keeps its compiled entry alive until completion. |
| K-008 | Enabled | Concurrent cache lookup and rendering | Cache publication and reference accounting remain safe across concurrent callers. |
| O-001 | Enabled unit tests | `src/compiler/optimize.zig` optimizer cases | Constant folding preserves spans; empty writes and unreachable branches are removed; jump targets remain valid. |
| O-002 | Enabled unit tests | `src/zeft.zig` finalization case | Repeated strings and symbol names share finalized storage while preserving output. |
| B-001 | Enabled benchmark | `bench/main.zig` small, large, dynamic, and control-flow cases | `zig build -Doptimize=ReleaseFast bench` reports compile/render time, allocator activity, write calls, and compiled size without thresholds. |
| T-001 | Pending comptime | Same supported fixture compiled at runtime and comptime | Produce equivalent logical program and identical rendered bytes. |
| T-002 | Pending comptime | Diagnostics for shared invalid fixtures | Runtime/comptime entry points report equivalent categories and spans where supported. |

Comptime cases remain pending until their API is defined.
