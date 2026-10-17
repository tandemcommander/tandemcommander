# Closing report — 242 backlog system

**Branch**: `242-backlog-system` (from `main` at `7993914c`) · **Date**:
2026-10-17 · **State**: implemented, not committed (the maintainer runs the
Spec Kit steps and commits).

## What changed

- **`backlog/`** — the only place of planned work: `BACKLOG.md` (row order
  = priority; seven sections; the legend is the vocabulary), 128 items in
  `items/<slug>/desc.md` (*Next* 61, *Decisions* 11, *Person steps* 38,
  *Parked* 5, *Rejected* 13, *Inbox* 0), `RUNS.md` (empty journal),
  `RELEASE.md` (release procedure + the current 0.1.10 gate).
- **`tools/backlog/backlog.py`** — standard-library CLI: `check` (18
  rules), `sync`, `list` (filters incl. `--needs` / `--related-to`), `next`,
  `new`, `import-github`, `set`, `log`, `verify`, `move`, `block`,
  `unblock`, `start`, `remove` (`--feature` / `--reason`), `run-log`,
  `lock` (`acquire` / `update` / `release` / `status`). Tests
  `test_backlog.py` (58), fixtures `fixtures/valid/`.
- **Skills** — `/tandem-backlog` (16 operations, two modes, decision
  tables, fix table, fixed reports) and `/tandem-backlog-implement` (steps
  0–11, stop rules).
- **Migration** — every entry of `specs/NEXT-WORK.md` (at `7993914c`) and
  the five `REMAINING-WORK.md` files mapped in
  `migration-ledger.md` (696 rows: item, merged, see, release-checklist,
  done, not migrated). `specs/NEXT-WORK.md` deleted; the `REMAINING-WORK.md`
  files carry a note; `CLAUDE.md`, `specs/FEATURE-HISTORY.md` (header,
  index, entry 242), `architecture/12-project-reference.md` redirected; the
  assistant's memory pointer rewritten. `issues/` and `features/` deletion
  staged.

## Checks

| Check | Result |
|---|---|
| `python -m unittest tools/backlog/test_backlog.py` | 58 tests OK |
| `python specs/242-backlog-system/probe/mutate.py` | 31 of 32 mutants caught; `first-link-wins` equivalent |
| `python tools/backlog/backlog.py check` (real backlog) | `TOTAL: 0`; `sync` idempotent |
| `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| Quickstart V1 (tests), V2 (check / sync), V3 (ledger complete, no instruction points to NEXT-WORK, independent sample) | pass |
| V4 / V5 (add, triage on a scratch copy), V6 (`import-github 5` against GitHub) | pass |
| V7 / V8 (dry run, dirty tree, held lock, nothing-to-do — temporary repository) | pass |
| V10 (branch and folder numbers after a stopped run, temporary repository) | `--dry-run` → `243-next-item` next to `242-stopped-run`; `GIT_BRANCH_NAME` creates exactly it |
| Files changed under `specs/` outside this feature | the five `REMAINING-WORK.md` notes, `FEATURE-HISTORY.md`, the `NEXT-WORK.md` deletion — nothing else |

## Reviews (refute-first, independent)

1. **Migration** (`ledger/review.md`): 4 MUST, 8 SHOULD, 12 NOTE — the
   0.1.10 release gate, the 072 winget audit plan, 10 Code Viewer person
   rows and 068's F1–F8 / G7 had been lost or inverted; all resolved, 4
   new items.
2. **Tool and skills** (`review-tool.md`): 2 MUST, 15 SHOULD, 17 NOTE —
   branch / spec-folder numbers diverge after a stopped run; `sync`
   dropped hand-written rows; weak tests (15 / 19 mutants survived); all
   resolved.
3. **Skills, exactness** (`review-skills.md`, after the maintainer asked
   for clear and exact skills): 2 MUST, 20 SHOULD, 18 NOTE — item text on
   a command line runs as shell code; rejecting a decision with dependents
   had no procedure; all resolved with the suggested wordings.

## Owed to a person (the maintainer)

- **V9 — the first real autonomous run**: put a small `who: agent`,
  `effort: S` item at the top of *Next* and run `/tandem-backlog-implement`
  (first maybe `--dry-run`). The run's interactive parts (Spec Kit skills
  answering themselves, the review agent, the fast-forward) have not been
  driven end to end.
- **Triage the migrated backlog**: *Next* is ordered by severity, then by
  the old order; the 11 *Decisions* (two of them gate the 0.1.10 release:
  `post-142-fixes-joining-0-1-10-decision`,
  `winget-repoint-pr-426090-decision`) and the order of *Person steps*.
- **Commit** the feature (and decide whether `ai-main`, named in
  `CLAUDE.md`, should exist — item `claude-md-names-missing-ai-main-branch`).

## Known limits

- The tool takes no lock of its own; the skills run one changing command
  at a time (documented in `cli.md` and the skills).
- Two git branches that each add an *Inbox* row conflict in `BACKLOG.md`
  (resolve by keeping both rows, then `sync`).
- Migrated items carry `verified: -` mostly; their *Evidence* was not
  re-checked at HEAD item by item (a run measures first).
