# Fix log — 242 backlog system

**Branch**: `242-backlog-system` (from `main` at `7993914c`, 2026-10-17)
**Spec / plan / tasks**: `spec.md`, `plan.md`, `tasks.md` in this folder.

## Decisions

- 2026-10-17 — the maintainer deleted `issues/` and `features/` before the
  feature started; the deletion is committed by this feature (FR-045).

## Measurements

- 2026-10-17 — Python 3.14.6 on `PATH`; `import yaml` fails (no PyYAML);
  `gh` not installed (Bash and PowerShell) → research R1, R2, R6.
- 2026-10-17 — `ai-main` (named in `CLAUDE.md`) does not exist locally.

## Progress

- 2026-10-17 — `tools/backlog/backlog.py` (all commands of `contracts/cli.md`)
  and `test_backlog.py`: 32 tests green at the first run, so a negative
  control was run: with the cycle rule disabled
  `test_every_rule_is_detected` fails (good). Smoke run on a scratch copy:
  `new`, the collision refusal, `move` refusing a person-step into *Next*,
  `next`, `check` 0.
- 2026-10-17 — seeded defects implemented as single-change mutations
  (`SEEDED` in `test_backlog.py`) instead of 18 copied fixture folders
  (deviation from T011's wording, same coverage; reason in
  `tools/backlog/fixtures/README.md`).
- 2026-10-17 — V6 against the real GitHub: `import-github 5` on a scratch
  copy created the item with the issue verbatim; a second import refused;
  check 0.
- 2026-10-17 — found while writing the implement skill: `start` must follow
  `speckit-specify`, because the check requires `specs/NNN-*` for an
  in-progress item and the folder is created by specify (its mandatory hook
  creates the branch and the number). `contracts/skills.md` step 4 updated.
- 2026-10-17 — migration: seven parallel agents, each writing only its
  ledger part and an items JSON (not the backlog — parallel writes to
  `BACKLOG.md` would race). `ledger/import_items.py` creates the items
  through the tool's model (`new` cannot carry historical `created`,
  `verified` and log dates); same rules, same renderer, full check at the
  end.
