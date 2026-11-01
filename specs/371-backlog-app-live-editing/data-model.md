# Data model - 371

Shapes the app adds or changes (zod schemas in `packages/shared`). Everything of feature 344 that
is not named here stays as it is (`specs/344-backlog-web-app/data-model.md`).

## Write gate (changed)

```text
WriteGate
  state        free | run-starting | run-on-main | auto-triage | not-on-main |
               merge-in-progress | stale-lock | edit-in-progress | degraded
  writable     true only in free
  channel      tray | commit | main-ref | null        (null when not writable)
  frozenSlug   the item a run works on (the run lock's slug), else null
  reason       words for every disabled control / the banner
  checkClean, branch, headIsMain, dirtyOutsideBacklog   (as before)
```

States removed: `loop-between-runs`, `run-holds-lock` (both are writable now). New:
`run-starting` (the loop holds the edit lock: a run starts or returns to `main`) and
`run-on-main` (a run holds the run lock while the primary tree is on `main` and no loop holds
the edit lock - a manual run's start or end).

Decision table (first match wins):

| # | Condition | State | Channel | Frozen |
|---|---|---|---|---|
| 1 | no loop view or repo state yet | degraded | - | - |
| 2 | the backlog cannot be read | degraded | - | - |
| 3 | `MERGE_HEAD` exists | merge-in-progress | - | - |
| 4 | run lock stale and no live loop | stale-lock | - | - |
| 5 | live edit lock of another pid = the loop's pid | run-starting | - | lock slug or null |
| 6 | live edit lock of another pid | edit-in-progress | - | - |
| 7 | run lock held, HEAD is `main` | run-on-main | - | lock slug |
| 8 | run lock held, HEAD is not `main` | free | main-ref | lock slug |
| 9 | loop shown triage / kill-pending | auto-triage | - | - |
| 10 | HEAD is not `main` | not-on-main | - | - |
| 11 | interrupted run waiting (lock-less, phase not new, not needing a person) | free | commit | its slug |
| 12 | loop live | free | commit | - |
| 13 | otherwise | free | tray | - |

Row 11: a run interrupted and waiting to be continued holds its lock normally (then row 7/8);
without a lock its record names the item the next start continues - that item stays frozen.

## Change (tray entry, changed)

```text
Change (+)
  channel   tray | commit | main-ref      how it was applied
  state     pending | committed | undone  (committed at once for commit / main-ref)
  commit    the commit hash (set at once for commit / main-ref)
```

`ChangeResult` (the answer of a changing route) gains `channel` and `commit` (null in the tray
channel). The tray view gains `committedRecently: Change[]` (committed entries of the last hour,
newest first) so the drawer can show what the app committed at once.

## Running item overlay (new, derived)

```text
RunningItem
  slug       from the run lock
  branch     from the run lock (`-` until the run created it)
  feature    the NNN prefix of the branch, or null
  started    the lock's start (local time)
```

Applied to the board read from `main`: the row with `slug` is removed from its section and
inserted at *In progress* #1 with `status: in-progress` and `feature`; `NextUp` is computed
without it; `Item` of that slug gets `section: "In progress"`, `position: 1`, `status`,
`feature`. `Board.running: RunningItem | null` tells the client the overlay is on.

## Conversation (new)

```text
Conversation            chats/<slug>.json in the app's state folder
  slug                  the item
  sessionId             claude's session (UUID chosen by the app at the first message)
  createdAt, updatedAt  ISO
  costUsd               sum of the turns' costs
  turns                 Turn[] oldest first (at most 200 kept; older ones dropped from the file)

Turn
  id                    1-based number within the conversation
  at                    ISO start
  user                  the maintainer's message (text)
  assistant             the reply text so far
  progress              [{at, text}] tool uses and notes (at most 200)
  state                 running | done | failed | stopped
  error                 text when failed
  costUsd               the turn's cost when known
  endedAt               ISO
```

Rules: one running turn per slug; `send` while running → 409 `busy`; `reset` ends the process,
archives the file as `chats/<slug>.<stamp>.json` (pruned after 30 days) and starts a new
conversation; a conversation of a slug the board no longer knows is still readable (the item was
closed) but `send` refuses (`not-found`).

## Settings (changed)

```text
Settings (+)
  chatBudgetUsd   number 0.5 .. 50, default 5   the cap per conversation process
```

## Loop status (changed, `loop.py status --json`)

```text
edit_lock (+)
  holder   "loop" | "other" | null     "loop" when the pid is the live loop's pid
returning  true when the flag `returning` exists (a run is returning to main)
```

## Loop state files (changed)

- `.git/tandem-backlog-loop/returning` - one line: the slug and the time; written by
  `loop.py returning`, removed by the loop when claude ends (or by the next start).
- `.git/tandem-backlog-edit.lock` - unchanged format; may now be held by the loop
  (`purpose: loop: starting a run` / `loop: the run of <slug> returns to main`).

## App state folder (changed)

- `main-worktree/` - the sparse detached worktree of `main` (git's own files inside
  `.git/worktrees/main-worktree/`); recreated when missing; never committed on a branch.
- `chats/` - conversations.
