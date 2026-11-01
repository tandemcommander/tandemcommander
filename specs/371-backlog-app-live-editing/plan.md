# Implementation Plan: Backlog app revision - editing while a run is in progress

**Branch**: `371-backlog-app-live-editing` | **Date**: 2026-11-01 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/371-backlog-app-live-editing/spec.md`

## Summary

The backlog app becomes writable while the loop lives and while a run is in progress: changes
made during a run are applied by the backlog tool in a sparse side worktree of `main` and land on
`main` with a compare-and-swap, committed at once; the run picks them up at its end through the
existing merge recipe of the implement skill. The loop and the app never overlap: the loop holds
the app's edit lock while a run starts (until the run is on its branch) and while it returns to
`main` (a new `returning` command the skill calls at step 9). The item a run works on is frozen
and shown in *In progress* (an overlay of the board read from `main`). Positions get a typed
field and "Move to the top" (a reorder). Each item gets a conversation with Claude in a separate
full-page window (a kept `claude -p` process in bidirectional stream-json mode, read-only tools,
transcript per item on the server). The two time-dependent tests are fixed. Details and
measurements: [research.md](research.md).

## Technical Context

**Language/Version**: TypeScript 6.0 on Node 24 (type stripping, no parameter properties),
React 19, Python 3 (standard library) for `tools/backlog/backlog.py`, `loop.py` and the fakes
**Primary Dependencies**: Hono, zod, TanStack Router / Query / Table, Radix, Tailwind 4, dnd-kit,
eventsource-parser; Playwright 1.64 (Edge) and vitest 5 for tests - all already pinned in
`tools/backlog-app/package-lock.json`; no new dependency
**Storage**: the repository (git objects, `backlog/`), the app's state folder
`<git-common-dir>/tandem-backlog-app/` (tray, jobs, settings; new: `chats/`, `main-worktree/`),
the loop's folder `.git/tandem-backlog-loop/` (new flag `returning`)
**Testing**: vitest (unit, API, write path, race soak opt-in), Playwright e2e in Edge with the
fake claude of 247/344 and a hidden loop window, `tools/backlog/test_backlog.py` and
`test_loop.py` (unittest), ESLint jsdoc/tsdoc, prettier, `tsc`
**Target Platform**: Windows 11, local host only (127.0.0.1)
**Project Type**: web application (Node server + React client) inside the repository's tools
**Performance Goals**: a change during a run visible on `main` and in the board within 10 s
(SC-001); position change within 3 s (SC-004); first words of a reply within 30 s (SC-005)
**Constraints**: the app never writes a backlog file itself, never touches the loop's files, never
pushes; texts to tools only on stdin; the primary working tree is never touched while a run holds
the lock; the frozen item never changes; the gate decides from fresh state under the edit lock
**Scale/Scope**: one maintainer, ~500 items, runs of hours, 200 changes per soak

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. Build Reproducibility**: not touched (the app is a repository tool; `build.cmd` unchanged).
  Dependencies stay pinned; `npm ci` reproduces. PASS.
- **II. Backward Compatibility**: the product is not touched. The backlog tool's additions
  (`next --except`) and the loop's (`returning`, the edit-lock hold) are additive; older callers
  keep working; the edit lock keeps its format. PASS.
- **III. Incremental Modernization / IV. Windows commitment**: not applicable beyond the tool
  living on Windows (worktrees, process liveness as already solved in 344). PASS.
- **V. Plugin Architecture Preservation**: not touched. PASS.
- **VI. UI Consistency**: the app's own UI conventions (gate reasons at every disabled control,
  the top bar, the tray) are kept; new controls follow the existing dialogs and tables. PASS.
- **Release documentation**: no product change; no `CHANGELOG.md` entry (344 did not add one
  either); `specs/FEATURE-HISTORY.md` gets the entry; `PRIVACY.md` is not affected (no new
  network communication: claude is the same local tool as for the jobs). PASS.

Post-design re-check (after Phase 1): unchanged - no violation, no complexity to justify.

## Project Structure

### Documentation (this feature)

```text
specs/371-backlog-app-live-editing/
├── plan.md              # this file
├── research.md          # decisions R1-R11 with measurements
├── data-model.md        # write channels, gate, frozen item, conversation, tray entry
├── quickstart.md        # how to verify every story
├── contracts/
│   ├── http-api-additions.md   # new routes and changed answers
│   ├── loop-cli-additions.md   # loop.py: edit-lock hold, `returning`, status fields
│   ├── backlog-cli-additions.md # backlog.py: `next --except`
│   └── chat.md                  # the conversation: process, prompt, events, limits
├── fix-log.md           # running log of the work (project rule)
├── checklists/requirements.md
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
tools/backlog/
├── backlog.py                 # `next --except <slug>` (+ test_backlog.py)
├── loop.py                    # edit-lock hold at start, `returning` command and flag,
│                              #   status: edit_lock.holder (+ test_loop.py)
└── fixtures/fake_claude.py    # step `branch-hang` (a run on a branch that returns to main)

