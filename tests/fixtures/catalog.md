# Fixture catalog

This catalog is the coverage target for the complete suite. Status describes
active coverage, not feature implementation or completion of every boundary
case. See [README.md](README.md) for status definitions and fixture layout.

The coverage audit below maps every stable ID to its current executable owner
and the remaining public-API coverage work. Multiple rows may share a fixture;
one row is not necessarily one execution. Internal IR, symbol numbering, and
allocation assertions remain in focused tests.

## Verified expansion batches

- **ZEP-076:** `tests/e2e_markup.zig` registers MK-001–MK-072: 51 exact
  output cases and 21 compile diagnostic cases. Covers M-001–M-013 and
  E-001/E-010, including every HTML void opening form, all escaping contexts,
  XML fragments, declarations, entities, and literal comments/CDATA.

- **ZEP-078/079:** `tests/e2e_control_flow.zig` and `tests/e2e_whitespace.zig`
  register 57 named executions: 16 control-flow goldens, two runtime errors,
  one compiled-template reuse/recovery harness, and 38 whitespace goldens.
  Covers F-001–F-010 and W-001–W-007; synchronized reuse is in ZEP-082.

## Markup and serialization

| ID | Status | Fixture or scenario | Expected result |
| --- | --- | --- | --- |
| M-001 | Fixture | `html/static.tmpl` | Nested HTML serializes exactly; source spelling, static attributes, and final newline are retained. |
| M-002 | Fixture | `html/static.tmpl` | `\{{` emits `{{`; `\\` emits one backslash; comment contents remain literal. |
| M-003 | Fixture | `html/static.tmpl` | Mixed-case void tags preserve their original opening tags and get no end tag. |
| M-004 | Fixture | `html/static.tmpl` | HTML5 doctype casing and whitespace are preserved. |
| M-005 | Fixture | `tests/integration.zig` static-attribute case | Bare boolean attributes and quoted boolean-looking values remain distinct and exact. |
| M-006 | Fixture | HTML void-element table from the architecture, in `<tag>` and `<tag/>` forms | Every listed void element is accepted and preserved; children/end tags and non-void self-closing tags fail. |
| M-007 | Fixture | Parser unit cases | Comments preserve bytes; unterminated comments and unsupported declarations fail as invalid markup. |
| M-008 | Fixture | Parser unit cases | Nested elements, mixed content, source spelling, and malformed tag spans are checked. |
| M-009 | Fixture | Parser unit cases | XML name case sensitivity, quoted attributes, and empty-element spelling are checked. |
| M-010 | Fixture | `xml/fragment.tmpl` | XML declaration, empty child, CDATA, and dynamic XML text/attribute escaping render exactly. |
| M-011 | Fixture | Parser unit cases | XML entity references are retained; invalid references, raw `<`, `]]>`, malformed comments, declarations, and CDATA fail. |
| M-012 | Fixture | HTML attribute interpolation with both quote styles and multiple dynamic/static segments | Escape `&<>"'` in either attribute quote style; preserve all surrounding source bytes. |
| M-013 | Fixture | XML fragment with multiple top-level text, comments, and elements | Render a fragment without imposing one-document-element validation. |

## Expressions and values

| ID | Status | Fixture or scenario | Expected result |
| --- | --- | --- | --- |
| E-001 | Fixture | `html/dynamic.tmpl` | HTML text and attribute contexts escape the same value according to their distinct rules. |
| E-002 | Fixture | `html/expressions.tmpl` | Nested property/index access, precedence, short-circuiting, filters, and escaping compose in one render. |
| E-003 | Focused | `tests/integration.zig` expression cases | Integer arithmetic, grouping, boolean literal, string newline escape, unary not, precedence, and logical short-circuit behavior. |
| E-004 | Focused | `tests/integration.zig` access cases | Struct fields, arrays/slices, property chains, zero-based indexes, missing properties, and out-of-range indexes. |
| E-005 | Focused | Built-in callable case | `length` for strings/sequences; `upper`, `lower`, `trim`, and `default` behavior. |
| E-006 | Focused | Registered callable cases | Render-local registrations, built-in override, scratch allocation, callback failures, and source spans. |
| E-007 | Focused | Expression table for every binary operator and precedence boundary | Verify `||`, `&&`, equality, comparisons, additive, and multiplicative precedence; all binary operators associate left-to-right. |
| E-008 | Focused | Expression table for numeric syntax and string escapes | Accept specified decimal/exponent forms and six escapes; reject unknown escapes, unescaped line breaks, and malformed numbers. `null`, `true`, and `false` are reserved case-sensitively; other case spellings remain identifiers. |
| E-009 | Focused | Function/filter syntax table: no args, multiple args, nested calls, filter arguments and pipelines | Parse zero or more arguments; execute left-to-right pipelines; report callable arity/type errors at call sites. |
| E-010 | Fixture | Expression output matrix for HTML/XML text/attributes | Test `&`, `<`, `>`, `"`, and `'` for each output context and format. |
| E-011 | Focused | Root names repeated and in different case | Repeated case-sensitive roots reuse symbols; distinct names resolve independently and missing roots fail by default. |
| E-012 | Focused | Dynamic values across null, bool, number, string, sequence, and object adapters | Verify supported value rendering, property lookup, indexing, and invalid operation categories. |

