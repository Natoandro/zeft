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

Control directives MUST use `{% ... %}` and MUST be recognized only in
template text, not inside markup tags, attribute values, comments, or CDATA.
The supported forms are `{% if expression %}`, `{% else %}`, `{% endif %}`,
`{% for name in expression %}`, `{% endfor %}`, `{% break %}`, and
`{% continue %}`. `else if` is not a form; nested `if` blocks express multiple
conditions. Each `if` has at most one `else`. Block terminators MUST match the
most recently opened block. Unknown directives, duplicate or unmatched
terminators, and unterminated directives MUST fail compilation with a source
span covering the directive. `break` and `continue` MUST be rejected outside
a loop and MUST target the innermost active loop.
Unknown directive names MUST use the `syntax` diagnostic category. Invalid
block nesting and loop control outside a loop MUST use `invalid_construct`.

Conditions MUST evaluate to booleans. A `for` iterable MUST evaluate to a
sequence; a non-sequence is a runtime `non_iterable` error at the loop
expression span. Empty sequences execute no body. A loop creates one lexical
binding visible only in its body. Loops are the only constructs that create
lexical scopes. Nested loop bindings may shadow outer loop bindings and root
context names; lookup selects the nearest loop binding and then the root
context. The root binding is visible again after a loop.

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

HTML and XML comments using `<!--` and the first subsequent `-->` MUST be
represented as static markup and serialized exactly as written. Template
delimiters and text escapes inside a comment MUST remain literal bytes and
MUST NOT be parsed. An unterminated comment MUST fail compilation as invalid
markup.

The initial HTML declaration grammar MUST accept only the HTML5 doctype form:
`<!DOCTYPE html>`, allowing ASCII case variation in `DOCTYPE` and `html` and
ASCII markup whitespace between the tokens or before `>`. The compiler MUST
preserve an accepted doctype exactly as written. Other declarations,
processing instructions, and CDATA sections MUST fail compilation as invalid
markup.

### XML markup

XML templates MUST be treated as fragments rather than complete XML documents.
They MAY contain multiple top-level nodes or character data; the compiler MUST
NOT require exactly one document element.

In XML format, element and attribute names MUST use the ASCII grammar
`[A-Za-z_][A-Za-z0-9_.:-]*` and MUST be matched case-sensitively. Names MUST
retain their original source spelling. Every non-self-closing element MUST
have one exactly matching end tag. Any element MAY use `<name/>` or
`<name />` empty-element syntax; the compiler MUST preserve its opening tag
exactly and MUST NOT generate an end tag. XML MUST NOT apply the HTML void
element set. XML attributes MUST have single- or double-quoted values; bare
attributes MUST be rejected as invalid markup.

XML format MAY begin with one XML declaration at byte offset zero. Its version
MUST be `1.0` or `1.1`; optional `encoding` and `standalone` pseudo-attributes
MUST follow XML declaration ordering and MUST be preserved exactly as written.
`encoding` MUST use the ASCII encoding-name syntax; `standalone` MUST be `yes`
or `no`. XML comments and CDATA sections MUST be represented as static markup
and serialized exactly as written. XML comments MUST NOT contain `--` except
as the final comment delimiter. The first subsequent `]]>` closes a CDATA
section; template delimiters inside CDATA MUST remain literal. An unterminated
CDATA section MUST fail compilation as invalid markup. XML document type
declarations and processing instructions other than the XML declaration MUST
be rejected as invalid markup.

Outside comments and CDATA sections, XML text and attribute values MUST NOT
contain a literal `<`; XML text MUST NOT contain `]]>`. Ampersands in static
XML text and attribute values MUST begin one of the five predefined XML entity
references or a valid decimal or hexadecimal numeric character reference.
Because document type declarations are unsupported, other named entities MUST
be rejected. Valid source references MUST be preserved verbatim.

### Expression analysis

Analysis MUST visit expression occurrences in document order, including
depth-first element children. It MUST assign one symbol ID per distinct root
identifier, reusing that ID for later occurrences of the same case-sensitive
name. New IDs MUST be assigned in first-occurrence order, starting at zero.
Each expression MUST be marked with its text or attribute output context. The
selected output format MUST remain available to rendering and determines the
format-specific escaping rule for that context.

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

