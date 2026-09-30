# Runtime

This document specifies the persistent compiled representation and its
execution.

## Compiled template

`CompiledTemplate` MUST contain the optimized Render IR, expression IR,
referenced strings and symbols, compile metadata, and available source maps.
It MUST be immutable after finalization and MUST own every piece of data
needed for rendering.

The same compiled template MUST be reusable for multiple renders and MUST be
safe for concurrent rendering. A render MUST NOT mutate the template. Each
render MUST use independent mutable state, including its program counter,
scope stack, and loop iterator state.

The renderer MUST consume a writer and a root context. It MUST execute the
compiled program directly. It MUST NOT parse template delimiters, parse
markup, or tokenize expressions at render time.

## Render VM

The renderer MUST interpret the linear Render IR using a program counter.
Instructions MUST provide enough information to advance, branch, jump, write,
and iterate. Conditional instructions MUST evaluate their condition and branch
to a compiled destination. Loop instructions MUST evaluate the iterable once
per loop entry, bind each item in a render-local scope, execute the body, and
continue or exit according to the compiled destinations.

The VM MUST support expression evaluation by invoking the expression
interpreter. It MUST write static output directly to the caller's writer.

Conceptually, the instruction set includes:

```text
WRITE              string_id
WRITE_EXPRESSION   expression_id, escape_mode
JUMP_IF_FALSE      expression_id, target
JUMP               target
LOOP_BEGIN         expression_id, binding_id, exit_target
LOOP_NEXT          body_target, exit_target
END
```

These are the canonical instruction names used in this architecture. Their
binary representation is not a public ABI.

## Expression VM

Expression evaluation MUST use compiled expression IR. A typical expression
such as `user.name | upper` is compiled to operations that load a value,
access a property, call the filter, and return a result. It MUST NOT traverse
expression source text during rendering.

An expression that reads a root-context identifier MUST load its assigned
root symbol and return that value. Root symbols MUST retain the identifier
name used for context lookup. Expression forms MUST be represented by
executable IR rather than reparsed during rendering.

The expression interpreter MUST support short-circuit behavior for logical
operators. It MUST report invalid property access, invalid operations,
missing variables, and filter/function failures as runtime errors with source
locations when available.

## Context and scopes

The root context MUST support native Zig values through an adapter boundary.
The runtime value model MUST represent null, booleans, numbers, strings,
sequences, and objects.

Loop and nested template bindings MUST use render-local lexical scopes. Lookup
MUST resolve the nearest visible local binding before falling back to the root
context. The compiler SHOULD replace statically resolved local names with
local-slot references to avoid repeated name searches.

## Output and escaping

Every dynamic output operation MUST carry an escape mode determined during
compilation. At minimum, modes MUST distinguish HTML text, HTML attribute,
XML text, XML attribute, and explicit raw output.

The renderer MUST apply the encoded escape mode when writing a dynamic value.
It MUST NOT infer context by scanning already-rendered output. Raw output MUST
be an explicit template operation; it MUST NOT be the default for ordinary
interpolated values.

## Errors

Compile errors and runtime errors MUST be distinguishable.

Compile errors include invalid syntax or markup, invalid expressions, and
invalid template constructs. Runtime errors include missing variables,
invalid property access, non-iterable values, invalid operands, filter/function
failures, and writer failures.

Missing variables MUST produce an error by default. A permissive missing-value
policy MAY be added as an explicit render or compile option; it MUST NOT change
the default behavior.

Errors MUST preserve their category and MUST include source information when
the compiled template retains it. Writer errors MUST propagate to the caller.

## Allocation and concurrency

Compilation MAY allocate temporary and persistent memory. Temporary compiler
memory SHOULD be released as a unit after finalization. Persistent compiled
data MUST remain valid until the template is deinitialized.

Render state MUST be isolated per call. The common rendering path SHOULD avoid
allocation where practical; any required scratch allocation MUST be owned by
or explicitly supplied to that render and MUST NOT be stored in the compiled
template.
