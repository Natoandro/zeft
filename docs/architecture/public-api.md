# Public API

This document defines the observable Zig API contract. Exact declarations may
evolve, but result categories, ownership, and lifetime behavior are normative.

## Compilation and rendering

Runtime compilation accepts an allocator, source bytes, and `CompileOptions`.
Allocation and system failures are Zig errors. Template syntax and markup
failures are returned as `.failure` in `CompileResult`; `.success` owns a
`CompiledTemplate`.

```zig
const compiled = try zeft.compile(allocator, source, .{});
var template = switch (compiled) {
    .success => |value| value,
    .failure => |diagnostic| return reportCompileFailure(diagnostic),
};
defer template.deinit();

const rendered = try template.render(writer, context);
switch (rendered) {
    .success => {},
    .failure => |diagnostic| return reportRenderFailure(diagnostic),
}
```

Template runtime failures are returned in `RenderResult`. Writer and allocator
errors propagate as underlying Zig errors. Callback failures map to a callable
diagnostic category. A failed render may have written a prefix of its output;
rendering is streaming and does not provide transactional rollback.

The allocator passed to compilation remains valid until the compiled template
is deinitialized. A compiled template owns all finalized data and does not
borrow source or compile-option bytes. It is deinitialized exactly once after
all renders finish.

Callers MAY set `CompileOptions.source_identity`. Compilation diagnostics
borrow that identity for the result lifetime; compiled templates retain their
own copy and attach it to render diagnostics. `sourceLocation` converts a
source byte offset to one-based line and Unicode scalar column coordinates.

## Context values

The native adapter MUST support booleans, signed integers up to 64 bits,
`f32`, `f64`, optionals, byte strings, structs, arrays, and slices. Integers
adapt to signed 64-bit values without passing through floating point; floats
adapt to `f64`. Unsigned integers are supported when their value fits in
`i64`. An unsigned value that does not fit fails with `invalid_operand`.
Optionals adapt to their child value or null; structs adapt to objects; and
non-byte arrays and slices adapt to sequences. Unsupported types MUST produce a
clear compile-time error when their type is known at comptime.

The renderer borrows context storage for the duration of the call. Callers MUST
keep it valid and MUST synchronize mutable context shared by concurrent renders.

## Callbacks and trusted values

Callables are registered per render in one namespace with a case-sensitive
name, callback, and optional user-data pointer. Direct calls and pipes resolve through the same
registration set. A callback receives evaluated values and the render scratch
allocator. Registrations, user data, arguments, and borrowed callback results
remain valid for the render call. Scratch-backed results MUST NOT escape it.
Public runtime values use distinct `integer: i64` and `float: f64` variants.
Numeric literals in template source compile as floats.

Trusted HTML and XML values use the public `Value.trusted_html` and
`Value.trusted_xml` variants. Constructing either is an application trust
boundary. Their format and valid output context follow the language contract;
a plain string is never trusted.

## Include resolver

Includes resolve through the public IncludeResolver callback interface,
independent of filesystems and caches. It receives the exact identity, writer,
context, format, render options, and directive span. It renders the selected
retained immutable child synchronously and releases its lease after use. A
resolver reports missing children, cycles, and child compilation failures
through RenderResult.

`TemplateCache` implements this resolver contract and remains the convenient
default for reloadable applications. Applications MAY provide another resolver
for embedded resources, databases, package systems, or an existing cache.
Custom resolvers MUST retain child templates for the complete render call and
track active identities to report recursive inclusion.

## Diagnostics

Every template diagnostic has a stable category, a half-open byte span when a
source location exists, and an optional source identity. Public helpers MUST
convert byte offsets to one-based line and column positions when given the
original source.

Nested include failures MUST expose an ordered include stack. Each frame
identifies the parent, child, and include-directive span. A child compilation
failure also retains the child's category, span, and source identity.
Cache diagnostic strings and include frames remain valid until cache
deinitialization.

Diagnostics distinguish compile failures from render failures. Writer errors
are not template diagnostics and propagate unchanged. A callback diagnostic
MUST retain the callback error name or an equivalent stable detail.

## Concurrency

Compiled templates are immutable and may be rendered concurrently. Every
render owns its execution and scratch state. Each concurrent call requires an
independent writer and concurrency-safe shared context, registrations, user
data, allocator, and resolver. Deinitialization MUST NOT race with rendering.

`TemplateCache` is thread-safe. Its cache allocator remains valid until cache
deinitialization, and the cache outlives all leases and renders.

## Optional comptime compilation

The comptime API accepts comptime-known source and compile options, reports
compile failures as build failures, and produces the same logical compiled
contract as runtime compilation. Runtime compilation remains the standard API.
