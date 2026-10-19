# Feature 247 — a loop over `/tandem-backlog-implement`

**Input**: the maintainer, 2026-10-19 (consultation in Czech, summarised here):
`/tandem-backlog-implement` takes one item and ends. Run it in a loop so that
item after item is implemented without a person; the runs keep adding items to
*Inbox*, the maintainer triages them and opens them for implementation. The
loop must be stoppable at any time; scripts in Git Bash (`tools/backlog/*.sh`)
so that nothing has to be remembered; it must survive the usage limits (the
five-hour and the weekly one) and continue by itself once they reset.

## Decisions (from the consultation)

| # | Decision | Why |
|---|---|---|
| D1 | One **fresh `claude -p` process per item**, not `/loop` inside one session | an item fills a large part of a context (Spec Kit flow, builds, probes, review); a fresh process starts clean, has its own log, and the skill's contract is "one item, then end" |
| D2 | Five scripts in `tools/backlog/`: `loop-start.sh`, `loop-pause.sh`, `loop-resume.sh`, `loop-stop.sh`, `loop-status.sh` | the maintainer works in Git Bash; one script per action, nothing to remember (Tab completes `loop-`) |
| D3 | The scripts are one-line wrappers of `tools/backlog/loop.py` | one source of truth for the control files, liveness and the run logic; testable with `unittest` like `backlog.py`; real process control (kill a tree, Ctrl+Break) on Windows |
| D4 | **pause** = finish the running item, then wait for `resume`; **stop** = finish the running item, then end; **Ctrl+C** = hard stop (kills the running `claude` and its tree) | a running item is never cut by pause/stop; Ctrl+C stays the emergency brake |
| D5 | When nothing is eligible the loop **waits and re-checks** (default every 60 s) — without starting `claude` | the maintainer opens items while the loop waits; checking `next` locally costs nothing, while a `nothing-to-do` run would cost a session and write a journal row + commit every time |
| D6 | **3 `blocked` in a row** stop the loop | a series of stops usually means a systemic problem (build broken, environment), not three bad items |
| D7 | Usage limits: `claude` runs in its **unattended retry mode** (`CLAUDE_CODE_RETRY_WATCHDOG=1`, Claude Code ≥ 2.1.301): a request at a usage limit waits until the limit resets and the session continues in-process. The loop is the fallback: an interrupted run (error, crash, Ctrl+C, reboot) is **continued in the same session** (`--resume <session-id>`); at a limit the loop waits until the reset time the API reported (`rate_limit_event.resetsAt`) | continuing the same session keeps the whole context of a half-done item; the session id is chosen by the loop (`--session-id`) and kept in a file, so it survives a restart of the loop and of the PC |
| D8 | The control and state files live in the git common dir (`.git/tandem-backlog-loop/`), next to the run lock | never in the working tree: a run's precondition is a clean `git status` |
| D9 | Before starting an item the loop checks the run's preconditions itself (lock free, on `main`, clean tree, `backlog.py check` = 0, an eligible item) and **waits** while one fails | the maintainer may be working in the tree; a refused run would cost a session |
| D10 | The loop passes the slug it selected: `/tandem-backlog-implement <slug>` | the log, the status and the journal name the same item; the skill re-checks eligibility |
| D11 | `/tandem-backlog` in maintainer mode refuses changing operations while the run lock is held **or a loop runs unpaused** | during a run the working tree is on the run's feature branch: a triage would land in the feature's commit (step 8.9 `git add -A`) or make the fast-forward of `main` fail; an unpaused loop can start a run between two commits of a triage (review S3) |

## Requirements

- **FR-1** `loop-start.sh [--max-items N] [--max-blocked N] [--poll SECONDS] [--model M] [--until-idle] [--forget-run]`
  runs the loop in the foreground; one loop per repository (a second start is refused while the first lives).
- **FR-2** Each item: `claude -p '/tandem-backlog-implement <slug>' --session-id <uuid> --output-format stream-json --verbose --permission-mode bypassPermissions`,
  environment `CLAUDE_CODE_RETRY_WATCHDOG=1` (unless the caller set it), working directory the repository root,
  output to a log file per item (`.git/tandem-backlog-loop/logs/`, the newest 100 kept).
- **FR-3** The outcome of a run is read from `backlog/RUNS.md` (a new row for its item) and the run lock, never
  from the model's text: a run is finished only when a new journal row of its item exists **and** the run no
  longer holds its lock (free, or since taken by another run).
- **FR-4** A run that ended while its item still holds the lock is *interrupted*: continue it with
  `--resume <uuid>` and a "continue where you stopped" prompt — after the reported reset time (limit),
  after a growing pause (error: 1, 5, 15, 30, 60 min; then the loop stops for a person), or at once
  (Ctrl+C, a run that ended its turn without finishing — at most twice).
- **FR-5** `loop-pause.sh` / `loop-resume.sh` / `loop-stop.sh` take effect within a second while the loop
  waits and after the running item while it runs; pause persists (a start while paused waits), stop is one-shot
  (removed when the loop ends; refused with a message when no loop runs).
- **FR-6** `loop-status.sh` shows: is the loop running (pid, since), what it does (running item / waiting and why /
  paused / waiting for a limit until …), pending pause / stop, the last usage figures, a pending interrupted run,
  the run lock, the counts of this loop, the log, and whether Ctrl+C is safe now.
- **FR-7** Ctrl+C / Ctrl+Break while an item runs kills the `claude` process tree, keeps the run record and
  the lock, and says that the next `loop-start.sh` continues the item. While waiting, Ctrl+C just ends the
  loop. Where the terminal kills loop and claude together (Git Bash signals), the next start says what
  happened (with the registry hint) and continues the item.
- **FR-10** A run is continued only while it holds its own lock (the item's lock, taken after the run started,
  the same one once seen); a run that refused because another run took the item's lock is never continued.
- **FR-8** The loop never pushes, merges, edits the backlog or releases the lock itself; everything in the tree is
  done by the runs.
- **FR-9** A `claude` left running by a killed loop is waited for by the next loop (it is not started twice).

## Out of scope

- A run that cannot be continued (session deleted) is not taken over automatically: the loop stops and says what
  to do (lock, branch, `--forget-run`). Teaching the skill to adopt an orphaned lock is a separate item if needed.
- Scheduling (cron, Windows Task Scheduler), several loops in parallel, worktrees per run.

## Owed to a person (cannot be driven here)

- Ctrl+C in a real Git Bash (mintty) window while an item runs and while the loop waits.
- The first real usage limit: that the run waited (or was continued) and finished.
