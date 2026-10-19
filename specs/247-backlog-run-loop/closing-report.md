# Closing report — 247-backlog-run-loop

Asked by the maintainer 2026-10-19 (not a backlog item): run `/tandem-backlog-implement`
item after item, unattended, stoppable, surviving usage limits; Git Bash scripts.
Outcome: done.

## What changed

- `tools/backlog/loop.py` (new, stdlib): the loop and the commands `start`, `pause`,
  `resume`, `stop`, `status`. One fresh `claude -p '/tandem-backlog-implement <slug>'`
  per item with a session id chosen by the loop, stream-json log per item, claude in its
  unattended retry mode (`CLAUDE_CODE_RETRY_WATCHDOG=1`). The outcome is read from
  `backlog/RUNS.md` and the run lock only. Interrupted runs (limit, error, stall, Ctrl+C,
  a killed loop) are continued in the same session (`--resume`), with bounds; a run is
  continued only while it holds its own lock. Precheck before every new run (lock, `main`,
  clean tree, `check`, an eligible item) — the loop waits instead of starting a refused run.
  Control and state in `.git/tandem-backlog-loop/`, never in the tree.
- `tools/backlog/loop-start.sh`, `loop-pause.sh`, `loop-resume.sh`, `loop-stop.sh`,
  `loop-status.sh` (new): one-line wrappers.
- `tools/backlog/backlog.py`: `next_eligible()` factored out of `cmd_next` (the loop uses the
  same rule).
- `.claude/skills/tandem-backlog-implement/SKILL.md` §0.11 *Continued run*;
  `.claude/skills/tandem-backlog/SKILL.md` §0.2 *Not during a run*; `CLAUDE.md` backlog row.
- Tests `tools/backlog/test_loop.py` + `fixtures/fake_claude.py`; probes
  `probe/mutate_loop.py`, `probe/e2e_real_claude.py`.

## Measurements (before / after, commands)

`fix-log.md` M1–M6 (session id + resume, the error and stream-json shapes, the rate-limit
event, the retry watchdog; a real 429 cannot be produced). After: e2e with the real claude
5/5 three times.

## Checks

`test_loop.py` 57 OK; encoding guard `TOTAL: 0 finding(s)`; `backlog.py check` `TOTAL: 0`;
mutants 38 / 39 caught (1 near-equivalent survivor); no build (no product code changed).

## Reviews

Two independent refute-first rounds. Round 1: 2 MUST (a manual run's lock taken as the
loop's run's → continued into another run's tree; Git Bash kills loop and claude together),
4 SHOULD, 8 NOTE — all fixed or recorded. Round 2: 0 MUST, 2 SHOULD (a refusing
continuation lost its record and the loop waited for ever — introduced by the M1 fix;
Ctrl+C state while waiting for a previous loop's claude), 11 NOTE — fixed, two recorded as
known limits (a clock step back > 2 s; a manual run racing the skill's lock acquire while
the loop's run crashes). Details in `fix-log.md`.

## Owed to a person

`backlog-loop-person-checks` (person step): a typed Ctrl+C in Git Bash (while waiting and
while an item runs — which of the two documented behaviours happens), and the first real
usage limit.

## New Inbox items

- `backlog-fixture-empty-specs-folder-missing` — Backlog tool tests fail on a fresh
  checkout: the fixture folder specs/243-example is not in git (28 failures, 2 errors at
  `main`).
- `backlog-loop-person-checks` — Backlog loop: Ctrl+C in Git Bash and the first real usage
  limit.
