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

## Compiler pipeline

Compilation MUST perform these stages in order:

1. **Lex and parse.** Parse markup and template syntax into an AST.
2. **Analyze.** Validate structure and template constructs, resolve names and
   scopes where possible, and determine output contexts.
3. **Lower.** Convert the AST into the linear Render IR and expression IR.
4. **Optimize.** Apply semantics-preserving optimizations to those IRs.
5. **Finalize.** Produce the immutable persistent `CompiledTemplate` and
   release temporary compiler data.

The AST MUST NOT be the persistent representation used by rendering.

## Markup and template parsing

### Template delimiters

The template grammar MUST recognize `{{` as the start of an interpolation and
the first subsequent `}}` as its end. Delimiters MUST NOT nestedly balance.
ASCII space, tab, carriage return, and line feed immediately inside the
delimiters MUST be excluded from the expression source span.

In static text, `\{{` MUST emit the literal bytes `{{`, and `\\` MUST emit
one literal backslash. These escapes MUST be recognized left-to-right; all
other backslashes MUST remain literal. Consequently, `\\{{ name }}` emits a
backslash followed by an interpolation. A `}}` outside an interpolation MUST
remain ordinary static text. The delimiter escapes apply to text, not markup
names or attribute values.

Element names MUST be serialized with their original source spelling.

For HTML, the void elements are `area`, `base`, `br`, `col`, `embed`, `hr`,
`img`, `input`, `link`, `meta`, `param`, `source`, `track`, and `wbr`, matched
using ASCII case-insensitive comparison. A void element MUST have no children
and MUST NOT have an end tag. Its opening tag MUST be serialized exactly as
written, with no generated end tag. HTML void elements MAY use either `<tag>`
or `<tag/>` syntax; the compiler MUST preserve that opening-tag spelling.
Self-closing syntax on a non-void HTML element MUST be rejected as invalid
markup.

A valueless attribute MUST be represented and serialized as a bare boolean
attribute, preserving its source spelling and surrounding markup bytes. An
attribute with a quoted value MUST remain an ordinary valued attribute,
including when its name commonly denotes a boolean attribute; its source
spelling and quoting MUST be preserved.

HTML comments using `<!--` and the first subsequent `-->` MUST be represented
as static markup and serialized exactly as written. Template delimiters and
text escapes inside a comment MUST remain literal bytes and MUST NOT be
parsed. An unterminated comment MUST fail compilation as invalid markup.

The initial HTML declaration grammar MUST accept only the HTML5 doctype form:
`<!DOCTYPE html>`, allowing ASCII case variation in `DOCTYPE` and `html` and
ASCII markup whitespace between the tokens or before `>`. The compiler MUST
preserve an accepted doctype exactly as written. Other declarations,
processing instructions, and CDATA sections MUST fail compilation as invalid
markup.

### Expression analysis

Analysis MUST visit expression occurrences in document order, including
depth-first element children. It MUST assign one symbol ID per distinct root
identifier, reusing that ID for later occurrences of the same case-sensitive
name. New IDs MUST be assigned in first-occurrence order, starting at zero.
Each expression MUST be marked with its HTML or XML text or attribute output
context.

An expression that resolves to a root-context identifier MUST load its
assigned symbol and return that value. Runtime lookup uses the symbol's
original identifier name against the root context. The root-context adapter
and missing-variable behavior are specified by the runtime contract.

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

Markup diagnostics MUST use half-open byte spans into the original template
source. A mismatched or unmatched end tag MUST identify the complete end-tag
token. Malformed start- or end-tag syntax MUST identify the token from its
opening `<` through its closing `>`, or through end of source if unterminated.
An element that reaches end of source without a matching end tag MUST identify
that element's complete opening-tag token.

## Expression compilation

Expressions MUST be parsed into an expression AST and lowered into a separate
expression IR. The expression IR MUST be executable without reparsing source
text. It MUST support the language operations accepted by the template
grammar, including property access, operators, and filter/function calls.

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

The IR MUST store expressions, strings, and symbols in compiled data addressed
by stable IDs. Instructions MUST NOT depend on pointers into temporary AST
storage. Static text escapes MUST be decoded during compilation. Markup MUST
be serialized during lowering; rendering MUST NOT reconstruct markup nodes.
Every render and expression instruction MUST carry a source span.

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
