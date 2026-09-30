# Repository guidance

## Architecture and planning

- Treat `docs/architecture/` as normative. Requirements there define the
  required behavior and boundaries of the system.
- Keep implementation sequencing and progress in
  `docs/design/implementation-plan.md`. Each task has a stable reference;
  preserve those references and check an item only after its implementation
  and verification are complete.
- If implementation requires a product or architectural decision not settled
  by the existing requirements, ask the user in the conversation. Do not put
  unresolved alternatives into normative documents.

## Zig and verification

- Support Zig 0.16.0 as specified by `build.zig.zon` and the root README.
- Run `zig fmt` on changed Zig files, then run `zig build` and `zig build test`
  for relevant implementation changes.
- Keep unit tests, integration tests, and reusable fixtures in their
  respective `tests/` locations.

## Git commits

- Use Conventional Commits for every commit, in the form
  `<type>(<optional scope>): <imperative summary>`; for example,
  `feat(parser): parse text interpolations` or `docs: clarify runtime API`.
- When the user has asked to commit and the change scope is clear, choose an
  accurate commit message and commit without asking them to approve the
  wording. Ask only when the commit scope or intent is materially ambiguous.
- Do not create commits unless the user asks for one.