- 2026-10-17 — migration result: 7 parts, 129 items proposed, all valid at
  the first dry run. Consolidation (`ledger/consolidate.py`, idempotent):
  8 duplicates across parts merged; the 072 audit had been lost to a
  circular pointer (numbered-2 → RW072, remaining-work → NW §6) — two items
  made for it; the `ai-main` finding added. Imported 124 items: Next 59,
  Decisions 9, Person steps 37, Parked 5, Rejected 14. The first check after
  the import found 4 problems: the two `github#N` items had no `issue.md`
  (fetched from GitHub with the tool's own fetcher) and a person step shared
  `github#6` with the decision item (source changed to `leftover:126`).
  Then `TOTAL: 0`. Ledger: 692 rows (`migration-ledger.md`).
- 2026-10-17 — `specs/NEXT-WORK.md` deleted, notes in the five
  `REMAINING-WORK.md`, `CLAUDE.md`, `FEATURE-HISTORY.md` header and
  `architecture/12` repository map redirected, memory pointer rewritten;
  `backlog/RELEASE.md` written from the 17 `release-checklist` rows.
- 2026-10-17 — V7 / V8 in a temporary repository (copy of `backlog/` +
  `tools/backlog/`, its own `main`): dry-run commands change nothing and
  leave the lock free; a dirty tree fails the precondition; a held lock
  refuses a second acquire (exit 1, nothing changed); nothing-to-do writes
  one journal row, one commit, releases the lock, check 0. Found: on Windows
  the tool's stdout was CRLF in a pipe, so a shell loop over `list` output
  passed slugs ending in `\r` (refused as unknown). Fixed: stdout is
  reconfigured with `newline="\n"`. Also measured: `core.autocrlf=true` on
  this machine — the tool reads CRLF files (normalises) and writes LF; git
  normalises on commit, so no spurious diffs.

## Review

- 2026-10-17 — independent refute-first review of the migration
  (`ledger/review.md`): 4 MUST, 8 SHOULD, 12 NOTE. All applied the same day
  (resolution at the end of `ledger/review.md`): the 0.1.10 release gate
  restored in `RELEASE.md` / `CLAUDE.md`, the 072 audit's plan turned into a
  decision, lost person rows (070 §8, 068 F1–F8 / G7, 156, 159, 178, 194,
  228, 230, 240) put into items; 4 new items (128 in all); ledger 696 rows
  after the corrections; `backlog.py check` TOTAL 0.

- 2026-10-17 — the maintainer: the skills were described too thinly; they
  must be clear and exact. Both rewritten: modes, an operation table with
  Czech synonyms, exact steps and commands per operation, decision tables
  for every field (reference.md §3), a findings / refusals → fix table
  (§6), fixed report formats; the implement skill as steps 0–11 with every
  command, the specify input template, how to answer clarify, the review
  prompt, the closing texts, the stop procedure and the final message;
  stop-rules as a question test, the project rules of a run and a stop
  table.
- 2026-10-17 — independent refute-first review of the tool and the skills
  (`review-tool.md`): 2 MUST, 15 SHOULD, 17 NOTE. MUST 1: after any stopped
  run the branch number (counts unmerged branches) and specify's folder
  number (counts `specs/` only) differ, so every later run would block its
  item — the specify input now names `SPECIFY_FEATURE_DIRECTORY:
  specs/<BRANCH_NAME>`. MUST 2: `sync` silently dropped a hand-written row
  — such rows are kept and `sync` refuses while they exist. All SHOULD and
  NOTE resolved or recorded (*Resolution* in `review-tool.md`). The tests
  were weak (15 of 19 mutants survived): 55 tests now, 31 of 32 mutants
  caught (`probe/mutate.py`; the survivor is equivalent). Two of my own
  strengthened tests first passed for the wrong reason (the check after the
  write failed, not the refusal) — they now require `refused:` and an
  unchanged file.
- 2026-10-17 — `architecture/12` still sent the `PRIVACY.md` rule to
  "NEXT-WORK item 7" — reworded (feature 083's defects F1–F9).

- 2026-10-17 — third review, the skills' exactness (`review-skills.md`):
  2 MUST, 20 SHOULD, 18 NOTE. MUST 1: the item text went as the specify
  argument into a double-quoted command line of the git hook — backticked
  *Evidence* paths ran as commands (the reviewer showed it; one demo ran
  in the real tree by mistake: it executed `src/fileswn7.cpp` as a script,
  which failed at line 17; `git status` before and after identical, `src/`
  clean — re-checked by me). Now the item text never goes on a command
  line, the branch is computed with `--dry-run` and passed as
  `GIT_BRANCH_NAME`, the hook gets only `'Backlog item <slug>'` (V10
  measured in a temporary repository). MUST 2: rejecting a decision with
  dependents ended at a check finding with no procedure — an answered
  decision is now closed (`remove --reason`), and `reject` resolves the
  dependents first (`list --needs`, new). All SHOULD / NOTE resolved
  (*Resolution* in `review-skills.md`). Tool: `list --needs /
  --related-to`, `--position` < 1 refused, `person-step` needs `who:
  person`. Tests 58; mutation 31 / 32.
- 2026-10-17 — my own test loops twice passed slugs with a trailing `\r`
  (inline Python printing CRLF into a pipe on Windows) — not the tool, whose
  output is LF; noted so nobody re-chases it.

## Owed to a person

- V9: the first real autonomous run (`/tandem-backlog-implement`, maybe
  `--dry-run` first) on a small agent item.
- Triage of the migrated backlog (order of *Next*, the 11 decisions — two
  gate 0.1.10 — and the order of *Person steps*).
- Commit; decide on `ai-main` (item `claude-md-names-missing-ai-main-branch`).
