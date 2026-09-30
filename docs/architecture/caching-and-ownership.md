# Caching and ownership

This document specifies how applications reuse compiled templates and how
compiled data is owned.

## Compilation and cache boundary

`compile()` MUST remain deterministic and independent of caches, filesystems,
and global state. Caching MUST be provided by an explicit, application-owned
`TemplateCache` layer.

The cache MUST provide a get-or-compile operation for a caller-supplied
template identity and source. A cache hit MUST return a valid compiled
template for that source and those compile options. A cache miss MUST compile
the source, store the resulting compiled template, and return it.

The cache identity MUST account for source content, all compile options that
affect output or semantics, and the compiler/IR version. Equivalent source
with different format, whitespace, syntax configuration, or compiler version
MUST NOT accidentally share an incompatible compiled result.

## Source change detection

Development-mode reload MUST be a cache behavior. It MUST detect when the
source for an entry has changed, compile the changed source, and replace the
cached entry only after compilation succeeds. A failed reload MUST NOT replace
the last valid compiled entry.

The cache MUST use an authoritative source identity that cannot silently
reuse stale output.

## Includes

An included template MUST be represented as a call to an independently
compiled child template. The cache MUST own and identify child templates
independently from their parents. Changing an included template MUST make the
next render observe the newly compiled child without requiring the parent
template's static content to be recompiled.

An include instruction MUST carry the child's stable template identity and
MUST resolve the current compiled child through the cache for each render.
Missing or invalid included templates MUST produce a runtime error; they MUST
NOT silently render stale or partial content.

## Ownership and lifetime

The allocator supplied to compilation MUST own the persistent data of the
returned `CompiledTemplate`. Deinitializing the template MUST release that
data exactly once.

Temporary compiler structures, including tokens, AST nodes, temporary
expression trees, and optimization worklists, SHOULD share a temporary arena
or equivalent lifetime and MUST be released after finalization. Persistent
Render IR, expression IR, strings, symbols, and retained debug metadata MUST
not refer to released temporary memory.

A cache MUST own its entries. Callers MUST NOT deinitialize a template while a
cache or active render still relies on that template. An entry MUST remain
alive until every active render using it has completed.

## Comptime compilation

Comptime compilation MUST produce the same logical Render IR contract used by
the runtime renderer. The renderer MUST be independent of whether a template
was compiled at runtime or comptime.

Comptime support MUST NOT require a second rendering architecture or change the
semantics of already compiled templates.
