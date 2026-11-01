# Tasks: Backlog app revision - editing while a run is in progress

**Input**: Design documents from `/specs/371-backlog-app-live-editing/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: requested by the specification (US5, FR-021, SC-006, SC-007): every story has its
tests; they are written with the implementation of the story and must pass before the story is
checked off.

**Organization**: by user story; US1 and US2 share the gate / channel foundation of Phase 2.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependencies on an unfinished task)
- **[Story]**: US1 (edit during a run), US2 (running item shown), US3 (positions), US4 (chat),
  US5 (revision)

## Path Conventions

Repository root `E:\Projects\tandemcommander`; the app is `tools/backlog-app/` (workspaces
`packages/shared`, `packages/server`, `packages/web`; tests in `packages/server/test`, e2e in
`e2e/`); the Python tools are `tools/backlog/`.

---

## Phase 1: Setup

**Purpose**: fixtures and tools every story builds on.

- [x] T001 Fix the time-dependent lock fixtures: a helper `lockNow(ageHours = 0)` in
      `tools/backlog-app/packages/server/test/helpers/fixture-repo.ts`; use it in
      `packages/server/test/write-path.test.ts` and `packages/server/test/ai-jobs.test.ts`; keep one
      negative control with a 25-hour-old lock expecting `stale-lock` (research R9; FR-021)
- [x] T002 [P] Add `next --except <slug>` to `tools/backlog/backlog.py` (`cmd_next`, `build_parser`,
      refusal with `--slug`) and its three tests in `tools/backlog/test_backlog.py`
      (contracts/backlog-cli-additions.md)
- [x] T003 [P] Add the fake run step `branch-hang` to `tools/backlog/fixtures/fake_claude.py`: lock,
      `BL start`, `git checkout -b`, `lock update --branch`, start commit, wait `seconds`, close,
      `returning` (through `loop.py`), `git checkout main`, `git merge --ff-only`, on failure the
      backlog recipe and `[NNN] merge main`, then the fast-forward; record in the plan's `calls`
      whether the first fast-forward succeeded and `git status --porcelain` at the start
      (research R10)
- [x] T004 [P] Create the chat fake `tools/backlog-app/packages/server/test/fixtures/fake-claude-chat.mjs`:
      reads stream-json lines from stdin, prints `system/init` with the session id from
      `--session-id` / `--resume`, answers each user message with three `stream_event` text deltas,
      one `assistant` tool-use line and a `result` (success, cost 0.01); modes through
      `FAKE_CHAT_MODE` (`ok`, `budget`, `crash`, `slow`); exits at stdin end (contracts/chat.md)

---

## Phase 2: Foundational (blocking)

**Purpose**: the loop's edit-lock holds and the app's write channels; without them neither US1 nor
US2 can be tested safely.

- [x] T005 Loop: take the edit lock before `precheck()` in `Loop.cycle()`, release it on a non-ready
      precheck, keep it through `execute()` until `watch()` sees the run lock's `branch != '-'` or
      claude ends; `pending()` holds it only while the branch is `-`; release on every exit path
      (`tools/backlog/loop.py`; contracts/loop-cli-additions.md)
- [x] T006 Loop: the `returning` flag and command - `cmd_returning` (writes the flag, waits for a
      foreign edit lock to clear, then for the loop's hold, prints `ok`/`refused`, `--timeout`),
      `watch()` takes the lock on the flag and removes the flag when claude ends, `start` removes a
      leftover; `status --json` adds `edit_lock.holder` and `returning` (`tools/backlog/loop.py`)
- [x] T007 Loop tests in `tools/backlog/test_loop.py`: the hold from precheck to the branch (fake
      `branch-hang`), the wait on an app lock with no run started meanwhile, `returning` (ok,
      timeout, no loop), the flag removed at claude's end and at the next start (depends on T003,
      T005, T006)
- [x] T008 [P] `bin/backlog-loop.sh`: list `returning` in `--help` and pass it through; run
      `python tools/test_bin_help.py`
- [x] T009 [P] Shared schemas: `WriteGate` (`state` set, `channel`, `frozenSlug`), `Change.channel`,
      `ChangeResult.channel/commit`, `Tray.committedRecently`, `Board.running`, `Settings.chatBudgetUsd`
      in `tools/backlog-app/packages/shared/src/schemas/app-state.ts`, `backlog.ts`, `api/responses.ts`
      (data-model.md)
- [x] T010 Gate decision table in `tools/backlog-app/packages/server/src/backlog/write-gate.ts` (pure):
      inputs + `loopPid`; the 13 rows of data-model.md; reasons in words for every state (depends
      on T009)
- [x] T011 Gate tests: one case per row of the table plus the frozen slug and the channel in
      `tools/backlog-app/packages/server/test/write-gate.test.ts` (depends on T010)
- [x] T012 Side worktree `tools/backlog-app/packages/server/src/backlog/side-worktree.ts`: create lazily
      (`worktree add --detach --no-checkout`, sparse `backlog` + `specs/*/spec.md`, checkout),
      `sync(mainCommit)` (detach to main, reset --hard, clean backlog, sparse reapply, clean check),
      `commit(paths, message)`, `landOnMain(expectedOld)` (CAS `update-ref`), `revert()`, `prune()` at
      app start; git calls through a small allow-list of its own (write commands are allowed here
      only) (research R1, R2)
- [x] T013 Side worktree tests `tools/backlog-app/packages/server/test/side-worktree.test.ts`: creation,
      sync after main moved, commit + CAS, CAS failure when main moved (reverted), a dirty worktree
      repaired, the folder deleted and recreated (depends on T012)
- [x] T014 Backlog tool adapter: `change(args, texts, { root })` and `next(ref, except)` in
      `tools/backlog-app/packages/server/src/backlog/tool.ts` (depends on T002)
- [x] T015 Write queue channels in `tools/backlog-app/packages/server/src/backlog/write-queue.ts`:
      wait up to 30 s for a loop-held edit lock (`busy` with the purpose after), gate from fresh
      state, `tray` (as today), `commit` (tool in the primary tree + the one-change commit),
      `main-ref` (sync the worktree, revision check against its files, the tool with `--root`,
      findings → revert + `check-findings`, frozen check → revert + `frozen-item`, commit, primary
      HEAD check + edit lock still ours, CAS, failure → revert + `changed-underneath`), tray entry
      with channel and commit, `read.fresh()` (depends on T010, T012, T014)
- [x] T016 Tray: `record()` takes `channel` and `commit`; `commitOne(change, message)` for the commit
      channel; `view()` adds `committedRecently`; the proposed message for one change
      (`tools/backlog-app/packages/server/src/backlog/tray.ts`) (depends on T009)
- [x] T017 Services wiring: `gate()` passes the loop pid; `reconcile()` invalidates the read model when
      the lock's slug or branch changes; `stopAndDrain()` ends chats (placeholder for T037); worktree
      prune at start (`tools/backlog-app/packages/server/src/services.ts`, `main.ts`) (depends on
      T012, T015)
- [x] T018 Changing routes return `channel` / `commit`, refuse the frozen slug before the queue for
      `/items/:slug/*`, `/bulk` skips it with a refusal, `/sections/:s/order` refuses an order that
      names it (`tools/backlog-app/packages/server/src/api/backlog-write.ts`) (depends on T015)
- [x] T019 Write-path tests in `tools/backlog-app/packages/server/test/write-path.test.ts`: the
      `commit` channel commits at once with the app's message; the `main-ref` channel (a fixture
      with the run lock held and HEAD on a branch): the change is on `main`, the primary tree
      untouched, the tray entry committed; `run-on-main` refusal when HEAD is `main`; the frozen
      item's own change and the indirect change (close of an item naming it) both refused with
      nothing written; `changed-underneath` when `main` moved; a change with findings reverted
      (depends on T015, T016, T018)

**Checkpoint**: the loop and the app serialise; changes land on `main` during a simulated run.

---

## Phase 3: User Story 1 - Change the backlog while a run is in progress (Priority: P1) 🎯 MVP

**Goal**: every change works while the loop lives or a run holds the lock; nothing is lost; the
run is never disturbed.

**Independent Test**: quickstart Q1, Q2, Q4, Q5, Q8; e2e `us1-live-edit.spec.ts`; soak
`write-race.test.ts`.

- [x] T020 [US1] Skill step 9: `bin/backlog-loop.sh returning` before `git checkout main` with one
      sentence why, in `.claude/skills/tandem-backlog-implement/SKILL.md`; §0.2 of
      `.claude/skills/tandem-backlog/SKILL.md` says the app changes `main` during a run and what
      stays frozen
- [x] T021 [P] [US1] Gate banner and reasons in
      `tools/backlog-app/packages/web/src/features/gate/gate-banner.tsx`: `run-starting`,
      `run-on-main`, the "changes land on main and are committed at once" note for the `commit` /
      `main-ref` channels, `useWriteAccess()` exposes `channel` and `frozenSlug`
- [x] T022 [P] [US1] Item actions and dialogs use `frozenSlug` from the gate (not the loop's slug)
      in `tools/backlog-app/packages/web/src/features/item/item-actions.tsx` and
      `features/backlog/bulk-actions.tsx` (marked rows exclude the frozen item)
- [x] T023 [P] [US1] Tray drawer shows committed-at-once entries with their commit and no undo, and
      the counter in the top bar counts pending only
      (`tools/backlog-app/packages/web/src/features/tray/tray-drawer.tsx`, `app/layout.tsx`)
- [x] T024 [P] [US1] Loop page and top bar: pause / resume tooltips no longer promise "to change the
      backlog"; the start dialog's "commit the tray" step stays
      (`tools/backlog-app/packages/web/src/features/loop/loop-status.tsx`, `loop-page.tsx`)
- [x] T025 [US1] E2E `tools/backlog-app/e2e/us1-live-edit.spec.ts`: a `branch-hang` run of 40 s; add an
      item placed at Next #1 through the UI, reorder, block another item; assert `main` holds them
      within 10 s and the run's status is unchanged; the frozen item's page is read-only; close of
      an item naming the frozen one refused; after the run: both the close and the changes on
      `main`, the recipe ran (the fake's record), the loop's next run takes the new item (depends on
      T003, T019, T021, T022)
- [ ] T026 [US1] Soak `tools/backlog-app/packages/server/test/write-race.test.ts` (opt-in
      `BACKLOG_APP_SOAK=1`): 200 changes against a loop at `--tick 0.05` with fake `close` runs,
      0 lost, 0 runs started on a dirty tree; 20 `branch-hang` runs x 3 changes, 0 lost (SC-002,
      SC-007); record the numbers in `specs/371-backlog-app-live-editing/fix-log.md`

**Checkpoint**: US1 works end to end on fixtures.

---

## Phase 4: User Story 2 - The running item is shown as in progress (Priority: P1)

**Goal**: the board, Home, the sidebar and the item page show the running item in *In progress*;
"next up" excludes it.

**Independent Test**: quickstart Q1, Q3; API tests of the overlay; e2e assertions in
`us1-live-edit.spec.ts`.

- [x] T027 [US2] Running-item overlay in
      `tools/backlog-app/packages/server/src/backlog/read-model.ts`: `runningOf(loopView)`; the row
      moved to *In progress* with status / feature / position; `next --except`; `Board.running`;
      the item detail of that slug (`api/backlog-read.ts`) gets section, position, status, feature
      (depends on T014, T017)
- [x] T028 [US2] Overlay tests in `tools/backlog-app/packages/server/test/read-model.test.ts`: with a
      lock held the row is in *In progress* and not in *Next*, counts follow, next-up names the
      next eligible item, `show` of the slug says *In progress*; without a lock the board is `main`'s
      (depends on T027)
- [x] T029 [P] [US2] Item page: a banner "in progress - feature NNN, run started …, live run" for
      the running item, the Runs tab links the live run
      (`tools/backlog-app/packages/web/src/features/item/item-view.tsx`)
- [x] T030 [P] [US2] Home: "Next up" and the sections come from the overlaid board (no code change
      beyond reading `board.running` for the "Live run" line); the sidebar counts follow
      (`tools/backlog-app/packages/web/src/features/home/home-page.tsx`, `app/layout.tsx`)
- [x] T031 [US2] E2E assertions in `tools/backlog-app/e2e/us1-live-edit.spec.ts`: Home shows
      *In progress* 1 with the item, Next without it, "Next up" another item; after the run
      *In progress* is empty (depends on T025, T027)

**Checkpoint**: US1 + US2 together are the MVP.

---

## Phase 5: User Story 3 - Set a position directly and move to the top (Priority: P2)

**Goal**: a typed position and "Move to the top" on the item page and in the section tables.

**Independent Test**: quickstart Q6; e2e `us3-order.spec.ts`.

- [x] T032 [US3] `PositionField` component in
      `tools/backlog-app/packages/web/src/features/backlog/position-field.tsx`: number input (Enter
      confirms, Escape cancels, hint on invalid input, larger than the section = last), "Move to the
      top" button, computes the order from the full section and posts `/sections/:s/order` with the
      board revision; disabled with the gate reason, for the frozen item, *In progress* and unordered
      sections
- [x] T033 [US3] Item page header uses `PositionField` for ordered sections
      (`tools/backlog-app/packages/web/src/features/item/item-view.tsx`) (depends on T032)
- [x] T034 [US3] Section table: the position cell opens the field on click / Enter, a row menu entry
      "Move to the top"; works under a filter or a column sort by using the board's own order
      (`tools/backlog-app/packages/web/src/features/backlog/section-table.tsx`,
      `sortable-section.tsx`) (depends on T032)
- [x] T035 [US3] E2E in `tools/backlog-app/e2e/us3-order.spec.ts`: type a position on the item page
      (#2 → #4 of the fixture's Next), "Move to the top", the table cell under a column sort, invalid
      input refused; the order verified through the tool (depends on T033, T034)

---

## Phase 6: User Story 4 - A conversation with Claude Code about one item (Priority: P2)

**Goal**: a full-page conversation window per item, streaming replies, a kept transcript.

**Independent Test**: quickstart Q7; API tests with the chat fake; e2e `us4-chat.spec.ts`.

- [x] T036 [P] [US4] Chat schemas (`Conversation`, `Turn`, `ChatContext`, requests, the event
      `chat.changed` and the stream events) in `tools/backlog-app/packages/shared/src/schemas/chat.ts`,
      `api/requests.ts`, `api/events.ts`, `index.ts`
- [x] T037 [US4] `ChatService` in `tools/backlog-app/packages/server/src/chat/service.ts`: conversations
      from `chats/<slug>.json`, the kept process (`claudeCommand()` reuse, the arguments of
      contracts/chat.md, `--session-id` / `--resume`), `send` (context block on the first message),
      stream parsing (deltas, tool uses, rate limit, result), `stop`, `reset` (archive), idle end
      after 10 min, 15-min turn limit, at most 5 live processes, shutdown; publishes `chat.changed`
      (depends on T036)
- [x] T038 [P] [US4] Context block builder `tools/backlog-app/packages/server/src/chat/context.ts`
      (item `show`, journal rows of the slug, runs of the slug from `RunsService`, feature folder,
      traces, related/dependents, branch) and the preamble
      `tools/backlog-app/packages/server/src/ai/prompts/chat.md` (role, where things are, rules,
      read-only)
- [x] T039 [US4] Routes in `tools/backlog-app/packages/server/src/api/chat.ts` (GET chat, GET context,
      POST messages, POST stop, POST reset, GET stream with `Last-Event-ID`); mounted in `api/app.ts`;
      the gate test of 344 lists the new routes (`test/gate.test.ts`); settings `chatBudgetUsd`
      (`settings/store.ts`) (depends on T037, T038)
- [x] T040 [US4] Chat tests `tools/backlog-app/packages/server/test/chat.test.ts` with the fake: a turn
      streams deltas and ends done with the cost; the second message reuses the process; after
      `reset` a new session id; after the idle end (short timeout in the test) the next message
      resumes with `--resume`; `busy` while a turn runs; `stop` ends the turn `stopped`; a crash
      ends it `failed` with the transcript kept; the context block is on stdin and names the item's
      data, never on the command line (depends on T004, T039)
- [x] T041 [P] [US4] Chat page `tools/backlog-app/packages/web/src/features/chat/chat-page.tsx`: the
      essentials header (ChatContext), the transcript (Markdown replies, progress lines collapsed),
      the composer (Enter sends, Shift+Enter newline), Stop, New conversation, cost, "Claude only
      reads" note, error states (tool missing, failed turn); subscribes to the stream and
      `chat.changed`
- [x] T042 [US4] Route `/items/$slug/chat` without the frame: `app/router.tsx`, `app/layout.tsx`
      (bare layout by pathname); the item page's "Chat about this item" opens it in a new window
      (`features/item/item-view.tsx`); the item page shows "a reply is being written" from
      `chat.changed` (depends on T041)
- [x] T043 [P] [US4] Settings page: the chat budget field
      (`tools/backlog-app/packages/web/src/features/settings/settings-page.tsx`)
- [x] T044 [US4] E2E `tools/backlog-app/e2e/us4-chat.spec.ts` with the fake: the window has no
      sidebar and shows the essentials (viewport 1920 x 1080: the header's bottom edge is within the
      viewport, SC-005); a message streams a reply; reload keeps it; New conversation empties it;
      axe check of the page (depends on T042)

---

## Phase 7: User Story 5 - The app's parts work (revision) (Priority: P3)

**Goal**: every check passes on any day; every page used on a copy of the real repository.

**Independent Test**: `npm run check`, `npm run test:e2e`, quickstart by hand.

- [ ] T045 [US5] Browse every page of the app on a copy of the real repository (`--root <copy>`,
      Chrome): Home, every section, item, triage, new item, loop, live, runs, run, features,
      release, ask, check, settings, closed; fix what fails inside this feature, record the rest
      with evidence as Inbox items (`/tandem-backlog add`, source `review:371`); log in
      `specs/371-backlog-app-live-editing/fix-log.md`
- [ ] T046 [US5] Review `specs/344-backlog-web-app/contracts/http-api.md` and `security.md` against the
      new routes; update the app's `README.md` rules (changes during a run, the side worktree, the
      chat) and `architecture/12-project-reference.md` where it describes the app's gate

---

## Phase 8: Polish & Cross-Cutting

- [ ] T047 `npm run check` and `npm run test:e2e` green; `python tools/backlog/test_backlog.py`,
      `test_loop.py`, `tools/test_bin_help.py` green; `python tools/check_encoding.py --strict`
      TOTAL: 0 (the app's files are out of its scope; the skills and tools are not)
- [x] T048 Independent refute-first review of the finished change (an agent; the project rule): the
      write channels, the loop's holds, the frozen check, the chat's tool allow-list; fix the
      findings; record them in `specs/371-backlog-app-live-editing/fix-log.md`
- [ ] T049 Closing: `specs/FEATURE-HISTORY.md` entry (traps, evidence, numbers), the closing report
      `specs/371-backlog-app-live-editing/closing-report.md`, `CLAUDE.md` *Standing rules* one line if
      a rule emerged (the primary tree is never touched while a run holds the lock; the loop holds
      the edit lock while a run starts or returns)

---

## Dependencies & Execution Order

- Phase 1 (T001-T004) → Phase 2 (T005-T019) → US1 (T020-T026) and US2 (T027-T031) → US3, US4
  (independent of each other, both after Phase 2 for the gate's `frozenSlug`; US4 needs only T009
  of Phase 2) → US5 → Polish.
- Inside Phase 2: T005/T006 → T007; T009 → T010 → T011; T012 → T013; T002 → T014; T010 + T012 +
  T014 → T015 → T017, T018 → T019.
- US4 can start right after T004 and T009 (its server side does not depend on the channels).

## Parallel Execution Examples

- Phase 1: T002, T003, T004 at once (three tools, three files); T001 alone first (it changes the
  shared fixture helper).
- Phase 2: T005+T006 (loop) in parallel with T009→T010 (schemas, gate) and T012 (worktree).
- US1: T021, T022, T023, T024 at once (four web files), then T025.
- US4: T036 → (T037, T038, T041, T043 at once) → T039 → T040, T042 → T044.

## Implementation Strategy

1. MVP = Phase 1 + Phase 2 + US1 + US2: the maintainer can change the backlog during a run and
   sees the running item. Verify with quickstart Q1-Q5, Q8 and the e2e before going on.
2. US3 (small, web only) and US4 (server + web, independent) next.
3. US5 and the polish close the feature: review, soak numbers, history entry.
