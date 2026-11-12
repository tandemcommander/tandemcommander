# Data model - 426

No stored format changes.

- **Side worktree** (`<git-common-dir>/tandem-backlog-app/main-worktree/`): sparse set
  `/backlog/` (was `backlog`); feature folders of `specs/` created empty, files of `specs/` never.
- **Loop run record** (`.git/tandem-backlog-loop/run.json`): unchanged fields. Derived state
  "finished" = a journal row of `slug` after `rows_before` and the run lock not the run's.
- **`describe()` JSON** (`bin/backlog-loop.sh status --json`): new key `finished`: the outcome
  of that row, or null. Additive (the app reads known keys only).
- **Trace stream** (`GET /api/runs/{id}/stream`): see [contracts/trace-stream.md](contracts/trace-stream.md).
