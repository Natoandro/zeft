# Compilation

This document defines the compiler boundary and the properties required of a
compiled template. Language behavior belongs in [Template language](language.md)
and public ownership and result behavior belongs in [Public API](public-api.md).

## Compiler boundary

Runtime compilation accepts source bytes, an allocator, and explicit compile
options. It MUST be deterministic for the same source, options, and compiler
version. It MUST NOT read files, resolve includes, or consult global state.

Compilation MUST parse markup and template syntax structurally, validate every
error decidable from source, determine each interpolation's output context, and
produce an immutable representation that can render without reparsing source.
Temporary compiler data MUST NOT be retained by the compiled template.

The current implementation uses parsing, analysis, lowering, optimization, and
finalization stages with separate render and expression IR. Those stages and
the physical IR are implementation design, not public ABI. They may change as
long as the observable contracts remain satisfied.

## Compiled representation

A compiled template MUST own or otherwise retain every byte and metadata item
needed for rendering. It MUST NOT borrow the template source, compile-option
slices, temporary syntax trees, or temporary optimization storage.

The representation MUST contain enough information to:

- write static output without reconstructing markup;
- evaluate compiled expressions without reading expression source;
- execute branches, loops, loop control, and includes;
- distinguish HTML/XML text and attribute escape contexts;
- resolve root symbols and lexical bindings;
- report runtime failures at their original source location.

The compiled representation is immutable. Its exact instruction set, symbol
numbering, storage layout, string sharing, and optimization strategy are
implementation details.

## Optimization

Optimizations MUST preserve output, evaluation order, short-circuit behavior,
error categories, and source locations. An optimization MUST NOT evaluate a
callback, resolve an include, or turn a skipped runtime failure into an eager
failure.

The implementation SHOULD eliminate unnecessary work and share repeated
immutable data where measurements justify it. Specific passes are not
architectural requirements.

## Options and cache identity

Compile options include output format and whitespace policy. Pretty formatting
also accepts indentation bytes. Every option that changes syntax, semantics,
diagnostics, or output MUST participate in cache matching. The compiled
template owns any option bytes it needs after compilation.

Runtime and optional comptime compilation MUST produce the same logical
compiled contract. Equivalent supported inputs MUST render identically and
report equivalent template categories and source spans.

## Source information

Source spans are half-open byte ranges in the original source. Compilation
MUST retain enough mapping for runtime diagnostics without retaining the source
itself. A caller-supplied source identity, when present, MUST be carried into
diagnostics.

Malformed markup spans cover the relevant complete token when possible, or
from its opening delimiter through end of source when unterminated. Expression
and runtime failures identify the smallest relevant expression, selector,
operator, call, or directive.

## Performance workflow

Performance work is measurement driven. The standalone benchmark is
`zig build -Doptimize=ReleaseFast bench`; measurement methods and results
belong in `docs/design/benchmark-results.md`. Benchmark numbers and current
optimizer internals are not normative behavior.
