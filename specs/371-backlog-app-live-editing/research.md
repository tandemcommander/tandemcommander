# Research - 371 backlog app revision: editing while a run is in progress

Measured on 2026-11-01 on `main` at `f46caca4` (Node 24.19.0, npm 11.17.0, claude 2.1.316,
git worktrees of the repository: the primary and six detached review trees).

## R1 - Where a change made during a run is written

**Decision**: into a **sparse, detached, persistent side worktree of `main`** kept by the app at
`<git-common-dir>/tandem-backlog-app/main-worktree/` (sparse patterns `backlog` and
`specs/*/spec.md`, so every `specs/NNN-*` folder exists for the tool's `feature-missing` rule
without its contents). Before every change the app brings it to `main` (`git checkout --detach
main`, `git sparse-checkout reapply`, a clean check), runs the backlog tool with `--root` at the
worktree, verifies the result, commits there (detached HEAD) and moves `main` with a
compare-and-swap (`git update-ref refs/heads/main <new> <old>`). The primary working tree (the
run's) is never touched.

**Measured**: `git worktree add --detach --no-checkout` 0.06 s; sparse checkout of `backlog` +
all of `specs/*/` 1.5 s and 67 MB (too much for folder names only); `backlog` + `tools/backlog`
0.6 s and 2.6 MB; `board --json`, `check` (TOTAL: 0) and `lock status` (finds the common
directory's lock) work against the worktree root; a commit on the detached HEAD and a ref update
to a side ref work; a worktree inside `.git/tandem-backlog-app/` is accepted by git.

**Rationale**: the tool must run on real files (it owns the format and its 18 rules), the run's
tree is off limits (analysis A2 §5.1 of feature 344, and a change there would land in the run's
commit), and the run flow already merges a moved `main` at its end (skill step 9, the backlog
recipe keeps the maintainer's order). A detached HEAD never collides with the primary tree's
`git checkout main` ("already checked out" would fail the run's step 9).

**Alternatives**: git plumbing with a temporary index (the tool cannot run on it); a full
worktree (67 MB, 1.5 s per sync, for nothing); writing into the run's tree (forbidden); queueing
changes until the run ends (rejected in clarification: the maintainer would act later on a backlog
they no longer see).

## R2 - When the main line may be moved under a run

**Decision**: only while the primary working tree's HEAD is **not** `main`. Moving `main` while
the primary tree has `main` checked out would make the run's tree look modified (its files are
the old `main`), and the run's next `git add -A` would commit a reversal of the app's change.
The app checks the primary HEAD under the edit lock immediately before the ref update, and the
two windows in which a run is on `main` are closed deterministically by the loop (R3): the start
of a run (preconditions, selection, measurements and the specification happen on `main` until
step 4.5 writes the branch into the run lock) and its return (step 9). In these windows the gate
is read-only with the reason (`run-on-main`), and the banner opens again as soon as the run is on
its branch (the gate is pushed to every tab).

**Rationale**: the measurement window can last minutes (builds, probes) and is the only part of
a run the app cannot write around; a clear reason beats a queue (clarification Q4).

## R3 - The loop and the app never overlap

**Decision**: the loop holds the app's **edit lock** itself in the two windows of R2, and the
app's write queue honours a lock held by the loop as it honours one of another app instance:

- before its precheck the loop takes the edit lock (`purpose: loop: starting a run`); it keeps it
  through the selection and the start of claude until the run lock shows a branch (step 4.5), or
  the run ends; a precheck that does not lead to a run releases it at once;
- at step 9 the run calls `bin/backlog-loop.sh returning` (new): it waits while a live app edit
  lock exists (an app change in progress), writes the flag `returning`, and - when a loop lives -
  waits until the loop holds the edit lock (`purpose: loop: the run returns to main`); the loop
  releases it when claude ends. Without a loop (a manual run) the command only waits for the
  app's lock, and the app's HEAD check (R2) remains the guard.

The edit lock keeps its format (`pid`, `started_epoch`, `started`, `purpose`); liveness stays the
loop's rule (pid + process creation time). The app treats a lock whose pid is the loop's pid as
`run-on-main`, any other live pid as `edit-in-progress`; its write queue waits up to 30 s for a
loop-held lock before refusing with the purpose.

**Measured**: the loop's `tree_state` already checks the edit lock first; `status --json` already
reports `edit_lock` (feature 344). The skill's step 9 is a numbered command block; adding one
command there is the same kind of change as the `.slt` refresh of 2026-10-23.

**Alternatives**: a `reference-transaction` git hook installed by the app (would serialise every
git ref change against the lock without touching the skill, but installs a hook into the
maintainer's `.git/hooks`, and whether a bare `git checkout <branch>` fires it is not certain);
suspending claude (the loop's stall watchdog would kill it; API calls time out) - rejected.

## R4 - Commits while the loop lives

**Decision**: while a loop lives or a run holds the run lock, every change is committed at once,
one commit per change, message `backlog(app): <summary>` with the change's body line
(prefix kept: `traces.py` attributes commits by `[NNN]` / `backlog: ` prefixes, analysis A1 §7 of
344). Three write channels, decided by the gate from fresh state under the edit lock:

| Channel | When | Where the tool runs | Afterwards |
|---|---|---|---|
| `tray` | no loop lives, HEAD `main`, lock free | primary tree | pending in the tray (undo, commit later) - as today |
| `commit` | loop lives, lock free, HEAD `main` | primary tree | committed at once on `main` |
| `main-ref` | lock held, HEAD not `main` | side worktree | committed there, `main` moved by compare-and-swap |

A change whose check has findings is **reverted and refused** in the two committing channels
(nothing is committed; the findings are the answer) - a backlog with findings would hold the loop
("check reports N findings") and could not be merged by the recipe. In the tray channel the
behaviour stays (the change is pending with its findings).

**Rationale**: clarification Q1; the loop's precheck needs a clean tree and the run's merge needs
commits. The tray's undo is unavailable for committed changes (a counter-change instead).

## R5 - The running item is frozen

**Decision**: the item named by the run lock is the **frozen item**: its own changes are refused
in the API (not only disabled in the UI), bulk changes skip it with a refusal, reorders may not
move it (it is not in the ordered section any more, see R6), and after every `main-ref` change
the app verifies that `backlog/items/<frozen>/desc.md` is byte-identical to `main`'s before the
commit; a difference reverts the worktree and refuses (`frozen-item`). Skill step 9's guard
(`git diff <merge-base> main -- backlog/items/<SLUG>` must print nothing) is thereby never
tripped by the app.

**Measured**: `remove` and `move` to Inbox rewrite other items' `related` / `depends-on` lists
(backlog.py `remove_item`), so an indirect change of the frozen item is possible and must be
caught after the tool ran, before the commit.

## R6 - Showing the running item as in progress

**Decision**: the read model overlays the board read from `main` with the run lock: the frozen
item's row moves to *In progress* (status `in-progress`, feature = the `NNN` prefix of the lock's
branch, the lock's start), it is removed from its section, "next up" is recomputed with the tool's
new `next --except <slug>` (one small addition, tested), and the item detail gets `section`
*In progress* and the lock's data. The overlay is applied only while a lock is held; the board's
`revision` stays `main`'s file hash (changes are checked against `main`'s file in the side
worktree).

**Rationale**: on `main` the item is `open` by design (R10 of 344); the maintainer must still see
what runs. The tool's `board --ref main` stays unchanged.

## R7 - Positions

**Decision**: a typed position and "Move to the top" send the existing `reorder` of the whole
section (computed from the board's own order, not from the filtered or sorted view), like a drag:
no log line per step (clarification Q2). Controls: on the item page (header, ordered sections
only) and in the section tables (the position cell is editable; a row menu entry "Move to the
top"). Keyboard: Enter confirms, Escape cancels. In the `main-ref` channel the order is `main`'s.

## R8 - A conversation with Claude about an item

**Decision**: one claude process per open conversation, started with `-p --input-format
stream-json --output-format stream-json --verbose --include-partial-messages`, the maintainer's
messages written to its stdin as `{"type":"user","message":{"role":"user","content":...}}`; the
process stays alive between turns and is ended after 10 minutes without a message or when the
maintainer starts a new conversation; a later message restarts it with `--resume <session-id>`
(session persistence on - unlike the one-shot jobs). Tools: `--tools Read,Grep,Glob,Bash` with
`--allowedTools Read Grep Glob "Bash(git log:*)" "Bash(git show:*)" "Bash(git diff:*)"
"Bash(git blame:*)" "Bash(git rev-parse:*)"` and `--permission-mode default`: in print mode a tool
outside the allow-list is denied without a prompt. Budget: `--max-budget-usd` per process from a
new setting `chatBudgetUsd` (default 5). The first message carries the item context as data
(description, journal rows, runs, feature records, related items, the branch of the working tree)
and the rules of the `ask` prompt; a new preamble `prompts/chat.md`.

**Measured** (haiku, two trivial turns): the process answered turn 1 in 3.9 s and turn 2 in
3.8 s with the context kept ("PING 2"), stayed alive between turns, ended cleanly at stdin close
(exit 0), cost 0.076 USD for both turns; a new process with `--resume <id>` answered from the
earlier context in 4.1 s. Every turn ends with a `result` event carrying `session_id`,
`total_cost_usd` and the text; `--include-partial-messages` adds `stream_event` lines with text
deltas for streaming.

**Rationale**: a kept process makes follow-up turns fast and keeps the context without a resume
per turn; the transcript on the server (`chats/<slug>.json`) survives restarts; read-only tools
keep FR-016; the rules of feature 344's jobs (no user text on the command line, identifiers from
the tool's listing, state folder) apply unchanged.

**Alternatives**: a `claude -p` per turn with `--resume` (works, 2-4 s slower per turn, simpler
life cycle - kept as the fallback path after the idle end); the one-shot job runner (no
transcript, structured output only).

## R9 - The two failing tests

**Finding**: `write-path.test.ts` and `ai-jobs.test.ts` write a run lock dated
`2026-10-30T10:00:00`; since 2026-10-31 10:00 it is older than the tool's 24-hour stale rule and
the gate says `stale-lock`. Fix: the fixtures write the current time (a helper `lockNow()`), and
a negative control keeps one test with a lock dated 25 hours ago expecting `stale-lock`.

## R10 - What the end-to-end fake run must do

**Decision**: a new step `branch-hang` of `fake_claude.py`: `BL lock acquire`, `BL start`,
`git checkout -b <feature>-<slug>`, `BL lock update --branch`, the start commit, a wait of the
configured seconds (the app changes `main` meanwhile), then the close and the return exactly as
the skill's step 9 does it: `bin/backlog-loop.sh returning`, `git checkout main`,
`git merge --ff-only`; on failure the backlog recipe (checkout `main`'s `BACKLOG.md` and item,
`BL remove --force`, `BL sync`, commit `[NNN] merge main`) and the fast-forward again. The step
also records whether the fast-forward succeeded at once, so the tests can assert the recipe ran.

## R11 - Soak and the race measurements

**Decision**: a vitest file `write-race.test.ts` (opt-in through `BACKLOG_APP_SOAK=1`, run in
this feature's closing) drives a real loop (`--tick 0.05`) with the fake claude while the test app
makes 200 changes; it asserts that every change is on `main`, that no run started on a backlog
with uncommitted files (the fake claude records `git status --porcelain` at its start), and that
no change was lost over 20 `branch-hang` runs with 3 changes each (SC-002, SC-007).
