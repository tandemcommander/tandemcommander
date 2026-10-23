# Contract — the backlog loop (feature 247)

`tools/backlog/loop.py` (stdlib only) and five Git Bash wrappers in
`tools/backlog/`. Each wrapper is one line: `exec python -u loop.py <command> "$@"`
(`$PYTHON` overrides `python`); options pass through, `--root DIR` selects
another repository (tests).

| Wrapper | Command | Effect | Exit |
|---|---|---|---|
| `loop-start.sh [options]` | `start` | Runs the loop in the foreground until stop / `--max-items` / `--until-idle` / a stop for a person. | 0 ended as asked; 1 stopped for a person or refused (another loop runs, an interrupted run cannot be continued, claude missing); 2 usage; 130 Ctrl+C / Ctrl+Break |
| `loop-pause.sh` | `pause` | Sets the pause: a running item finishes, then the loop waits. Without a loop: the next start waits. Persists until `resume`. An interrupted run waiting for a limit or a backoff keeps the lock and its branch while paused — `pause` says so. | 0 |
| `loop-resume.sh` | `resume` | Clears the pause and a pending stop. | 0 |
| `loop-stop.sh` | `stop` | A running loop finishes its item and ends; a waiting loop ends within a second. An item interrupted meanwhile (limit, error) is not waited for: the loop ends and the next start continues that run. Without a loop: says so, sets nothing. One-shot: the loop removes it when it ends, and a start removes one left by a killed loop. | 0 |
| `loop-status.sh [--json]` | `status` | See *Status* below. | 0 |

## `start` options

| Option | Default | Meaning |
|---|---|---|
| `--max-items N` | 0 (no limit) | end after N finished runs (any outcome but `nothing-to-do`) |
| `--max-blocked N` | 3 | stop (exit 1) after N `blocked` outcomes in a row; any other outcome resets the count |
| `--poll SECONDS` | 60 | how often a waiting loop looks at the backlog again |
| `--model M` | claude's default | passed to `claude --model` |
| `--until-idle` | off | end (exit 0) when nothing is eligible instead of waiting |
| `--forget-run` | off | drop the record of an interrupted run first (after the maintainer cleaned up) |
| `--auto-triage` | off | before a new run, when the *Inbox* holds an item the last triage of this loop did not see (at the start: any item), run the auto-triage (*Auto-triage* below) |

Hidden test options: `--claude-cmd JSON-list`, `--backoff s,s,…`, `--limit-margin s`,
`--limit-unknown-wait s`, `--tick s`, `--deadline s` (the loop ends with exit 3 after s
seconds and kills its claude — a test that would hang fails instead).

## Files (git common dir, never the working tree)

| Path | Written by | Content |
|---|---|---|
| `.git/tandem-backlog-run.lock` | the runs (feature 242) | the run lock — the loop only reads it |
| `.git/tandem-backlog-loop/loop.json` | the loop | pid + process creation time (liveness that survives pid reuse), host, started, state, detail, since, until, slug, session, log, counts, blocked streak, last usage figures; removed when the loop ends |
| `.git/tandem-backlog-loop/run.json` | the loop | the current run: slug, session id, log, journal rows before, attempts, stalls, resumes, limits, nudges (idle continuations), phase (`new`/`running`/`waiting`/`killed`/`failed`/`lost`), wait_until, why, claude pid + creation time; removed when the run finished or never took its item |
| `.git/tandem-backlog-loop/pause`, `stop` | `pause` / `stop` | flags |
| `.git/tandem-backlog-loop/logs/<date>-<slug>.jsonl` / `.err` | claude | stream-json output and stderr of a run (all its continuations append); the newest 100 kept |

## One cycle

1. stop requested → end (0). Paused → wait for `resume` / `stop`.
2. `run.json` exists → *pending run* (below).
2a. `--auto-triage`, the precheck's tree conditions of step 4 hold (lock free, `main`,
   clean, `check` clean) and the *Inbox* holds an item the last triage did not see →
   *Auto-triage* (below), then the cycle starts again. So the findings of a finished run
   are placed before the next item is chosen, also after the last item of `--max-items`.
3. `--max-items` reached → end (0).
4. Precheck, in order — while one fails the loop waits (`--poll`) and starts nothing:
   run lock free; `HEAD` is `main`; `git status --porcelain` empty;
   `backlog.py check` has no finding; an eligible item in *Next* (`backlog.next_eligible`,
   the same rule as `backlog.py next`). Nothing eligible + `--until-idle` → end (0).
5. New run: `uuid4` session id, `run.json`, then
   `claude -p '/tandem-backlog-implement <slug>' --output-format stream-json --verbose --permission-mode bypassPermissions --session-id <uuid> [--model M]`
   with `CLAUDE_CODE_RETRY_WATCHDOG=1` (unless set by the caller), stdin closed, the
   repository root as working directory, a new process group.
6. When claude ends, the verdict. *The run holds the lock* when the lock names its item, was
   taken after the run started, and — once the loop has seen it — is the same lock (its
   `started` value; the lock file has no session id). Only the part of the log written by
   this attempt is read (its offset).

