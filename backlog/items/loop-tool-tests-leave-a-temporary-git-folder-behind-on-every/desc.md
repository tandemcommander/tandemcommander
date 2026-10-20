---
title: Loop tool tests leave a temporary git folder behind on every test
type: tech-debt
status: open
severity: 1
area: tooling
source: measure:265
who: agent
created: 2026-10-20
updated: 2026-10-20
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Loop tool tests leave a temporary git folder behind on every test

## Problem

Every test of `tools/backlog/test_loop.py` (feature 247) creates a temporary git repository
under `%TEMP%\loop247-*` and tries to delete it in `tearDown`, but on Windows the delete
silently fails for git's read-only object files, so each run of the 57 tests leaves 57
folders behind that hold `repo\.git\objects`. Whoever runs the suite (the maintainer, an
agent, the loop's own checks) piles up leftovers in `%TEMP%`.

## Evidence

- `tools/backlog/test_loop.py:83` at `42700908` (`LoopTestCase.tearDown`):
  `shutil.rmtree(self.tmp, ignore_errors=True)`; the repository is made by `git init` in
  `setUp`, and git writes its object files read-only, which `rmtree` cannot delete on
  Windows; `ignore_errors=True` hides the failure.
- Measured in feature 265 (review 2) on 2026-10-20: 324 folders `%TEMP%\loop247-*`, each with
  only `repo\.git\objects\...` files left (one sample: 27 files).
- Not caused by 265; found by its second independent review
  (`specs/265-backlog-fixture-specs-folder/fix-log.md`, *Review*).

## Expected

After `python -m unittest tools/backlog/test_loop.py` no new `%TEMP%\loop247-*` folder
remains (count before and after the run is the same); the suite still passes.

## Approach

Delete with an `onexc` / `onerror` handler that clears the read-only attribute
(`os.chmod(path, stat.S_IWRITE)`) and retries, as other probes of the project do; keep
`ignore_errors` off so a real failure shows. Check whether `test_backlog.py` or the 247
probes have the same pattern.

## Notes

Severity 1: only temporary files of a developer tool, no user impact. The existing leftovers
can be deleted by hand (not done by the run that found them).

## Log

- 2026-10-20 — created (source measure:265)
- 2026-10-20 — moved to Next
