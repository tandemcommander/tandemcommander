---
title: Backlog loop: Ctrl+C in Git Bash and the first real usage limit
type: person-step
status: open
severity: 4
area: tooling
source: leftover:247
who: person
created: 2026-10-19
updated: 2026-10-19
verified: -
effort: S
feature: -
related: []
depends-on: []
reason: -
---

# Backlog loop: Ctrl+C in Git Bash and the first real usage limit

## Problem

Two behaviours of the backlog loop (feature 247) cannot be driven by an
agent: a real Ctrl+C typed into a Git Bash (mintty) window, and a real usage
limit of the Claude subscription. Tests cover them with Ctrl+Break sent to a
process group and with a stand-in claude that reports a limit; the real
terminal and the real limit are unconfirmed.

## Evidence

- `specs/247-backlog-run-loop/fix-log.md`, measurement M6: the 429 simulation
  of Claude Code is not active in the public build, so no real limit could be
  produced.
- `tools/backlog/test_loop.py` `test_ctrl_break_kills_the_item_and_the_next_start_continues_it`
  and `specs/247-backlog-run-loop/probe/e2e_real_claude.py` row E2b use
  Ctrl+Break, not a key typed into mintty.

## Expected

Ctrl+C in the loop window behaves as `loop-status.sh` announces (hard stop
while an item runs, a quiet end while waiting), and a run that meets a usage
limit finishes after the limit resets without a person.

## Steps

- [ ] Git Bash: `tools/backlog/loop-start.sh` while nothing is eligible (or
      after `loop-pause.sh`): the window says `(Ctrl+C is safe now)`; press
      Ctrl+C → `stopped (Ctrl+C) - no item of this loop was running`, the
      prompt returns, `loop-status.sh` → `loop: not running`.
- [ ] Git Bash, while an item runs (`Ctrl+C now = hard stop`): press Ctrl+C.
      Note which of the two happened: (a) `HARD STOP: claude was killed …` is
      printed and `loop-status.sh` shows `run: … phase killed`, or (b) the
      window returns to the prompt silently (Git Bash ended loop and claude
      together — the review measured this with `kill -TERM`) and
      `loop-status.sh` shows `run: … phase running` with the registry note.
      Either way: Task Manager shows no `claude.exe` of the run, `lock:` names
      the item, and `loop-start.sh` again says the run was interrupted, then
      `continuing item …`, and the item ends with a row in `backlog/RUNS.md`.
- [ ] The first time a run meets a usage limit: `loop-status.sh` shows
      `claude waits for the usage limit until …` (claude waited in-process) or
      `run: … phase waiting … (a usage limit)` (the loop waits); after the reset
      the item finishes. Note in this item which of the two happened.

## Log

- 2026-10-19 — created (source leftover:247)
- 2026-10-19 — moved to Person steps position 5
