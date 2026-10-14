# Runtime

This document defines execution invariants. Expression, output, and whitespace
semantics belong in [Template language](language.md); public lifetimes and
diagnostics belong in [Public API](public-api.md).

## Execution

Rendering executes the immutable compiled representation against a root context
and writer. It MUST NOT parse markup, template directives, or expression source.
Static output is written directly, while dynamic output uses the escape context
chosen during compilation.

A compiled template is reusable and safe for concurrent rendering. Each render
owns all mutable execution state, including its instruction position, lexical
bindings, loop iterators, include stack, and scratch allocations. Rendering
MUST NOT mutate the compiled template.

The current implementation interprets linear render and expression IR. The
choice of interpreter, instruction names, and physical program representation
is not a public ABI.

## Values and native adaptation

The runtime value model represents null, booleans, signed 64-bit integers,
`f64` numbers, strings, sequences, objects, and the format-tagged trusted
values specified by the language contract. Integer arithmetic preserves exact
values and reports overflow as `invalid_operand`; mixed operations and
comparisons follow the language contract. Native Zig adaptation follows the
public API contract.

Property lookup is case-sensitive. Sequence indexing is zero-based. Missing
properties and out-of-range indexes return `invalid_property_access` at the
selector span. Lexical bindings resolve before root names and disappear when
their scope exits.

## Expressions and callbacks

Expressions execute from the compiled representation and preserve source order
except where short-circuiting or semantics-preserving optimization explicitly
skips evaluation. Callable arguments are evaluated before invocation.

Callables resolve from render-local registrations followed by built-ins.
Direct calls and pipes use the same namespace. Registrations and callback user
data are never retained by a compiled template. Callback results remain valid
until consumed during that render. Scratch-backed results MUST NOT escape the
render call.

## Includes

An include asks the render's resolver for the exact compiled identity. The
resolver supplies a retained immutable child; rendering releases it after use.
Children receive the current root context and render options. Each include is
resolved when executed so reloads can become visible without recompiling a
parent.

The render tracks active identities and rejects recursive inclusion with
`include_cycle`. Missing roots, missing children, and child compilation
failures use their distinct diagnostic categories and preserve the ordered
dependency stack.

## Errors and streaming output

Template failures return render diagnostics. Underlying writer errors propagate
unchanged. Rendering is streaming: any bytes written before a template,
callback, allocator, resolver, or writer failure remain written. Zeft does not
buffer or roll back output unless a caller supplies such a writer.

Missing variables fail by default. Invalid conditions, operands, selectors,
iterables, trusted-output contexts, and callable invocations use stable render
categories with the originating source span.

## Allocation and concurrency

Persistent compiled data remains valid until deinitialization. Render scratch
storage is released on success, template failure, or propagated Zig error.
The common render path SHOULD avoid allocation where practical, but allocation
strategy is not part of template semantics.

Concurrent renders use independent writers and mutable state. Any shared
context, allocator, resolver, registration, callback data, or writer must be
safe for the caller's concurrency. Template deinitialization MUST NOT race with
an active render.
