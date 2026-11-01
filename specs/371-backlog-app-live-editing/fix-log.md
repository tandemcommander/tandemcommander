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

## 2026-11-01 - implementation, phases 1-2 and the overlay

- Python: `next --except` (3 tests), the loop holds the edit lock from its precheck until the
  run lock names a branch and again from the `returning` flag until claude ends; `returning`
  command; `status --json` `edit_lock.holder` + `returning`; `branch-hang` fake step with
  `before_branch`. test_loop 113 / 113, test_backlog 112 / 112, test_bin_help OK.
- Trap: the loop tests play the app from the test process, so "our own pid" cannot mean "our
  own lock": the loop recognises its hold by the lock's exact text (`edit_lock_mine`).
- Trap: a sparse pattern `specs/*/spec.md` misses feature folders without a `spec.md` (the
  fixture's `243-*`): the tool reported `feature-missing` and the change was refused. The side
  worktree now checks out `backlog` only and creates every `specs/<folder>` empty from the
  commit's tree (git ignores empty folders).
- Trap (measured by the first side-worktree test): moving `main` while the primary tree has
  `main` checked out leaves the primary tree with a staged modification of `BACKLOG.md` - the
  exact hazard of research R2; the test now puts the primary tree on a branch first, and the
  queue refuses (`run-on-main`) and re-checks the primary HEAD before the swap.
- Trap: the fixture's `BACKLOG.md` is CRLF in a Windows checkout (text=auto); a test parsing
  `git show main:backlog/BACKLOG.md` must normalise line ends.
- `git sparse-checkout` in a linked worktree set `extensions.worktreeConfig = true` in the
  repository's config (seen after the first measurement) - harmless, documented in the module.
- App: gate decision table (13 rows, 15 tests), side worktree (6 tests), write queue with the
  three channels, tray entries with channel / commit, frozen refusals in the routes, the
  running-item overlay (`Board.running`, next up without it, the item detail) - 4 tests; the
  write-channel tests (7) run a real idle loop for the `commit` channel. The AI apply step and
  the AI runner follow the new gate (`free` only).

## 2026-11-01 - state at the usage limit (the session was cut here)

Done and committed: Phase 1, Phase 2, US1 (server + web + skills), US2 (overlay), US3 (position
field, Move to the top; e2e `us3-order` 8/8 green incl. the new position test), the chat server
(`chat/service.ts`, `chat/context.ts`, `api/chat.ts`, `prompts/chat.md`), the chat page, route
and bare layout, the chat budget setting, `fake-claude-chat.mjs`, `chat.test.ts` (written, NOT
yet run), `us1-live-edit.spec.ts` (last run: everything up to the frozen item's page passed; the
assertion on the Block button was wrong - an in-progress item has no Block button - fixed to
"Edit text", NOT re-run). Typecheck green; lint/prettier not re-run after the chat files.

Left (tasks.md): T021-T026 partly (banner/tray done; soak T026 not written), T029-T031 (US2 web
done, e2e assertion fixed), T036-T044 (chat: tests to run, lint, e2e `us4-chat.spec.ts` to
write), T045-T049 (revision browse, docs, full `npm run check` + `npm run test:e2e`, review,
history entry, closing report). Next commands: `npm run check`, `npx vitest run
packages/server/test/chat.test.ts`, `npx playwright test e2e/us1-live-edit.spec.ts`.

## 2026-11-01 - review (refute-first, one agent) and the fixes

- MUST M1: on the maintainer's repository (`core.autocrlf=true`, 255 backlog files `i/lf w/crlf`)
  every change during a run would have been refused `changed-underneath`: the client's revision
  is the blob's SHA-256 (LF, read from git objects), the side worktree's file is CRLF. The fixtures
  force `autocrlf false`, so the suite was green. First fix (normalising the worktree's files to
  LF before hashing) broke the e2e fixture, whose blobs are CRLF: the e2e copies the fixture's
  CRLF working copy and commits it with `autocrlf false`. The fix that holds for both: the side
  worktree checks files out exactly as the blobs hold them (`git config --worktree
  core.autocrlf false` + `core.eol lf`, possible because `sparse-checkout` enabled
  `extensions.worktreeConfig`), so a file hash equals the blob hash in every repository; a new
  test runs the channel on a CRLF checkout (`core.autocrlf true`).
- MUST M2: the conversation's allow-list (`Bash(git log:*)` etc.) was an arbitrary file write:
  `git log -1 --format=<text> --output=<file>`; an imported issue's text could ask for it. Fix:
  the file tools only (`Read,Grep,Glob`), no shell; spec FR-016, the clarification, the contract,
  the preamble and the README amended.
- SHOULD S1: `returning` without a loop left the flag; the next loop run would have held the edit
  lock for its whole duration. Fix: the no-loop path removes the flag; test adjusted.
- SHOULD S2: in the `commit` channel a change whose commit failed stayed pending with an error
  answer. Fix: the change is undone and the refusal says so.
- SHOULD S3 (accepted, documented): the primary-HEAD check before the swap is best effort for a
  manual run (no loop holds the lock at step 9); under the loop `returning` closes it. No data is
  lost in the bad case (the app's commit is on main; the run stops at step 10 with its reason).
- NOTE N1: the loop's pid for the never-stale rule came from a possibly stale view. Fix: a fresh
  poll before the lock is taken. N2-N5 recorded, not changed (N2: stale empty `specs/` folders in
  the worktree only hide a `feature-missing` finding that main's check would report - the loop's
  own check runs on main; N3: the frozen check covers `desc.md`, the only file the tool rewrites;
  N4: a stale client naming the frozen item gets `frozen-item` rather than `changed-underneath`;
  N5: `returning` for the item the loop runs makes the loop hold the lock until claude ends - that
  is the intended behaviour).
- The e2e `us1-live-edit` asserted main's head after the run; the loop's next run could already
  close the new item. It now asserts the order in the run's `merge main` commit.