## Compile diagnostics

| ID | Status | Fixture or scenario | Expected result |
| --- | --- | --- | --- |
| C-001 | Focused | `tests/integration.zig` and parser unit cases | Unterminated interpolation and malformed HTML/XML return categorized diagnostics before render. |
| C-002 | Focused | Parser unit cases | Mismatched/unmatched end tags point to the full end tag; malformed tags point from `<` through `>` or EOF; unclosed elements point to the opening tag. |
| C-003 | Focused | Invalid-expression table for each literal, selector, operator, call, and delimiter rule | Return invalid-expression/syntax category and half-open source span for the invalid token. |
| C-004 | Focused | Invalid-markup table for HTML declarations, XML declarations/entities/comments/CDATA, and attributes | Return invalid-markup category and prescribed markup token span. |
| C-005 | Focused | Control-flow integration diagnostics | Unknown directive and invalid nesting return categorized diagnostics at source spans. |

## Control flow and scopes

The scenarios below use the syntax specified by ZEP-038: `{% if expression %}`,
`{% else %}`, `{% endif %}`, `{% for name in expression %}`, `{% endfor %}`,
`{% break %}`, and `{% continue %}`.

| ID | Status | Scenario | Expected result |
| --- | --- | --- | --- |
| F-001 | Fixture | Control-flow fixture and focused cases | True/false conditions emit only the selected branch. |
| F-002 | Fixture | Control-flow fixture and focused cases | Alternate branch and nested conditions preserve document order. |
| F-003 | Fixture | Control-flow integration cases | Empty loops emit nothing; non-empty loops emit once per item. |
| F-004 | Fixture | `html/control-flow.tmpl` | Loop local resolves before root context and expires after its body. |
| F-005 | Fixture | Control-flow integration cases | Nested loops keep independent iteration state and bindings. |
| F-006 | Fixture | Control-flow integration cases | Inner loop shadows outer name; outer binding is visible again afterward. |
| F-007 | Fixture | `html/control-flow.tmpl` | Root variable with the loop binding's name is visible before and after the loop. |
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
| W-001 | Fixture | `html/whitespace.tmpl` preserve output | Preserve source whitespace exactly. |
| W-002 | Fixture | `html/whitespace-compact.out` and `xml/whitespace-compact.out` | Remove formatting whitespace in element-only content and collapse ordinary text runs. |
| W-003 | Fixture | `html/whitespace-pretty.out` and `xml/whitespace-pretty.out` | Format nested element-only content with two-space indentation; mixed content stays inline. |
| W-004 | Fixture | `html/whitespace.tmpl` in all modes | Preserve whitespace in `pre`, `textarea`, `script`, and `style`. |
| W-005 | Fixture | HTML whitespace fixture and dynamic boundary integration case | Retain form text and meaningful inline boundaries. |
| W-006 | Fixture | `html/whitespace-dynamic.tmpl` golden outputs and pretty loop integration cases | Preserve inline boundaries for empty/repeated output and indent loop-generated elements. |
| W-007 | Fixture | All whitespace golden cases and configurable-indentation case | Outputs distinguish policies and custom indentation is used in pretty mode. |

## Runtime errors and lifecycle

| ID | Status | Scenario | Expected result |
| --- | --- | --- | --- |
| R-001 | Focused | Invalid property/index access, invalid operand, and local selector spans | Return the correct runtime category and originating selector/operator span. |
| R-002 | Focused | Unknown/failing filters and functions | Return filter/function failure at the call site. |
| R-003 | Focused | Missing root variable | Return `missing_variable` by default at the identifier span; source before the expression does not shift the reported span. |
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

