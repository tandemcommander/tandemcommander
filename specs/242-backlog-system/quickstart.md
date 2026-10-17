# Quickstart: validating the backlog system (242)

Run from the repository root on branch `242-backlog-system` (or `main` after
the merge). Formats: `contracts/item-format.md`,
`contracts/overview-format.md`; commands: `contracts/cli.md`; skills:
`contracts/skills.md`.

## Prerequisites

- Python 3.13+ on `PATH` (the build already requires it).
- A clean working tree for the implement scenarios (V7–V9).

## V1 — Unit tests of the tool (SC-004)

```text
python -m unittest tools/backlog/test_backlog.py -v
```

Expected: all tests pass. Among them one seeded fixture per check rule of
`contracts/cli.md` (each detected with its `rule-id`), a valid fixture with
`TOTAL: 0`, `sync` idempotence (a second `sync` changes nothing), slug
derivation (`Žluťoučký kůň: test` → `zlutoucky-kun-test`), collision
refusal, `remove` cleaning other items' `depends-on`, lock exclusivity and
staleness (clock injected).

## V2 — The migrated backlog is consistent (SC-004, SC-008)

```text
python tools/backlog/backlog.py check
python tools/backlog/backlog.py sync && git diff --exit-code backlog/
```

Expected: `TOTAL: 0`; `sync` changes nothing.

## V3 — Migration is complete (SC-003, SC-007)

- Every open entry of `specs/NEXT-WORK.md` (as of `7993914c`) and of the five
  `REMAINING-WORK.md` files has exactly one row in `migration-ledger.md`;
  every `item:` / `merged:` destination exists in `backlog/items/`.
- `specs/NEXT-WORK.md` does not exist; each `REMAINING-WORK.md` starts with
  the one-line note.
- `git grep -n "NEXT-WORK" -- CLAUDE.md specs/FEATURE-HISTORY.md
  architecture .claude/skills` shows no instruction that sends planned work or
  findings there (history mentions are allowed).
- An independent agent samples 20 ledger rows against the old file and finds
  no lost or mis-mapped entry.

## V4 — Add and list (User Story 1, SC-001)

`/tandem-backlog add "Packing a folder with a too long name fails silently,
archives, severity 6"` → an item in *Inbox*, check passes, `git status`
shows changes only under `backlog/` (SC-005). Repeat with the same title →
refused, the existing slug named.

## V5 — Triage and order (User Story 2)

`/tandem-backlog triage` on three *Inbox* items: one to *Next* position 1,
one parked with a reason, one rejected with a reason → sections and statuses
match, *Next* renumbered, `Last triaged` today, logs written, check passes.
`/tandem-backlog list area=archives severity>=5` lists only matching items
in order.

## V6 — GitHub import (User Story 5)

`/tandem-backlog import-github 5` → item with `issue.md` (verbatim body and
comments), `reply.md` `state: not-sent`, `source: github#5`; a second import
of 5 is refused naming the item.

## V7 — Implement, dry run (User Story 4)

`/tandem-backlog-implement --dry-run` → names the item it would take and the
reasons for every skipped row above it; nothing changed (`git status`
clean), no lock (`backlog.py lock status` → `free`).

## V8 — Implement refuses safely

- With an uncommitted change: ends "dirty tree", nothing changed.
- With a lock held (`backlog.py lock acquire --slug x`): ends "another run in
  progress", nothing changed, no journal line; then
  `backlog.py lock release --slug x`.
- With *Next* holding only a `blocked` item: `nothing-to-do`, one journal
  line, one commit on `main`, lock free afterwards.

## V10 — Numbers agree after a stopped run (review-tool M1)

In a temporary repository with `specs/241-prev` on `main` and an unmerged
branch `242-stopped-run`:
`.specify/extensions/git/scripts/bash/create-new-feature.sh --json --dry-run --short-name next-item "Next item"`
prints `243-next-item`; a specify run given
`SPECIFY_FEATURE_DIRECTORY: specs/243-next-item` creates exactly that
folder, so `ls -d specs/<BRANCH>` holds in step 4 of the implement skill.
Without the line, specify would create `specs/242-next-item` (the defect).

## V9 — Implement, one real small item (SC-006)

Put a small `who: agent`, `effort: S` item (e.g. a tooling item) at the top
of *Next* and run `/tandem-backlog-implement`. Expected: feature branch from
`main`, Spec Kit commits after each step, final `[NNN] …` commit, local
`main` fast-forwarded, item gone from `backlog/`, leftovers in *Inbox*, a
`FEATURE-HISTORY.md` entry naming the item, `closing-report.md`, one
`closed` row in `RUNS.md`, lock free, nothing pushed (`git status -sb` shows
`main` ahead of `origin/main` only).