bin/backlog-loop.sh            # passes `returning` through (help text)
.claude/skills/tandem-backlog-implement/SKILL.md   # step 9: `bin/backlog-loop.sh returning`
.claude/skills/tandem-backlog/SKILL.md             # §0.2: the app may change the backlog during a run

tools/backlog-app/packages/shared/src/
├── schemas/app-state.ts       # WriteGate: channel, frozen; gate states run-on-main, run-starting;
│                              #   Change: channel; Settings: chatBudgetUsd
├── schemas/chat.ts            # Conversation, Turn, chat events (new)
├── api/requests.ts            # chat message / reset requests
└── api/events.ts              # `chat.changed`

tools/backlog-app/packages/server/src/
├── backlog/write-gate.ts      # the new decision table (pure, tested)
├── backlog/write-queue.ts     # channels; waits for a loop-held edit lock; frozen check
├── backlog/side-worktree.ts   # the sparse detached worktree of main; sync, commit, CAS (new)
├── backlog/tray.ts            # committed-at-once entries (channel, commit) and the one-change commit
├── backlog/read-model.ts      # the running-item overlay, `next --except`
├── backlog/tool.ts            # `--root` per call (worktree), `next(ref, except)`
├── api/backlog-write.ts       # answers carry channel/commit; frozen refusals
├── api/chat.ts                # routes of the conversation (new)
├── chat/service.ts            # the kept claude process, transcript, stream (new)
├── chat/context.ts            # the item context block (new)
├── ai/prompts/chat.md         # the conversation preamble (new)
└── services.ts                # wiring; source() unchanged

tools/backlog-app/packages/web/src/
├── app/layout.tsx             # bare layout for /items/$slug/chat
├── app/router.tsx             # chat route
├── features/gate/gate-banner.tsx      # new states and reasons; "committed at once" note
├── features/item/item-view.tsx        # position field, Move to the top, Chat button, frozen banner
├── features/item/item-actions.tsx     # frozen from the gate
├── features/backlog/section-table.tsx # editable position cell, row menu
├── features/backlog/sortable-section.tsx # position -> reorder
├── features/tray/tray-drawer.tsx      # committed-at-once entries
├── features/home/home-page.tsx        # In progress from the overlay (no change needed beyond data)
├── features/chat/chat-page.tsx        # the conversation page (new)
└── features/settings/settings-page.tsx # chat budget

tools/backlog-app/packages/server/test/
├── write-gate.test.ts         # the decision table
├── write-path.test.ts         # fixed dates; main-ref channel; frozen; CAS; commit channel
├── side-worktree.test.ts      # sync, commit, CAS failure, cleanup (new)
├── read-model.test.ts         # overlay (new or extended loop-view tests)
├── chat.test.ts               # with fixtures/fake-claude-chat.mjs (new)
├── ai-jobs.test.ts            # fixed dates
└── write-race.test.ts         # opt-in soak (new)

