# Closing report - 411-lock-retry-permission
Backlog item: run-lock-update-release-no-retry - Run lock update and release fail when a reader holds the lock open
Outcome: closed

## What changed

- `tools/backlog/backlog.py`: `LOCK_RETRY_ATTEMPTS` / `LOCK_RETRY_DELAY` (40 x 50 ms),
  `lock_retry`, `lock_now`, `lock_fields`; `cmd_lock` routes every file operation (create, read,
  replace, delete) through them. A persistent PermissionError is one `refused:` line, exit 1,
  nothing changed. A retried update / release acts only on the lock it checked (review 1 S1).
  A lock gone between check and read is "no lock".
- `tools/backlog/test_backlog.py`: `LockHeldOpenTests` (Windows, 14 tests).
- `.claude/skills/tandem-backlog-implement/SKILL.md`: §0.8, steps 2 and §11 handle the new
  `refused: the run lock …` and `refused: the lock changed while waiting` lines (review 1 S2,
  review 2 N1).
- `specs/411-lock-retry-permission/probe/repro_lock.py`: the item's measurement.

## Measurements (before / after, commands)

`python specs/411-lock-retry-permission/probe/repro_lock.py "$(pwd -W)"`:

| Case | Before (b5bb8329) | After |
|---|---|---|
| update, reader holds 0.5 s | exit 1, `PermissionError: [WinError 5]` traceback | exit 0, `lock updated: branch b2`, 0.53 s |
| release, reader holds 0.5 s | exit 1, `PermissionError: [WinError 32]` traceback, lock kept | exit 0, `lock released`, 0.56 s, lock gone |
| update / release, reader holds 5 s | traceback | one `refused: the run lock … could not be updated / released: another process holds it open, or it is not writable (…); nothing changed - try again`, exit 1, lock kept |

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- `python -m unittest tools/backlog/test_backlog.py tools/backlog/test_loop.py tools/backlog/test_traces.py` → `Ran 258 tests in 220.846s OK`.
- `python tools/test_bin_help.py` → OK.
- `bin/backlog.sh check` → `TOTAL: 0`.
- Build / saltests / GUI probes: not applicable - no product code, no `src/`, no UI strings or
  translations changed.
- Negative controls: the new tests against `main`'s `cmd_lock` fail (12 of 13 at review 2, each
  with the defect's error); the S1 tests fail on the pre-review `backlog.py`.

## Reviews (findings and what was done)

- Review 1: MUST 0; SHOULD 2 (check-then-act widened by the retry - fixed with a re-check per
  attempt; the skill did not know the refusals - fixed); NOTE 4 (wording, a timing test, the probe's
  temp folder - fixed; acquire's pathological bound - documented). Stress run: 83 acquisitions under
  constant readers, never two holders; `main` failed under the same load.
- Review 2: MUST 0; SHOULD 2 (tests left temp folders - fixed; contract out of date - rewritten,
  plus a test for FR-002); NOTE 4 (skill wording - fixed; same-second identical re-acquire,
  `write_text` temp-file cleanup, stale worktrees of other reviews - documented). Stress run: 24
  acquisitions, ~10,000 reads, never two holders.

## Owed to a person (the lines added to the release checklist)

None - the feature is a developer tool; no keyboard, clipboard or GUI step.

CHANGELOG: no entry - the backlog tooling is not part of the shipped product (342, 344 and 371
have none either), and `CHANGELOG.md` has no `[Unreleased]` section.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- (severity 3, measure:411) the read side of the same commands: `lock status` and the reads in
  `acquire` / `update` / `release` did not retry a PermissionError and had an `exists()`-then-read
  race (FileNotFoundError traceback). Tests `test_status_waits_for_a_briefly_unreadable_lock`,
  `test_lock_gone_between_check_and_read_is_no_lock` fail before, pass after.

## New Inbox items (slug - title)

None.
