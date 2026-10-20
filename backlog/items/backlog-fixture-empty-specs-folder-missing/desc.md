---
title: Backlog tool tests fail on a fresh checkout: the fixture folder specs/243-example is not in git
type: bug
status: open
severity: 4
area: tooling
source: measure:247
who: agent
created: 2026-10-19
updated: 2026-10-20
verified: 2026-10-20 6085500d
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Backlog tool tests fail on a fresh checkout: the fixture folder specs/243-example is not in git

## Problem

`python -m unittest tools/backlog/test_backlog.py` fails at `main`
(e6442151): 28 failures and 2 errors out of 68 tests. The valid fixture
needs an empty folder `tools/backlog/fixtures/valid/specs/243-example/` (the
target of the `feature-missing` rule for its in-progress item), but git does
not store empty folders, so the folder was never committed. On every fresh
checkout `check` of the valid fixture reports `feature-missing`, and every
test that expects a clean fixture fails.

## Evidence

- `python tools/backlog/backlog.py --root tools/backlog/fixtures/valid check`
  → `feature-missing: no folder specs/243-* for the in-progress feature`,
  `TOTAL: 1`.
- `git ls-tree -r HEAD tools/backlog/fixtures` lists no file under
  `valid/specs/`; `tools/backlog/fixtures/README.md` and
  `specs/242-backlog-system/tasks.md` T010 say the folder is part of the
  fixture; `test_backlog.py` SEEDED `feature-missing` deletes it.
- With the folder created by hand all 68 tests pass (measured in feature
  247, which works around it in its own tests).

## Expected

The fixture folder exists in git (e.g. a short `README.md` inside it saying
why it exists), `test_backlog.py` passes on a fresh checkout, and the
`feature-missing` seed still deletes it.

## Log

- 2026-10-19 — created (source measure:247)
- 2026-10-19 — moved to Next position 24
- 2026-10-20 — verified at 6085500d: at 6085500d: fixture check TOTAL 1 feature-missing; unittest test_backlog 68 tests, 28 failures 2 errors
