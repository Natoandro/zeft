# Zeft implementation plan

This plan lists open implementation tasks that are not tracked by GitHub
issues. GitHub issues hold the scope and progress for ticketed work; do not
duplicate them here.

When behavior changes, update the relevant language or public API contract,
add or revise the implementation task and its verification, then implement the
change. The resulting documentation, plan, tests, and code are the record of
the decision; do not maintain a separate decision log.

## Implementation tasks

- [ ] **ZEP-104** Build platform-tagged CPython wheels in GitHub Actions for
  the supported OS, architecture, and Python matrix. Pass explicit Zig target
  triples and import-test the wheel on each supported CPython version.
  Verification: complete the matrix successfully and inspect each wheel's
  platform and ABI tags.
