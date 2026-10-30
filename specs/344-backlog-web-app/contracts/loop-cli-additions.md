# Contract: additions to the backlog loop (feature 344)

Amends `specs/247-backlog-run-loop/contracts/loop-cli.md` (and, for the trace of a single-item
run, nothing in `specs/342-backlog-agent-traces/contracts/traces.md` changes). Every existing
command, option, state, file and exit code keeps its meaning. Standard library only; tests in
`tools/backlog/test_loop.py` with the fake claude.

## `start` options

| Option | Meaning |
|---|---|
| `--new-window` | Start the loop with the remaining options in a **new console window** (`CREATE_NEW_CONSOLE`, title `Backlog loop`) and return. Prints `started the loop in a new window (pid N)` and exits 0 once the new loop has registered `loop.json` (at most 15 s; otherwise exit 1 with the reason the new loop printed, read from `loop.log`). Refused (exit 1) when a loop lives, exactly like `start`. The new loop is a normal foreground loop of that window: Ctrl+C there is the hard stop, closing the window kills it like a killed loop (the next start continues its run). |
| `--item SLUG` | Run this one item, then end (implies `--max-items 1`; with `--until-idle` meaningless and refused). Eligibility is `backlog next --slug SLUG`; not eligible = exit 1 with the reason, nothing started. The run is a normal loop run (trace, continuation, verdict, `RUNS.md` row). The backlog order is not changed. A pending interrupted run is continued first, as with every start; `--item` is then refused with the reason (`an interrupted run of <slug> must be continued first`). |

## New command `kill`

```text
bin/backlog-loop.sh kill
```

Sets the flag `.git/tandem-backlog-loop/kill`. A live loop checks it every tick (while waiting
and while watching claude or the auto-triage) and handles it **exactly like Ctrl+Break in its
window** (the existing hard-stop path: claude's process tree killed, `run.json` phase `killed`,
`why` "a hard stop (kill) ended the process", the lock kept, `meta.json` phase `killed`, the
messages printed, exit 130), then removes the flag. Without a live loop: says so and sets
nothing (exit 0). A `kill` flag left by a dead loop is removed by the next `start`. `status`
shows a pending kill (`kill requested`).

## Precheck: the edit lock

New first precheck condition (cycle step 4, and before the auto-triage of step 2a): when
`.git/tandem-backlog-edit.lock` exists and names a live process (pid + creation time, as the
loop's own liveness check), the loop waits with
`waiting: the backlog app is changing the backlog (since HH:MM:SS)`. A lock whose process is
gone is ignored (not deleted: the app replaces it). File: four lines `pid: N`, `ident: N`,
`started: YYYY-MM-DDTHH:MM:SS`, `purpose: <one line>`.

When the loop leaves `paused` (after `resume`), it writes `loop.json` with state `starting` and
detail `resumed` **before** the precheck, so a reader that sees `paused` knows no precheck has
passed since.

## New files

| Path | Written | Content |
|---|---|---|
| `.git/tandem-backlog-loop/loop.log` | every line the loop prints (`say()`), appended with one write per line, prefixed with the local time | the loop's narrative for loops started anywhere; rotated to `loop.log.1` when it passes 5 MB |
| `.git/tandem-backlog-loop/last.json` | when a loop ends (any exit path that runs Python code, incl. Ctrl+C and kill) | `{"pid", "started", "ended", "exit_code", "reason", "counts", "items", "options"}`; `reason` one of `stop`, `max-items`, `until-idle`, `item-done`, `max-blocked`, `stopped-for-person`, `hard-stop`, `refused`, `error`. Replaced atomically. Not written when the process is killed from outside (then `loop.json` stays with `live: false`, as today). |
| `.git/tandem-backlog-loop/kill` | `kill` | flag, content = a timestamp |

## `status --json`

Adds `kill` (bool, a kill is pending), `last` (the content of `last.json` or null),
`edit_lock` (`{"pid", "started", "purpose", "live"}` or null) and `log` (the path of
`loop.log`). Existing keys unchanged.
