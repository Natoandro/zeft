# Zeft implementation plan

This plan tracks future work. Each accepted task has a stable reference and is
checked only after its implementation and verification are complete.
References `ZEP-001` through `ZEP-087` are complete and preserved in Git
history; references are never reused.

## Future work

- [ ] **ZEP-088** Add optional comptime template compilation using the public
  compile options and the same logical Render IR contract as runtime
  compilation. Runtime compilation remains the standard API and behavior.
  Verification: add compile-success and build-failure cases for the comptime
  API, and verify equivalent runtime and comptime inputs render identically.

Add future work here only after its required behavior and boundaries have been
decided. Record unresolved ideas outside the implementation plan until they
are concrete enough to implement and verify.