tools/backlog-app/e2e/
├── us1-live-edit.spec.ts      # change during a branch-hang run; In progress; next up (new)
├── us3-order.spec.ts          # position field, Move to the top
└── us4-chat.spec.ts           # the conversation window with the fake (new)
```

**Structure Decision**: the existing workspace layout of feature 344 (shared schemas, server
modules by concern, one web folder per page) is kept; new concerns get their own modules
(`backlog/side-worktree.ts`, `chat/`) and the loop/tool additions stay in the Python tools with
their own tests.

## Design notes (what the tasks implement)

1. **Gate decision table** (`write-gate.ts`, pure): inputs as today plus `loopPid`; outputs
   `state`, `writable`, `channel`, `frozenSlug`, `reason`. Order: degraded → merge → stale lock →
   edit lock (loop's pid → `run-starting`, other → `edit-in-progress`) → run lock (HEAD `main` →
   `run-on-main`; else `main-ref`, frozen = lock slug) → triage / kill-pending → not on main →
   loop live (`commit`) → `tray`. `pause-pending` / `stop-pending` are run states (lock held) and
   fall under the lock rule.
2. **Write queue**: take the edit lock (waiting up to 30 s while the loop holds it), fresh loop +
   repo, gate; `tray`/`commit`: as today in the primary tree, `commit` adds the one-change commit;
   `main-ref`: `SideWorktree.sync(mainCommit)`, revision check against the worktree's files, the
   tool with `--root <worktree>`, findings → revert + refuse, frozen check → revert + refuse,
   commit in the worktree, verify primary HEAD ≠ `main` and the edit lock still ours, CAS on
   `refs/heads/main`, failure → revert + `changed-underneath`; tray entry `committed` with
   `channel` and `commit`; read model `fresh()` (source `main` reloads on the new commit).
3. **Side worktree**: created lazily (`git worktree add --detach --no-checkout`, sparse set
   `backlog` `specs/*/spec.md`, checkout), repaired when missing or dirty (`git checkout --detach
   main`, `git reset --hard`, `git clean -fdx -- backlog`, `sparse-checkout reapply`), pruned at app
   start; never registered as a branch; `git worktree prune` when the folder is gone.
4. **Loop**: `cycle()` takes the edit lock before `precheck()` (replacing a stale one, waiting
   while a live app lock exists - today's `tree_state` "edit" wait), releases it on a non-ready
   precheck, keeps it through `execute()` until `watch()` sees the run lock with a branch other
   than `-` or claude ends; `pending()` (continued runs) holds it only while the lock's branch is
   `-`. The `returning` flag: `watch()` takes the edit lock when the flag appears (purpose "the run
   returns to main"), releases it and removes the flag when claude ends. `cmd_returning`: writes
   the flag (slug from the run lock), waits (max 300 s) until no live foreign edit lock exists
   and, if a loop is live, until the loop holds it; prints one line. `status --json`:
   `edit_lock.holder` = `loop` when the pid is the live loop's.
5. **Overlay** (`read-model.ts`): after loading from `main` with a lock held: find the row of the
   lock's slug in any section, remove it, insert into *In progress* with `status: in-progress`,
   `feature` = `^\d{3}` of the lock's branch (or null), position 1; `next` = tool `next --except
   <slug>`; `show` of that slug gets `section: In progress`, `position: 1`, `status`, `feature`.
   The overlay is recomputed when the lock changes (loop view change → `reconcile` → invalidate).
6. **Positions**: `PositionField` (web) used in the item header and the table cell; computes the
   new order from the full section order and posts `/sections/:s/order` with the board revision;
   "Move to the top" = position 1. Disabled with the gate reason / frozen / unordered / In progress.
7. **Chat**: `ChatService` keeps `Map<slug, Conversation>` loaded from `chats/<slug>.json`; a
   `LiveChat` per slug (process, current turn, idle timer 10 min); `send(slug, text)` → 409 when
   a turn runs; the first message of a conversation carries the context block (from
   `chat/context.ts`: item `show`, journal rows of the slug from `RUNS.md`, run ids of the slug,
   feature records folder if any, related/dependents, the working tree's branch); stream parsing:
   `stream_event` text deltas → `assistant` text, `assistant` tool_use → progress line, `result` →
   turn done (cost, session id); `stop(slug)` kills the process tree (the turn ends `stopped`, the
   next message resumes the session); `reset(slug)` ends the process and starts an empty
   conversation (the old file is kept as `chats/<slug>.<stamp>.json` for 30 days). Events:
   `chat.changed` (slug, turn id, state) on the app stream; `GET /api/items/:slug/chat/stream`
   sends the running turn's deltas (`delta`, `progress`, `done`, `failed`) with resume by event id.
8. **Layout**: `Layout` renders only the providers and the outlet when the route is the chat page
   (`useRouterState` pathname matches `/items/<slug>/chat`); the item page's "Chat about this
   item" is an `<a target="_blank">` to that address (the session token is in local storage, so
   the new window is signed in).
9. **Fixtures**: `fake_claude.py` step `branch-hang`; `test/fixtures/fake-claude-chat.mjs`
   (reads stream-json lines on stdin, answers with partial deltas, a tool-use line and a `result`,
   honours `--resume`/`--session-id` by echoing the id, exits on stdin end); lock dates via a
   helper.

## Complexity Tracking

No constitution violation; nothing to justify.
