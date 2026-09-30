# Compilation

This document specifies how Zeft turns template source into a
`CompiledTemplate`.

## Public operation

The public compilation operation MUST accept source text, an allocator, and
explicit compile options. It MUST return an owning `CompiledTemplate` or a
diagnostic error. It MUST NOT read from a filesystem, resolve includes, or
consult a global cache as an implicit side effect.

Conceptually:

```zig
var template = try zeft.compile(allocator, source, .{
    .format = .html,
    .whitespace = .preserve,
});
defer template.deinit();

try template.render(writer, context);
```

The exact Zig types and signatures are implementation details; the ownership
and behavior described here are requirements.

## Compiler phases

Compilation MUST perform these phases in order:

1. **Lex and parse.** Parse markup and template syntax into an AST.
2. **Analyze.** Validate structure and template constructs, resolve names and
   scopes where possible, and determine output contexts.
3. **Lower.** Convert the AST into the linear Render IR and expression IR.
4. **Optimize.** Apply semantics-preserving optimizations to those IRs.
5. **Finalize.** Produce the immutable persistent `CompiledTemplate` and
   release temporary compiler data.

The AST MUST NOT be the persistent representation used by rendering.

## Markup and template parsing

### Phase 1 template delimiters

The initial template grammar MUST recognize `{{` as the start of an
interpolation and the first subsequent `}}` as its end. Delimiters MUST NOT
nestedly balance. ASCII space, tab, carriage return, and line feed immediately
inside the delimiters MUST be excluded from the expression source span; other
expression syntax is specified separately.

In static text, `\{{` MUST emit the literal bytes `{{`, and `\\` MUST emit
one literal backslash. These escapes MUST be recognized left-to-right; all
other backslashes MUST remain literal. Consequently, `\\{{ name }}` emits a
backslash followed by an interpolation. A `}}` outside an interpolation MUST
remain ordinary static text. The delimiter escapes apply to text, not markup
names or attribute values.

The Phase 1 markup subset MUST accept element names beginning with an ASCII
letter or underscore and continuing with ASCII letters, digits, underscore,
hyphen, colon, or period. Opening elements in this subset MUST have no
attributes. Closing names MUST match their opening names using ASCII
case-insensitive comparison. Elements MUST be balanced and properly nested.
Attributes, comments, declarations, void-element behavior, and interpolation
inside markup constructs are outside this subset.

The parser MUST understand markup structure. It MUST represent elements,
attributes, attribute values, text nodes, and embedded expressions as distinct
syntax, rather than treating the whole document as undifferentiated text with
template delimiters.

The parser and analyzer MUST retain enough structure to identify whether an
expression appears in HTML/XML text or an attribute value. This information
MUST be lowered into the output operation so rendering can apply the correct
escaping rule.

The template language MUST support dynamic expressions, conditional output,
and iteration. A loop binding MUST have a lexical scope limited to its loop
body. Nested scopes MUST be representable without mutating the compiled
template.

The parser MUST retain source spans for syntax and expression nodes. Compile
diagnostics MUST identify the relevant source location and MUST distinguish
syntax, invalid markup, and semantic errors where applicable.

## Expression compilation

Expressions MUST be parsed into an expression AST and lowered into a separate
expression IR. The expression IR MUST be executable without reparsing source
text. It MUST support the language operations accepted by the template
grammar, including property access, operators, and filter/function calls where
implemented.

The compiler MUST resolve statically known local bindings to local slots where
possible. Root-context lookups MUST use symbol identifiers. Expression
instructions MUST retain source mapping sufficient to report runtime failures
at the originating expression.

## Render IR generation

The Render IR MUST be a linear instruction sequence. Control flow MUST use
explicit branch destinations and jumps. Iteration MUST use `LOOP_BEGIN` and
`LOOP_NEXT` instructions. Nested loop state MUST be maintained per render.

The IR MUST represent at least:

- writing static text;
- evaluating and writing an expression;
- conditional branches;
- iteration and loop-local bindings;
- termination of the program.

The IR MUST store expressions and strings in compiled data addressed by stable
IDs. Instructions MUST NOT depend on pointers into temporary AST storage.

## Optimization and serialization

Optimization MUST preserve template semantics. The optimizer MUST merge
adjacent static output into a single output operation when possible. It SHOULD
fold compile-time constants, remove unreachable or empty operations, and
intern repeated identifiers and strings.

Static markup MUST be serialized during compilation. The renderer MUST write
the resulting serialized bytes directly and MUST NOT reconstruct markup nodes.

Whitespace behavior MUST be selected through explicit compile options. The
supported policies are preserve, compact, and pretty. Whitespace processing
MUST account for markup semantics; it MUST NOT be implemented as a global
trim or regular-expression pass. In particular, whitespace-sensitive
elements and meaningful text boundaries MUST be preserved.

The selected format and whitespace policy MUST affect the compiled output and
MUST be included in template identity for caching.

## Diagnostics

Compile failures MUST include a source location and a useful category, such as
invalid markup, invalid expression, unknown directive, or invalid control-flow
usage. The compiler MUST NOT defer errors that are decidable from the source
until rendering.

Finalized templates MUST retain source maps for runtime diagnostics.
