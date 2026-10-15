# Caching and ownership

This document specifies how applications reuse compiled templates and how
compiled data is owned.

## Compilation and cache boundary

`compile()` MUST remain deterministic and independent of caches, filesystems,
resolvers, and global state. Includes resolve through the public resolver
contract during rendering. Caching is provided by an explicit,
application-owned, thread-safe `TemplateCache` that implements that contract.

The cache MUST provide a get-or-compile operation for caller-supplied stable
identity bytes, source bytes, and compile options. It MUST NOT read files or
resolve identities. Callers load sources and explicitly submit changed source
to the cache. A hit MUST return a retained lease to the matching immutable
compiled template. A miss MUST compile, store, and return a lease.

Cache matching MUST account for exact identity bytes, source bytes, all compile
options that affect output or semantics, and the compiler/IR version. Compile
options include output format, whitespace policy, indentation bytes, and
optional source identity. A hash MAY accelerate matching, but equality MUST be
confirmed against all identity inputs.

## Source change detection

Reload is explicit: when the caller submits changed source for an identity,
the cache MUST compile it and replace the current entry only after compilation
succeeds. A failed reload MUST leave the last valid entry available. The failed
compile result MUST still be returned to the caller. Eviction removes the
current lookup entry; outstanding leases remain valid.

## Includes

An included template MUST be represented as a call to an independently
compiled child template. The cache MUST own and identify child templates
independently from their parents. Changing an included template MUST make the
next render observe the newly compiled child without requiring the parent
template's static content to be recompiled.

Include syntax and identity semantics are defined by the language contract.
`compile()` MUST compile a parent without looking up its children.

Rendering MUST ask its resolver for the current child on each include
execution through the public resolver callback. A resolver MUST retain its
selected child for the duration of rendering it. Cache callers populate or
reload children with get-or-compile before rendering. A lease render pins that
lease's root version while resolving
children from the current cache. A cache render pins the current root version.
Missing children, children whose initial compilation failed, and include
cycles MUST return runtime diagnostics with the relevant include identity and
the including template identity and directive span. An initial child compile
failure MUST also retain the child's compile category and source span. A failed
reload MUST preserve the last valid entry, which remains renderable.

Lookup, compilation publication, replacement, eviction, and reference
accounting MUST be synchronized. Compilation MAY be serialized within a cache.
Rendering MUST occur without holding the cache lock. A render MUST hold a lease
for every template it executes. Replaced or evicted templates MUST be
destroyed only after all leases to them are released.

## Ownership and lifetime

Compiled-template ownership follows the public API contract. Temporary compiler
structures MUST be released after compilation and MUST NOT be referenced by a
cache entry.

The cache MUST own its entries. A `TemplateLease` MUST be released exactly
once. The cache MUST outlive all its leases and renders; deinitialization MUST
assert that no active or retired entry still has a lease. The cache allocator
MUST remain valid through cache deinitialization. Include identity strings in
diagnostics returned from cache-backed rendering MUST remain valid until cache
deinitialization, including after replacement or eviction.