### Expression grammar

Identifiers MUST match `[A-Za-z_][A-Za-z0-9_]*`. The case-sensitive literals
`null`, `true`, and `false` are reserved. Decimal number literals MUST match
`[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?`. String literals MUST use single or
double quotes. They MUST support the escapes `\\`, `\'`, `\"`, `\n`, `\r`,
and `\t`; unknown escapes and unescaped line breaks MUST be invalid.

An access expression MUST begin with an identifier and MAY continue with any
number of `.property` or `[expression]` selectors. Property names MUST match
the identifier grammar. An index selector MUST evaluate to a non-negative
integer and MUST be applied to a sequence. Parenthesized expressions MUST be
supported for grouping.

Named function calls MUST use `name(argument, ...)` syntax and MUST be
available as expression values. Filters MUST use `value | name` syntax and
MAY take arguments as `value | name(argument, ...)`; filter pipelines MUST
associate left-to-right and bind more tightly than logical OR. Calls and
filters MUST accept zero or more expression arguments syntactically; arity and
value constraints are checked by the invoked callable at render time.
Identifiers followed by `(` are function calls, while bare identifiers remain
root-context lookups.

Applications MUST be able to register filters and functions per render. Each
registration MUST provide a case-sensitive name, callback, and optional
user-data pointer. A callback MUST receive the render scratch allocator and
the evaluated argument values, and MUST return a `Value` or an error. The
render scratch allocator MUST remain valid only for that render; callback
results that reference it MUST be consumed before rendering returns. A
callback error or unknown callable MUST produce the corresponding filter or
function runtime error at the call site's source span. Caller registrations
with the same name as a built-in MUST take precedence for that render.

The initial built-ins MUST include the `length(value)` function for strings
and sequences and the `default` filter, which returns its second argument when
the input is null or an empty string. The `upper`, `lower`, and `trim` filters
MUST accept one string; case conversion is ASCII-only and trim removes ASCII
space, tab, carriage return, and line feed from both ends. Invalid arity or
value types MUST be reported as filter/function failures.

Unary `!` and `-` MUST associate right-to-left. Binary operators MUST associate
left-to-right. Their precedence, from lowest to highest, MUST be:

| Precedence | Operators |
| --- | --- |
| 1 | `||` |
| 2 | `&&` |
| 3 | `==`, `!=` |
| 4 | `<`, `<=`, `>`, `>=` |
| 5 | `+`, `-` |
| 6 | `*`, `/`, `%` |
| 7 | unary `!`, unary `-` |
| 8 | property and index selectors |

Logical operators MUST short-circuit. Arithmetic operators MUST operate on
numeric values; `+` MUST NOT implicitly concatenate strings.

The template language MUST support dynamic expressions, conditional output,
and iteration as specified above. Loop bindings MUST be resolved to local
slots where statically known.

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

Preserve mode MUST emit source whitespace exactly, including whitespace
around dynamic output. Compact mode MUST collapse runs of markup whitespace
in ordinary text to one space. Within element-only content, whitespace-only
text nodes are formatting and MUST be removed. In mixed content, whitespace
that separates text from inline markup or dynamic output MUST remain as one
space. Pretty mode MUST format element-only content with line breaks and a
two-space default indentation; callers MAY set the indentation string through
compile options. Mixed content MUST remain inline. These structural rules
apply equally to HTML and XML.

Conditional and loop bodies whose possible output is element-only MUST
participate in structural formatting. Loop-generated elements MUST receive
the same indentation as static siblings. Dynamic constructs inside mixed
content MUST remain inline.

HTML `pre`, `textarea`, `script`, and `style` contents MUST preserve source
whitespace in all modes. XML element names do not imply whitespace
sensitivity. Formatting-generated whitespace is applied only to element-only
content; source whitespace is retained verbatim in preserve mode.

The selected format and whitespace policy MUST affect the compiled output and
MUST be included in template identity for caching.

## Diagnostics

Compile failures MUST include a source location and a useful category, such as
invalid markup, invalid expression, unknown directive, or invalid control-flow
usage. The compiler MUST NOT defer errors that are decidable from the source
until rendering.

Finalized templates MUST retain source maps for runtime diagnostics.
