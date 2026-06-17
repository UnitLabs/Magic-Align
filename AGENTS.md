# Agent Notes

- Project todo/design backlog: see `TODO.md`.
- Keep Magic Align changes architecture-level where possible. Avoid introducing isolated special-case paths for snapping, point references, undo restore, or session state.
- Implement equivalent behavior through shared, robust code paths rather than hard-to-maintain one-off branches. In particular, Copy and Copy&Move clone/mirror handling should reuse the same copy pipeline with mode-specific inputs instead of separate backup/fallback logic.