Comptime cases remain pending until their API is defined.

## Executable coverage audit (ZEP-074)

Owners use exact searchable test titles with these file prefixes: **I** =
`tests/integration.zig`, **U** = `tests/unit.zig`, **Z** = `src/zeft.zig`,
**X** = `src/compiler/expression.zig`, **A** = `src/compiler/analysis.zig`.
**G** denotes an embedded `.tmpl`/`.out` pair under `tests/fixtures/`;
whitespace pairs name the output policy. Golden owners run in
`enabled golden fixtures compile and render byte-for-byte`, except the dynamic
whitespace pairs, which run in
`whitespace policies retain dynamic boundaries across empty and repeated loop output`.

Requirement ownership follows the catalog sections: markup, expressions,
compile diagnostics, control flow, and whitespace map to the corresponding
sections of `docs/architecture/compilation.md`; values, escaping, runtime
errors, and render isolation map to `docs/architecture/runtime.md`; cache,
includes, ownership, and comptime map to
`docs/architecture/caching-and-ownership.md`. Optimization and benchmarks map
to Compilation / Compiler pipeline and Optimization and serialization.

This audit records coverage at the start of the expansion. An active owner
means its assertions exist; it does not claim that each remaining scenario has
been verified. Update the owner and gap columns as each expansion is reviewed
and passes verification. Future syntax/API cases stay pending.

