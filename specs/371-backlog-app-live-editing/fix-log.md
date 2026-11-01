# Fix log - 371 backlog app revision: editing while a run is in progress

Running log of the work (project rule: keep it while working). Newest entries at the end.

## 2026-11-01 - measurements before the design

- `npm run check` on `main` (`f46caca4`): typecheck, lint, format pass; vitest 282 / 284 - two
  failures, both from a run lock dated `2026-10-30T10:00:00` in the fixtures
  (`write-path.test.ts:149`, `ai-jobs.test.ts:250`): the lock is older than the tool's 24-hour
  stale rule since 2026-10-31, so the gate says `stale-lock`. Time-dependent fixtures (R9).
- Home shows *In progress* 0 during a run: the board is read from `main` (`--ref main`), where
  the running item is an `open` row of *Next* (R10 of 344 by design). The overlay (R6) fixes it.
- `git worktree add --detach --no-checkout` 0.06 s; sparse `backlog` + `tools/backlog` 0.6 s /
  2.6 MB; sparse with every `specs/*/` 1.5 s / 67 MB; a worktree under
  `.git/tandem-backlog-app/` is accepted; `backlog.py --root <worktree> board|check|lock status`
  work (TOTAL: 0; the lock is found through the common directory).
- `claude -p --input-format stream-json --output-format stream-json`: two turns in one process
  (3.9 s and 3.8 s, context kept, exit 0 at stdin close, 0.076 USD with haiku); `--resume <sid>`
  in a new process answers from the earlier context (4.1 s).
- The app is not running (no listener on 47321) and no loop lives: the checks can run freely.

## 2026-11-01 - design

- spec, clarifications (five answers recorded, the maintainer is away), research R1-R11, plan,
  data model, contracts (HTTP, loop CLI, backlog CLI, chat), quickstart written.
- Decision worth repeating: the primary working tree is never touched while a run holds the
  lock; `main` moves by compare-and-swap from a sparse detached side worktree; the loop holds the
  edit lock while a run starts (until the run is on its branch) and while it returns (`returning`
  called by the skill at step 9).
