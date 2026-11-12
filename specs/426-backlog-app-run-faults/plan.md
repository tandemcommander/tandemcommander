# Implementation Plan: The backlog app and the loop during a run

**Branch**: `426-backlog-app-run-faults` | **Date**: 2026-11-12 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/426-backlog-app-run-faults/spec.md`

## Summary

Four faults of the development tooling, each with its cause measured at `f8fc5084`
([research.md](research.md)):

1. The app's side worktree: `SideWorktree.sync()` makes a folder of `specs/FEATURE-HISTORY.md`
   (`ls-tree` without `-d`) and then cannot leave that state (checkout before reset). Fix: list
   only trees, clean before the checkout (also a folder standing where a tracked file belongs),
   sparse pattern `/backlog/`; the web shows a refusal's detail.
2. A finished run hangs: a pending `ScheduleWakeup` keeps `claude -p` alive after its final
   `result`. Fix in two places: the loop ends a finished run's process after a 30 s grace period;
   the implement skill cancels pending wakeups (`ScheduleWakeup` with `stop: true`) before its
   final message and never waits for the maintainer's program with a wakeup.
3. `status` offers to continue a finished run after a hard stop. Fix: `status` (and its JSON)
   reports such a record as finished; `pending()` already concludes it; the conclusion writes the
   trace's `meta.json` end.
4. The live page falls back to Specify: the trace stream's catch-up ends after the first 1 MB page
   (`send()` moves the shared `offset` to `page.next`), and drops the second and later events of a
   multi-event line. Fix: separate read and sent positions in the catch-up; the client takes the
   server's `phase` event as the lower bound of its fold.

## Technical Context

**Language/Version**: TypeScript (Node 24, type stripping; React 19 web) for `tools/backlog-app/`;
Python 3.14 for `tools/backlog/loop.py`; Markdown for the skill.
**Primary Dependencies**: Hono (server, SSE), vitest, React, git 2.51.
**Storage**: files (the loop's `run.json`, the trace's `meta.json`, git worktrees).
**Testing**: `npm run check` in `tools/backlog-app` (typecheck, lint, prettier, vitest);
`python -m unittest` in `tools/backlog` (`test_loop.py`, `test_backlog.py`, `test_traces.py`);
`python tools/test_bin_help.py`.
**Target Platform**: Windows 11 (the maintainer's machine).
**Project Type**: development tooling (CLI + localhost web app).
**Performance Goals**: a finished run ends within the 30 s grace period plus one tick.
**Constraints**: the app never touches the primary working tree during a run (371); the loop never
ends a process that still holds its run lock.
**Scale/Scope**: traces up to tens of MB (run 425: 15.7 MB, 1694 events).

## Constitution Check

- I Build reproducibility: no build change (tooling only).
- II Backward compatibility: the product is not touched; the loop's state files keep their
  format (a new field is not added; `describe()` gains a derived key in its JSON).
- III Incremental modernization: small fixes at the measured sites.
- IV Windows commitment: kept (git and process handling on Windows).
- V Plugin architecture: not touched.
- VI UI consistency: the app's toasts show the detail the same way everywhere.

Gate: passes; no violation to justify.

## Project Structure

### Documentation (this feature)

```text
specs/426-backlog-app-run-faults/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/trace-stream.md
├── tasks.md
└── fix-log.md
```

### Source Code (repository root)

```text
tools/backlog-app/packages/server/src/backlog/side-worktree.ts   # part 1
tools/backlog-app/packages/server/test/side-worktree.test.ts     # part 1 tests
tools/backlog-app/packages/web/src/lib/api.ts                    # part 1: errorText (message + detail)
tools/backlog-app/packages/web/src/features/**                   # toasts use errorText
tools/backlog-app/packages/server/src/api/runs.ts                # part 4: catch-up
tools/backlog-app/packages/server/test/runs.test.ts (or a new stream test)  # part 4 test
tools/backlog-app/packages/web/src/features/runs/trace-view.tsx  # part 4: phase event
tools/backlog-app/packages/web/src/features/live/run-dashboard.tsx  # part 4: lower bound
tools/backlog-app/packages/shared/src/runs/run-state.ts          # part 4: laterPhase helper
tools/backlog/loop.py                                            # parts 2, 3
tools/backlog/fixtures/fake_claude.py                            # part 2: linger
tools/backlog/test_loop.py                                       # parts 2, 3 tests
.claude/skills/tandem-backlog-implement/SKILL.md                 # part 2: cancel wakeups
```

**Structure Decision**: fixes at the measured sites, no new module except a pure helper in
`shared` for the phase bound.

## Complexity Tracking

None.