| ID | Current executable owner | Concrete remaining coverage / owning task |
| --- | --- | --- |
| M-001 | G html/static | ZEP-076: expand independent markup boundaries. |
| M-002 | G html/static; U lexer tracks raw spans and decodes text delimiter escapes | ZEP-076: left-to-right escape combinations and ordinary backslashes through compile/render. |
| M-003 | G html/static; I HTML void elements preserve their opening spelling without closing tags | ZEP-076: all fourteen tags in both forms and mixed case. |
| M-004 | G html/static; U parser represents comments and the HTML doctype as static markup | ZEP-076: casing/whitespace variants through public compile/render. |
| M-005 | I static attributes are preserved exactly during compilation and rendering | ZEP-076: named golden with both quote styles and source spacing. |
| M-006 | U parser recognizes HTML void elements case-insensitively and preserves their syntax; I invalid HTML self-closing syntax and void end tags fail during compilation | ZEP-076: unit table alternates opening forms; cover both forms for every tag and exact negative spans. |
| M-007 | U parser represents comments and the HTML doctype as static markup; U parser rejects unsupported declarations and unterminated comments; I HTML comments and doctype serialize verbatim without comment interpolation | ZEP-076/080: named literal-content and invalid-comment/declaration cases with exact spans. |
| M-008 | U parser preserves nested mixed markup, quoted attributes, and exact source spans; U malformed markup diagnostics point to the relevant source token; I HTML and XML markup is serialized before runtime execution | ZEP-076/080: golden mixed-content variants and public diagnostic span tables. |
| M-009 | U XML parsing preserves declarations and CDATA and applies XML element rules; U XML names are case-sensitive and XML attributes require quoted values | ZEP-076/080: public render variants and invalid name/attribute spans. |
| M-010 | G xml/fragment; I XML text and attributes use XML-specific escaping | ZEP-076: declaration versions/order, quote styles, CDATA literal delimiters. |
| M-011 | U XML parsing preserves declarations and CDATA and applies XML element rules; U XML names are case-sensitive and XML attributes require quoted values; U XML 1.1 accepts valid control-character references | ZEP-076/080: public positive/negative entity matrix and exact markup spans; unterminated CDATA case. |
| M-012 | I attribute interpolations retain their context and render in source order; U attribute values preserve static and interpolated segments in source order | ZEP-076: both quote styles, all five characters, multiple segments in HTML/XML. |
| M-013 | No dedicated multiple-top-level fragment execution | ZEP-076: named XML fragment with top-level text, comment, and multiple elements. |
| E-001 | G html/dynamic | ZEP-076: full escape matrix. |
| E-002 | G html/expressions | ZEP-077: independent cases with dynamic operands. |
| E-003 | I expression operators honor precedence and render literals; I logical operators short circuit missing property access | ZEP-077: complete operator/precedence/associativity matrix. |
| E-004 | I property and literal array-index expressions traverse native context values; I missing properties and out-of-range literal indexes report access spans | ZEP-077: dynamic indexes, case sensitivity, selector type boundaries. |
| E-005 | I built-in functions and filters evaluate through expression IR | ZEP-077: empty/nonempty strings/sequences, arity/type failures and ASCII boundaries. |
| E-006 | I registered functions and filters override built-ins and receive scratch allocation; I callable failures and invalid operands retain originating source spans | ZEP-077: registration case sensitivity, user data, isolation, nested/multiple arguments. |
| E-007 | I expression operators honor precedence and render literals; X expression parser handles literals, precedence, grouping and accesses | ZEP-077: every operator and adjacent boundary with unfurled context operands. |
| E-008 | X expression parser handles literals, precedence, grouping and accesses; X expression parser rejects malformed literals and operators; I expression operators honor precedence and render literals | ZEP-077/080: numeric syntax, all six escapes, reserved-name case matrix, exact invalid spans. |
| E-009 | I built-in functions and filters evaluate through expression IR; I registered functions and filters override built-ins and receive scratch allocation | ZEP-077/080: zero/multiple args, nested calls, pipelines and arity/type call-site spans. |
| E-010 | G html/dynamic; G xml/fragment; I attribute interpolations retain their context and render in source order | ZEP-076: all five characters in both formats, text and both attribute quote styles. |
| E-011 | A assigns first-occurrence root symbol IDs and HTML text context; I missing roots and local selectors report their own expression spans | ZEP-077: public repeated roots and case-distinct roots; retain symbol-ID unit assertion. |
| E-012 | I expression operators honor precedence and render literals; I property and literal array-index expressions traverse native context values | ZEP-077: native null/bool/numeric/string/array/slice/object adapters and invalid operations. |
| C-001 | I compile syntax failures are returned before execution; U parser rejects malformed delimiters and unbalanced elements with spans | ZEP-080: complete named public compile-failure table. |
| C-002 | U malformed markup diagnostics point to the relevant source token; U parser rejects malformed delimiters and unbalanced elements with spans | ZEP-080: public compiler spans, EOF boundaries, multibyte prefix. |
| C-003 | X expression parser rejects malformed literals and operators | ZEP-080: public literal/selector/operator/call/delimiter table with exact category/span. |
| C-004 | U parser rejects unsupported declarations and unterminated comments; U XML names are case-sensitive and XML attributes require quoted values; U malformed markup diagnostics point to the relevant source token | ZEP-080: public HTML/XML invalid-markup table with exact spans. |
| C-005 | I control-flow compile and runtime diagnostics identify invalid constructs | ZEP-080: named directive table, duplicate/unterminated/mismatched cases and byte offsets. |
| F-001 | G html/control-flow; I conditionals support false branches and loops handle empty sequences | ZEP-078: independently named true/false contexts. |
| F-002 | G html/control-flow; I nested conditionals select one branch | ZEP-078: nested branch combinations and document order. |
| F-003 | I conditionals support false branches and loops handle empty sequences | ZEP-078: explicit empty/single/multiple loop goldens. |
| F-004 | G html/control-flow; I nested loops shadow and restore bindings; break and continue target innermost loop | ZEP-078: local value selectors and scope exits. |
| F-005 | I nested loops shadow and restore bindings; break and continue target innermost loop | ZEP-078: differing outer/inner lengths and empty nested loops. |
| F-006 | I nested loops shadow and restore bindings; break and continue target innermost loop | ZEP-078: named shadow/restoration golden. |
| F-007 | G html/control-flow | ZEP-078: root restoration across break, empty loop, and nested shadowing. |
| F-008 | I control-flow compile and runtime diagnostics identify invalid constructs | ZEP-078/080: multiple non-sequence value kinds and exact spans. |
| F-009 | I nested loops shadow and restore bindings; break and continue target innermost loop; I control-flow compile and runtime diagnostics identify invalid constructs | ZEP-078/080: controls inside nested branches and invalid nesting table. |
| F-010 | G html/control-flow; I nested loops shadow and restore bindings; break and continue target innermost loop | ZEP-078: branch/loop combinations and selector scopes. |
| F-011 | I one control-flow template can render concurrently with isolated state; I conditional runtime errors point to condition expressions and renders reset loop state | ZEP-078/082: failed render followed by successful render and synchronized overlap. |
| W-001 | G html/whitespace preserve; G xml/whitespace preserve | ZEP-079: leading/trailing spaces, tabs and final-newline boundaries. |
| W-002 | G html/whitespace compact; G xml/whitespace compact | ZEP-079: independent mixed/element-only/dynamic boundaries. |
| W-003 | G html/whitespace pretty; G xml/whitespace pretty; I pretty mode keeps descendants of mixed content inline | ZEP-079: generated siblings, empty branches and final newlines. |
| W-004 | G html/whitespace in three policies | ZEP-079: independent cases for each sensitive element and XML contrast. |
| W-005 | G html/whitespace; I whitespace policies retain dynamic boundaries across empty and repeated loop output | ZEP-079: meaningful form/inline boundaries across both formats and all policies. |
| W-006 | G html/whitespace-dynamic in three policies; I pretty mode indents element output generated by loops | ZEP-079: empty dynamic values, branch/loop siblings in HTML/XML. |
| W-007 | G whitespace fixtures; I pretty whitespace uses caller configured indentation; I pretty mode formats structural conditional branches and respects format specific sensitive names | ZEP-079: custom indentation in both formats and full policy distinctions. |
| R-001 | I missing properties and out-of-range literal indexes report access spans; I missing roots and local selectors report their own expression spans; I callable failures and invalid operands retain originating source spans | ZEP-080: selector/operand/condition type boundaries and multibyte prefixes. |
| R-002 | I callable failures and invalid operands retain originating source spans | ZEP-077/080: unknown names, bad arity/types, explicit callback failures. |
| R-003 | I missing roots and local selectors report their own expression spans; Z render reports missing identifiers with their source span | ZEP-080: multibyte source prefix and case-distinct missing roots. |
| R-004 | Z writer errors propagate unchanged for static and dynamic writes; Z writer failures propagate from render | ZEP-082: fixture-backed writer errors including includes and cleanup. |
| R-005 | Z compile temporary storage is released and finalized storage lasts until deinit | ZEP-082: fixture-backed lifecycle and source/options storage ownership. |
| R-006 | I concurrent renders keep branch, loop, and callback scratch state isolated; I one control-flow template can render concurrently with isolated state | ZEP-082: deterministic synchronized overlap and fixture-backed variants. |
| R-007 | I render scratch allocations are released after callback output; I registered functions and filters override built-ins and receive scratch allocation | ZEP-082: scratch cleanup on template and writer failures. |
| R-008 | I finalized access expressions do not retain the template source; Z compiled template owns finalized storage and renders after source release | ZEP-082: fixture-backed source and indentation release. |
| K-001 | U template cache reuses entries and keys source and compile options | ZEP-081: fixture-backed hits and distinct identities. |
| K-002 | U template cache reuses entries and keys source and compile options | ZEP-081: all options including indentation and exact identity/source bytes. |
| K-003 | U template cache reuses entries and keys source and compile options; U cache renders independently compiled includes and reports include errors | ZEP-081: named reload output/version scenario. |
| K-004 | U failed cache reload preserves the previous valid template | ZEP-081: fixture-backed exact failed compile category/span and retained output. |
| K-005 | U cache renders independently compiled includes and reports include errors | ZEP-081: nested/repeated includes and changed child with retained parent. |
| K-006 | U missing and invalid included templates identify the dependency edge; U include cycles return a runtime diagnostic with the include span; U cache include diagnostics survive entry eviction | ZEP-081: named missing-root/child, failed-child, cycles, dependency context and retained diagnostic bytes. |
| K-007 | U replacement keeps a template alive during an active render; U a replaced cache entry stays alive through its active lease | ZEP-081/082: eviction as well as replacement during active render. |
| K-008 | U template cache supports concurrent lookup and rendering | ZEP-082: synchronized render/reload/evict overlap. |
| O-001 | src/compiler/optimize.zig tests | Retain focused IR/span/destination assertions; no new golden-only substitute. |
| O-002 | Z finalization interns repeated strings and symbol names | Retain focused storage-sharing assertion. |
| B-001 | bench/main.zig workloads | Benchmark execution is separate from fixture verification; no timing thresholds. |
| T-001 | No executable owner; API not defined | Pending comptime API; do not invent fixture syntax or enable. |
| T-002 | No executable owner; API not defined | Pending comptime API; do not invent diagnostic entry point or enable. |
