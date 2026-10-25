# Closing report — 342 backlog loop traces in `.agent-traces/` and two `bin/` commands

**Date**: 2026-10-25 · **Branch**: `342-backlog-agent-traces` (not committed; the
maintainer decides) · **Session**: interactive Spec Kit flow with the maintainer.

## What changed

- **Traces in the reference format** (`2026_hscr_ai_chatbot`, its feature 003). Every
  item run and auto-triage of the loop writes
  `.agent-traces/<YYYYMMDD-HHMMSS>-claude-<slug|triage>/`:
  - `trace.jsonl`: claude's stream-json output unchanged, with a
    `backlog_loop.attempt` separator line before every attempt;
  - `stderr.log`: a header line per attempt;
  - `meta.json`: format 1, the reference's keys. It holds the outcome, feature and
    branch from `RUNS.md`, the run's commits, every attempt with its ending, usage and
    exit code, the counters and the claude version. It is replaced atomically.

  `.agent-traces/index.jsonl` gets one line per ended run. The folder is in
  `.gitignore`, and the loop never deletes from it (the newest-100 pruning is gone).
  `bin/backlog-loop.sh status` shows the run's folder and the total size. The format
  is in `contracts/traces.md`; the code is the new `tools/backlog/traces.py`.
- **Two commands in `bin/`**: `bin/backlog.sh` runs the backlog tool
  (`tools/backlog/backlog.py`; argparse names the script). `bin/backlog-loop.sh` is the
  loop (the former `bin/backlog.sh`). Skills (`BL = bin/backlog.sh`), the 242 and 247
  contracts, `CLAUDE.md` and the backlog prose were renamed. An old loop word typed
  into `bin/backlog.sh` is the tool's usage error (exit 2, nothing written), as the
  maintainer chose.
- **The old logs moved** (the maintainer's instruction during implementation). The
  first `start` moves `.git/tandem-backlog-loop/logs/` into the layout once: copy, byte
  compare, rename from `.part`, index line, then delete; marker `imported.json`. This
  was **done on this repository**: 142 runs (81 closed, 5 blocked, 5 not-reproduced,
  4 split, 47 triaged; 547 MB), verified byte for byte against a copy taken before. The
  loop's state files stay in `.git/tandem-backlog-loop/`.

## Comparison with the reference — what was not taken over

Codex and the harness adapters, `.cmd` twins, a read-only reviewer agent, a
`Backlog-Item:` trailer, and a silence timeout (it would kill reviewers that
legitimately wait up to 2 h). Measured as unnecessary: lost-session detection in
`result.errors` (claude 2.1.310 also writes it to stderr) and parsing the reset time
from the limit text (the real limit carried `resetsAt`). Reasons in the spec's table.

## Evidence

| Check | Result |
|---|---|
| Baseline before the change | 144 tests OK |
| `test_traces` + `test_backlog` + `test_loop` + `test_bin_help` | 175 OK (31 new), see `fix-log.md` |
| `tools/check_encoding.py` | TOTAL 0 |
| `bin/backlog.sh check` | TOTAL 0 |
| Old-command search (SC-008) | only dated history records of 242 / 247 and one dated item log line |
| Rehearsal on a scratch clone | 142 → 142 folders / 142 index lines, no difference, second start moves nothing |
| Real move | 142 runs, no difference, `.agent-traces/` ignored by git |
| Independent review (refute-first) | no defect in the run path; 1 MUST + 4 SHOULD in the move / separators, all fixed with tests (R1–R4); negative controls fail as they should |

## Spec corrections made by measurement

FR-013 / SC-005 were withdrawn (the lost session is already handled). Imported runs
record their attempts as unknown, because `system/init` repeats at every turn. A run's
commits are found after `HEAD` at its start, not by time. The run count is 142, not 94
(94 was the number of distinct slugs). The tool has no `show` command. A failed or lost
pending run moves with the old logs.

## Owed to a person

- The first real loop run after the merge. (The failed 341 record was removed on the
  maintainer's request: that run was finished by hand and is in the traces as `closed`.)
  Check that
  the window names `.agent-traces/…` and that `status` shows the size.
- The existing person step `backlog-loop-person-checks` now names `bin/backlog-loop.sh`.
- Commit, merge and push are the maintainer's steps.

## Left as notes (not defects here)

A run pending at the upgrade on a branch whose `.gitignore` predates 342 could commit
traces through the skill's `git add -A`; this repository has no pending run (the
finished 341 record was removed), so this cannot happen here. `status --json` gives `trace: null` for a run not yet migrated.
