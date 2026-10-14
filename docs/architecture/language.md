# Template language

This document defines Zeft's markup, template, expression, output, and
whitespace semantics. These rules are independent of the compiler and renderer
implementation.

## Markup formats

Compilation selects HTML or XML. Markup is parsed structurally so every
interpolation has a text or attribute output context. Element and attribute
spelling, quote style, comments, declarations, and accepted character
references MUST be preserved unless a whitespace policy explicitly transforms
surrounding text.

HTML names are matched using ASCII case-insensitive comparison. HTML supports
quoted and valueless attributes, comments, the HTML5 doctype, and the standard
void elements: `area`, `base`, `br`, `col`, `embed`, `hr`, `img`, `input`,
`link`, `meta`, `param`, `source`, `track`, and `wbr`. A void element has no end
tag. Zeft MUST document deviations from accepted HTML syntax until broader
HTML compatibility is implemented.

HTML interpolation MUST fail compilation with `unsupported_syntax` inside
`script` or `style` elements, or in `style`, `srcdoc`, or attributes whose names
begin with `on` (ASCII case-insensitive). Static content in those positions
remains supported within the accepted markup syntax. HTML text and attribute
escaping does not validate URL schemes; callers MUST validate untrusted URL
values before placing them in URL-bearing attributes.

XML templates are fragments and MAY contain multiple top-level nodes or text.
XML names use `[A-Za-z_][A-Za-z0-9_.:-]*` and are case-sensitive. Attributes
MUST be quoted, have valid XML names, and be unique by exact name. Literal
XML source MUST be valid UTF-8 and contain only characters permitted by its
XML version; restricted XML 1.1 characters require character references. Any element may use empty-element syntax. An XML declaration
at byte offset zero, comments, CDATA, and the five predefined entities are
supported. XML doctypes, custom entities, and processing instructions other
than the declaration are unsupported.

Malformed markup MUST fail compilation. Markup diagnostics use half-open byte
spans into the original source. Zeft does not silently apply browser error
recovery.

## Template syntax

`{{ expression }}` interpolates an expression. The first subsequent `}}`
closes it; delimiters do not nest. ASCII whitespace immediately inside the
delimiters is excluded from the expression span.

Backslashes in template text have no special meaning and are preserved. A
literal template delimiter may be produced through interpolation, such as
`{{ "{{" }}` or `{{ "{%" }}`. Template delimiters in comments and CDATA
remain literal.

Block syntax uses explicit opening, branch, and closing prefixes in template
text:

- `{#if expression}`, `{:else if expression}`, `{:else}`, `{/if}`
- `{#for name in expression}`, optional `{:else}`, `{/for}`

Standalone directives use `{% ... %}`:

- `{% break %}` and `{% continue %}`
- `{% include "identity" %}`

Interpolation uses `{{ expression }}`. Closing blocks contain only the block
name; they do not repeat the opening expression. Branches and closing blocks
MUST match the innermost open block. A conditional permits zero or more
`{:else if expression}` branches followed by at most one `{:else}` branch.
Conditions are evaluated in order until one is true; only its body runs.
Percent-delimited directives accept only include, break, and continue.

Conditions MUST be booleans. A loop operand MUST be a sequence. The loop body
runs once per item; its `else` body runs only when the sequence is empty. A loop
creates a lexical binding that may shadow an outer loop or root name. `break`
and `continue` target the innermost loop and are invalid outside a loop.
The loop binding and iteration scope exist only in its main body. Its `else`
body uses the enclosing scope; controls there target an enclosing loop, if any.

An include identity is a double-quoted, non-interpolated byte string without
escapes. Zeft does not interpret it as a filesystem path. Compilation records
the identity; rendering resolves it through the caller's resolver.

## Expressions

Identifiers match `[A-Za-z_][A-Za-z0-9_]*`. `null`, `true`, and `false` are
case-sensitive literals. Numbers match
`[0-9]+(\.[0-9]+)?([eE][+-]?[0-9]+)?`. Strings may use single or double quotes
and the escapes `\\`, `\'`, `\"`, `\n`, `\r`, and `\t`.

An access begins with an identifier and may contain `.property` and
`[expression]` selectors. Properties are case-sensitive. Sequence indexes are
zero-based non-negative integers. Parentheses group expressions.

Calls use `name(argument, ...)`. Pipe syntax, written as `value | name` or
`value | name(argument, ...)`, is alternate call syntax that passes the piped
value as the first argument and associates left-to-right. Calls and pipes use
one callable namespace. Caller registrations override built-ins.

Unary operators associate right-to-left. Binary operators associate
left-to-right with this precedence, lowest first:

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

Logical operators short-circuit and require booleans. Arithmetic requires
numbers; `+` does not concatenate strings. Integer values use signed 64-bit
representation. Addition, subtraction, multiplication, and modulo of integer
operands, and unary negation, preserve integer values and detect overflow;
overflow fails with `invalid_operand`. For mixed `i64` and `f64` operations
other than division, an `f64` that is an exact integer within the `i64` range
is converted to `i64`, and the operation uses integer semantics. Otherwise,
the integer is converted to `f64` and the operation uses floating semantics.
Division always converts both operands to `f64` and returns an `f64`. Division
and modulo by positive or negative zero fail with `invalid_operand`.

Integer comparisons are exact. For mixed comparisons, an `f64` that is an
exact integer within the `i64` range is converted to `i64`; otherwise the
integer is converted to `f64`. Numeric literals in template source remain
`f64` literals.

For equality, `null == null` is true. Comparing null with a nonnull value is
false, and `!=` is the inverse. Integers and `f64` values form one numeric
comparison group; mixed equality and ordering use the conversion rule above.
Equality between other different nonnull value types fails with
`invalid_operand`. Ordering requires compatible value types.

The built-ins are `length`, `default`, `upper`, `lower`, and `trim`; each may be
used with direct or pipe syntax. `length` accepts strings and sequences.
`default` selects its fallback for null or an empty string. Case conversion and
trimming operate on ASCII bytes.

## Values and output

The value model contains null, booleans, signed 64-bit integers, `f64`
numbers, strings, sequences, and objects. Integer interpolation writes the
exact base-10 integer. Null interpolation emits no bytes. Direct
interpolation of a sequence or object fails with `invalid_operand`.

Ordinary interpolation is escaped according to the compile-time output format
and position. HTML and XML text escape `&`, `<`, and `>`. Attributes also
escape both quote characters: HTML uses `&quot;` and `&#39;`; XML uses
`&quot;` and `&apos;`.

Future trusted output values MUST be tagged with their format. A trusted HTML
value may bypass escaping only in HTML text; a trusted XML value may do so only
in XML text. Trusted values used in a different format or in an attribute MUST
fail rather than silently bypass escaping. Ordinary strings remain escaped.

## Whitespace

Whitespace policy is selected at compilation. `preserve` is the default and
MUST preserve source whitespace exactly, including around dynamic output.

`compact` and `pretty` are compile-time serialization policies over the parsed
template; they do not require a second parse and do not affect expression or
rendering semantics. They are not guarantees about visual browser layout. They
MUST preserve whitespace inside HTML `pre`, `textarea`,
`script`, and `style`, and at meaningful mixed-content boundaries in either
format. Compact mode may collapse formatting whitespace between structural
elements. Pretty mode may add line breaks and configured indentation between
structural elements. Neither policy may rewrite dynamic values or infer layout
from CSS. Includes are opaque structural boundaries in the including template.