| Journal / lock / log | Verdict | Action |
|---|---|---|
| a new row **for the item** in `RUNS.md`, the run does not hold the lock | finished (`outcome` = the row's) | count; `blocked` → streak + 1, else streak 0; streak ≥ `--max-blocked` → stop (1) |
| the run holds the lock, a successful result `Outcome: refused …` (also in Markdown), first attempt and the lock never seen before | refused | another run (a manual one) took the item's lock first: never continued; drop the record |
| the same, but a continuation or a lock the loop had already seen as the run's | refused-own | phase `failed`, the record (session) kept; stop (1) |
| the run holds the lock, stderr `No conversation found` | lost | `run.json` phase `lost`; stop (1) |
| the run holds the lock, an **error** result with status 429, or no result after a `rejected` rate event, or an error result without a status with a usage-limit text | limit | continue after `resetsAt + 120 s` (no reset known: after 30 min); the 11th → phase `failed`, stop (1). A successful result is never a limit (claude waited it out) |
| the run holds the lock, any other error result or no result (also `Context limit reached`) | error | continue after 1, 5, 15, 30, 60 min; the 6th error → phase `failed`, stop (1) |
| the run holds the lock, a successful result | stalled | continue at once; the 3rd → phase `failed`, stop (1) |
| while it runs: since the last change of the background-task list (`background_tasks_changed`), task notification, task progress or subagent line, the main thread scheduled **2** wakeups with `noop: true` in a row, and the last list is empty (added 2026-10-23 after 320: a killed reviewer, the run waited on wakeups) | idle → the loop kills the process | continue at once with the reason "launch again what you wait for" (SKILL.md step 7); the 4th → phase `failed`, stop (1) |
| the run does not hold the lock, a successful result | refused / unrecorded | drop the record (unrecorded = an `Outcome` other than refused but no journal row: say so); 2 in a row → stop (1) |
| the run does not hold the lock, a limit | — | wait for the reset, then a fresh start |
| the run does not hold the lock, an error | — | wait 1, 5, 15, 30, 60 min, then a fresh start; the 6th → stop (1) |

*Continue* = `claude -p '<continue prompt>' --resume <uuid>` with the same options: the
prompt says why the run was interrupted and points to SKILL.md *Continued run*.

## Auto-triage

`claude -p '/tandem-backlog auto-triage --commit'` with the options of a new run (its own
`uuid4` session, never continued), `TANDEM_BACKLOG_LOOP_TRIAGE=<the loop's pid>` (the skill
proceeds only when `status` shows that pid in state `triage`), log
`logs/<date>-auto-triage.jsonl`, state `triage`. The skill commits its changes on `main`
(`backlog: auto-triage - …`). It takes no run lock and writes no `run.json`. When claude ends:

| After it | Action |
|---|---|
| the tree is not on `main`, not clean, or `check` reports findings | stop (1): the loop never repairs the tree |
| a usage limit | wait for the reset, then the auto-triage again |
| an error result or no result | wait 1, 5, 15, 30, 60 min, then again; the 6th → stop (1) |
| a successful result, a new commit | count it; the *Inbox* items left now are not triaged again by this loop; say how many were placed and which item is next |
| a successful result, no commit (refused, nothing to do) | say so; the same, the loop continues with *Next* as it is |

Pause and stop wait for it as for an item. Ctrl+C kills it (`HARD STOP …`): what it
changed and did not commit stays in `backlog/`; the next start waits for a clean tree.

## Pending run (a `run.json` at the top of a cycle)

- phase `lost` / `failed` → say what to do, stop (1); `--forget-run` drops it first.
- its claude still runs (a loop died, its claude did not) → wait for it, then the verdict.
- `wait_until` in the future → wait (pause / stop interrupt the wait).
- a new journal row for the item and the run does not hold the lock → finished meanwhile → the verdict.
- the lock free, no row → the record is dropped (the lock was released by hand).
- the lock held, but not by this run (another item, or the same item's lock taken before
  the run started or replaced) → wait.
- else → continue the session; when the record says the run was cut off (phase
  `running` / `killed` / `new`), the window first says so and names the registry backup of
  an interrupted GUI probe (the continue prompt says it too).

## Ctrl+C / Ctrl+Break

When the loop's handler runs (Ctrl+Break, Ctrl+C in a console window): `taskkill /T /F`
of claude's tree (also when the same key already ended claude), `run.json` phase
`killed`, the lock stays, `HARD STOP …` and the registry hint are printed, exit 130. While
waiting: exit 130, nothing else. **In Git Bash (mintty) a signal ends the loop and claude
at once without the handler** (measured by the review with `kill -TERM`; a typed Ctrl+C is
owed to a person): then nothing is printed, `run.json` stays in phase `running`, and the
next start says what happened and continues the session. claude is started in its own
process group; that keeps a console Ctrl+C from reaching it, not a Git Bash signal.

## Status

```text
loop:    running (pid P, host H, since T) | not running | not running (… ended without cleanup …)
state:   <state> - <detail> (since T)
control: pause requested, stop requested | -
done:    closed n, blocked n, not-reproduced n, split n (blocked in a row: n)
triage:  auto, when the Inbox has new items (n done)        (only with --auto-triage)
usage:   <status>: five_hour x% (resets HH:MM), seven_day y% (resets …)
run:     item S, session U, phase P[, continues after T] [(why)]
log:     <path>
todo:    (phase lost / failed: what the maintainer does)
lock:    free | <backlog.py lock status>
Ctrl+C:  HARD STOP now (an item | the auto-triage is running) … | safe now (no item is running)
```

The `Ctrl+C` line follows what the loop announced (`ctrl_c_safe` in `loop.json`): while the
loop waits for a claude left by a previous loop, Ctrl+C ends only the loop — safe.

States: `starting`, `running`, `triage` (the auto-triage runs), `waiting` (precheck failed /
lock of another item), `idle` (nothing eligible), `paused`, `limit` (waiting for a reset),
`backoff`.
