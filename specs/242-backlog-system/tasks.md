---
description: "Task list for feature 242 — backlog system outside specs/"
---

# Tasks: Backlog System Outside `specs/`

**Input**: Design documents from `specs/242-backlog-system/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Requested — SC-004 and quickstart V1 require unit tests of the
tool with one seeded fixture per check rule. Test tasks precede the code
they cover within each phase.

**Organization**: by user story (spec.md US1–US5). Paths are relative to the
repository root. Formats and behaviour are fixed by
`contracts/item-format.md`, `contracts/overview-format.md`,
`contracts/cli.md`, `contracts/skills.md` — tasks reference them instead of
repeating them.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an
  unfinished task)
- **[Story]**: US1–US5 from spec.md

---

## Phase 1: Setup

**Purpose**: working record and empty folders

- [X] T001 Create the running log `specs/242-backlog-system/fix-log.md` (header: feature, branch, baseline `7993914c`, sections *Decisions*, *Measurements*, *Review*, *Owed to a person*) and keep it current in every later task
- [X] T002 [P] Create folders `tools/backlog/`, `tools/backlog/fixtures/`, `backlog/items/`, `.claude/skills/tandem-backlog/`, `.claude/skills/tandem-backlog-implement/` (a `.gitkeep` only where a folder would otherwise stay empty at commit time)

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the file formats as code, and an empty valid backlog. Every
story depends on this phase.

- [X] T003 Write `tools/backlog/backlog.py` skeleton in the style of `tools/check_encoding.py` (SPDX header `2026 Pavel Stupka`, `GPL-2.0-or-later`, module docstring naming feature 242 and the contracts), `argparse` sub-commands per `contracts/cli.md` returning exit codes 0/1/2, `--root` defaulting to the repository that contains the script, UTF-8 stdout on Windows, standard library only
- [X] T004 Implement the item model in `tools/backlog/backlog.py`: read/write the metadata header of `desc.md` per `contracts/item-format.md` (strict key order, value after the first `": "`, flow lists, `-` as empty), parse the body into title line, headings and *Log* entries, and write back changing only the header and appended log lines; atomic write (temporary file in the same folder + replace), UTF-8 without BOM
- [X] T005 Implement the overview model in `tools/backlog/backlog.py`: parse `backlog/BACKLOG.md` per `contracts/overview-format.md` into header text, the seven sections in fixed order (each heading + one table; rows identified by the slug in `items/<slug>/desc.md`), and the *Legend* tables (vocabularies of Types, Statuses, Areas, Sources, Who, Effort read from the first column); write back preserving all text outside section tables, cells joined by `" | "` without padding
- [X] T006 Implement slug derivation in `tools/backlog/backlog.py` per research R5 (NFKD, drop combining marks, lowercase, non-alphanumeric runs → `-`, trim, cut at a hyphen to ≤ 60) and the slug pattern `^[a-z0-9]+(-[a-z0-9]+)*$`
- [X] T007 Create `backlog/BACKLOG.md` per `contracts/overview-format.md`: title, rules paragraph (order is priority; only the maintainer triages and reorders; agents add to *Inbox* only; derived columns written by `python tools/backlog/backlog.py sync`), `Last triaged: 2026-10-17`, seven empty section tables, and the full *Legend* (Types, Statuses, Severity anchors from FR-009, Areas from FR-005, Sources, Who, Effort) with one-line meanings
- [X] T008 [P] Create `backlog/RUNS.md` (title, one-line explanation, empty journal table with the columns of `contracts/overview-format.md`)
- [X] T009 [P] Create `backlog/RELEASE.md` with a title and a placeholder line "Filled by the migration (T047)"

**Checkpoint**: formats readable and writable; an empty backlog exists.

---

## Phase 3: User Story 1 — Record a new item and see it in the overview (P1) 🎯 MVP

**Goal**: add items, keep the overview consistent, and prove it with a check.

**Independent test**: from the empty backlog add three items of different
types; *Inbox* lists them with correct derived columns; `check` → `TOTAL: 0`
(quickstart V1, V2 on the fixture, V4).

### Tests for User Story 1

- [X] T010 [P] [US1] Create the valid fixture `tools/backlog/fixtures/valid/backlog/` (BACKLOG.md with legend, RUNS.md, RELEASE.md, about six items covering every section, type, a `github#N` item with `issue.md` and `reply.md`, a `decision` and a `person-step` item, `related` and `depends-on` links) plus `tools/backlog/fixtures/valid/specs/243-example/` so the `feature-missing` rule has a target
- [X] T011 [P] [US1] Create one seeded defect per check rule of `contracts/cli.md` (implemented as single-change mutations of `valid/` in `SEEDED` of `test_backlog.py` instead of 18 copied folders — see `tools/backlog/fixtures/README.md`; originally: folders `tools/backlog/fixtures/bad-<rule-id>/`) (layout, slug, desc-missing, header, value, required, feature-missing, body, ref, cycle, github, orphan, dangling, duplicate, section, derived, overview, runs), each a copy of the valid fixture with exactly one defect, and a `README.md` in `tools/backlog/fixtures/` listing them
- [X] T012 [US1] Write tests in `tools/backlog/test_backlog.py` (`unittest`, fixtures copied to a temporary folder per test): valid fixture → `TOTAL: 0`; each `bad-<rule-id>` → at least one finding with that rule id and no crash; header round-trip leaves the file byte-identical; slug cases (`Žluťoučký kůň: test` → `zlutoucky-kun-test`, 80-character title cut at a hyphen, punctuation-only title refused); `sync` idempotent; `new` refuses an existing slug naming it; `list --json` order and filters

### Implementation for User Story 1

- [X] T013 [US1] Implement `check` in `tools/backlog/backlog.py`: every rule of the `contracts/cli.md` table, output `<path>:<line>: <rule-id>: <message>` then `TOTAL: <n>`, exit 1 iff n > 0; section admission with the precedence of `contracts/overview-format.md`; cycle detection listing members
- [X] T014 [US1] Implement `sync` in `tools/backlog/backlog.py`: derive every cell except position and section from the items, number ordered sections `1..n`, sort *Inbox* (`created`, slug) and *Parked* / *Rejected* (area, slug); refuse with a list of differences when rows and items do not correspond one-to-one
- [X] T015 [US1] Implement `new` in `tools/backlog/backlog.py` per `contracts/cli.md` (template body with *Problem* / *Evidence* / *Expected* / *Log*, plus *Question* / *Options* / *Recommendation* for `decision` and *Steps* for `person-step`; status `new`; created/updated today; verified `-`; log "created (source …)"; *Inbox* row; check afterwards)
- [X] T016 [US1] Implement `list` in `tools/backlog/backlog.py` (backlog order, filters `--section --area --type --status --who --min-severity`, plain table or `--json` with `section` and `position`)
- [X] T017 [US1] Write `.claude/skills/tandem-backlog/SKILL.md`: front matter like `.claude/skills/speckit-specify/SKILL.md` (`name: tandem-backlog`, a description that triggers on adding, listing, triaging or changing backlog items, `argument-hint`, `user-invocable: true`, `disable-model-invocation: false`); operation router per `contracts/skills.md`; operations `add`, `list`, `show`, `check` fully described (others added in US2/US5); the four agent rules; "every mechanical change through `tools/backlog/backlog.py`, run `check` after changes"; Czech or English instructions, English files
- [X] T018 [P] [US1] Write `.claude/skills/tandem-backlog/reference.md`: the `desc.md` template per type (copy of `contracts/item-format.md` essentials), the severity anchors with two examples each from this project, how to write *Problem* / *Evidence* (user's view; `file:line` at a commit; fix-log or probe), the grouping rule (one item = one feature's worth), source forms with examples
- [X] T019 [US1] Run quickstart V1 (`python -m unittest tools/backlog/test_backlog.py -v`) and V4 on a scratch copy (`--root` pointing to a temporary copy of the repository's `backlog/`); record results in `specs/242-backlog-system/fix-log.md`

**Checkpoint**: MVP — items can be recorded and checked.

---

## Phase 4: User Story 2 — Triage, order and maintain items (P2)

**Goal**: the maintainer turns *Inbox* into an ordered plan and keeps items
current.

**Independent test**: ten *Inbox* items triaged into sections and ordered;
numbering consistent, statuses match sections, check passes (quickstart V5).

### Tests for User Story 2

- [X] T020 [US2] Add tests to `tools/backlog/test_backlog.py`: `move` *Inbox* → *Next* position 2 sets `open`, renumbers, logs, updates `Last triaged`; `move` to *Parked* / *Rejected* without `--reason` refused, with reason sets status and `reason`; `move` to *In progress* refused; `block` / `unblock` round trip; `set` refuses `status` and invalid values and sets `updated`; `set title=…` keeps the slug and updates the body's first line; `verify` writes `YYYY-MM-DD <short HEAD>`; `log` appends with today's date; reopening a rejected item clears `reason` only with a new log line

### Implementation for User Story 2

- [X] T021 [US2] Implement `set`, `log`, `verify` in `tools/backlog/backlog.py` per `contracts/cli.md` (`verify` reads `git rev-parse --short HEAD` unless `--commit`)
- [X] T022 [US2] Implement `move`, `block`, `unblock` in `tools/backlog/backlog.py` per `contracts/cli.md` (status implied by the target section, reason handling, `Last triaged` update, log lines, check afterwards)
- [X] T023 [US2] Extend `.claude/skills/tandem-backlog/SKILL.md` with `triage` (oldest *Inbox* item first, one question per item via the question tool: severity, section, position, `who`, `effort`, `depends-on`), `move`, `update`, `verify` (re-check at HEAD by reading the cited code or running the cited probe; `block` with "not reproduced at <commit>" when gone), `decide` (log the decision; convert to work type + section, or reject with the decision as reason), `park`, `reject`, `reopen`
- [X] T024 [P] [US2] Add triage guidance to `.claude/skills/tandem-backlog/reference.md` (how to choose a section, when to park vs reject, what *blocked* means vs *parked*, how to word a reason)
- [X] T025 [US2] Run quickstart V5 on a scratch copy; record in `specs/242-backlog-system/fix-log.md`

**Checkpoint**: the backlog can be ordered and maintained.

---

## Phase 5: User Story 3 — Migrate today's backlog and retire `NEXT-WORK.md` (P3)

**Goal**: every open entry lives in `backlog/`; the project points there.

**Independent test**: quickstart V2 and V3 — check passes on the migrated
backlog, the ledger accounts for every open entry, no instruction points to
`NEXT-WORK.md`.

**Rules for every migration task**: read the source at `7993914c` in full;
an entry struck through or marked done is recorded in the ledger as
`done (feature NNN)` and not turned into an item — only its still-open
"left:" parts are; one item = one feature's worth (group small related
leftovers); `source` = the origin the text names (`review:NNN`,
`leftover:NNN`, `measure:NNN`, `github#N`), otherwise `next-work`;
`created` = the date the entry was first recorded when stated, otherwise
2026-10-17; `verified` `-` unless a check at a commit is stated; the item's
*Evidence* cites the source section and the feature folders it names;
recorded maintainer decisions go to *Log* with their dates; items are
created with `tools/backlog/backlog.py new` and placed with `move`
(sections per research R12: work → *Next* in the old order, decisions →
*Decisions*, person steps → *Person steps*, decided-not-to-do → *Rejected*,
recorded-deliberately-not → *Parked* or *Rejected* by its wording). Each
task appends its rows to its own ledger part file
`specs/242-backlog-system/ledger/<part>.md` (table: Source · Destination).

- [X] T026 [US3] Create `specs/242-backlog-system/ledger/README.md` (columns, destination forms `item:<slug>`, `merged:<slug>`, `release-checklist`, `done (feature NNN)`, `not migrated: <reason>`; the rules above) and snapshot the sources: `git show 7993914c:specs/NEXT-WORK.md > specs/242-backlog-system/ledger/NEXT-WORK.7993914c.md` (kept until T034)
- [X] T027 [P] [US3] Migrate `NEXT-WORK.md` header block *Before 0.1.10 – steps owed to a person* and section **B. Steps owed to a person** into `person-step` items grouped by feature or topic; ledger part `ledger/b-person-steps.md`
- [X] T028 [P] [US3] Migrate section **A. Code work an agent can do** (items 1–19 with their letter sub-items; most entries done — migrate only open "left:" parts) into work items in *Next*, keeping the old order; ledger part `ledger/a-code-work.md`
- [X] T029 [P] [US3] Migrate section **C. Decided — not to do** and *Recorded, deliberately not on the list* into `rejected` / `parked` items with reasons and decision dates; ledger part `ledger/c-decided.md`
- [X] T030 [P] [US3] Migrate section **D. From the GitHub issues after 0.1.9** (decisions owed → `decision` items in *Decisions*, e.g. Network plug-in, Windows floor; code work; person steps; the two 2026-10-16 "stays in the backlog" decisions in the items' logs); ledger part `ledger/d-github.md`
- [X] T031 [P] [US3] Scan the numbered sections **R, 0–8** and *Protocol* for entries still open (queues "Found by 104" / "Found by 108" in item 5, item 3 sweeps, item 6 winget housekeeping, and others); migrate them; record every closed section as `done`; *Protocol* → `not migrated: rule, moved into the implement skill's stop-rules.md` (T042); ledger part `ledger/numbered-sections.md`
- [X] T032 [P] [US3] Migrate the open entries of `specs/068-encoding-regression-review/REMAINING-WORK.md`, `specs/069-finish-encoding-fixes/REMAINING-WORK.md`, `specs/070-source-viewer-plugin/REMAINING-WORK.md`, `specs/072-winget-distribution/REMAINING-WORK.md`, `specs/080-restart-manager-upgrade/REMAINING-WORK.md` (an entry already migrated from `NEXT-WORK.md` → `merged:<slug>`); ledger part `ledger/remaining-work.md`
- [X] T033 [US3] Consolidate: merge duplicate items created by T027–T032 (keep one slug, `merged:` in the ledger), fix `related` / `depends-on` across parts, run `python tools/backlog/backlog.py sync` and `check` until `TOTAL: 0`; assemble `specs/242-backlog-system/migration-ledger.md` from the parts with a count per destination kind
- [X] T034 [US3] Have an independent agent (refute-first) verify the ledger: sample at least 20 rows per source against `ledger/NEXT-WORK.7993914c.md` and the `REMAINING-WORK.md` files, search the sources for open entries missing from the ledger, check that no `done` row hides an open leftover; fix findings; record the review in `specs/242-backlog-system/fix-log.md`; then delete `ledger/NEXT-WORK.7993914c.md` (git keeps it)
- [X] T035 [US3] Fill `backlog/RELEASE.md` from `NEXT-WORK.md` (header *Revised 2026-10-14* block, section R, *At the next release, because of feature 123*) and `CLAUDE.md` *A release bumps …*: the release procedure as a checklist and the standing checks owed at each release; the 0.1.10 state (branch `release-0.1.10-final`, not `release-0.1.10`) as the current release section
- [X] T036 [US3] Add the one-line note at the top of each of the five `specs/*/REMAINING-WORK.md`: `> Open items moved to backlog/ on 2026-10-17 (feature 242); this file is a historical record.`
- [X] T037 [US3] Delete `specs/NEXT-WORK.md`
- [X] T038 [US3] Update `CLAUDE.md`: *Where things are* row "What to work on next" → `backlog/BACKLOG.md` (sections *Next*, *Decisions*, *Person steps*) and `/tandem-backlog`; the standing rule "Serious defects found on the way go to `specs/NEXT-WORK.md`…" → "…are added to `backlog/` *Inbox* with `/tandem-backlog add` (source `review:NNN` / `leftover:NNN`) and fixed one by one, not inside the current feature (242)"; *Status* line about person steps → `backlog/` *Person steps* and `backlog/RELEASE.md`; the repository map gains `backlog/`
- [X] T039 [P] [US3] Update the header of `specs/FEATURE-HISTORY.md` ("open items are tracked in `specs/NEXT-WORK.md`" → `backlog/BACKLOG.md`); leave entries citing NEXT-WORK as history
- [X] T040 [US3] Stage the deletion of `issues/` and `features/` (already deleted in the working tree by the maintainer: `git add -A issues features`) for the feature commit; add an *Inbox* item "CLAUDE.md names a branch ai-main that does not exist" (source `measure:242`, area `tooling`)
- [X] T041 [US3] Run quickstart V2 and V3; record results in `specs/242-backlog-system/fix-log.md`

**Checkpoint**: one backlog, all open work in it, the project points to it.

---

## Phase 6: User Story 4 — Implement one backlog item autonomously (P4)

**Goal**: one command runs one eligible item through the Spec Kit flow, or
stops with a record.

**Independent test**: quickstart V7 (dry run) and V8 (safe refusals); V9 is
the maintainer's first real run.

### Tests for User Story 4

- [X] T042 [US4] Add tests to `tools/backlog/test_backlog.py`: `next` skips `blocked`, `who: person`, `decision`, `person-step`, unmet `depends-on` and reports reasons, returns `nothing-to-do` on an empty *Next*, fails for an ineligible `--slug`; `start` moves to *In progress* with `feature`; `remove` deletes folder and row and strips the slug from other items' `related` / `depends-on` with a log line; `run-log` appends a row with each outcome and refuses others; `lock acquire` twice → second fails naming the holder; `lock status` reports `stale` past 24 hours (clock injected); `lock release` with the wrong slug refused, `--force` works; lock path from `git rev-parse --git-common-dir`

### Implementation for User Story 4

- [X] T043 [US4] Implement `next`, `start`, `remove`, `run-log` in `tools/backlog/backlog.py` per `contracts/cli.md`
- [X] T044 [US4] Implement `lock acquire|release|status` in `tools/backlog/backlog.py` per research R8 (exclusive create, fields `started`, `slug`, `branch`, `host`, 24-hour staleness, injectable clock for tests)
- [X] T045 [US4] Write `.claude/skills/tandem-backlog-implement/stop-rules.md`: maintainer-owned questions (research R11 list), stop conditions (FR-036 + failed fast-forward + dirty tree), the project rules a run follows with pointers into `CLAUDE.md` (*Working method*, *Never lose the user's data*, hidden-desktop probes and registry backup, NOT DRIVEN rows, refute-first review, no push), and the binding fix rules of `specs/069-finish-encoding-fixes/contracts/fix-protocol.md` that `NEXT-WORK.md` *Protocol* carried (check the site at HEAD first; enumerate consumers before writing)
- [X] T046 [US4] Write `.claude/skills/tandem-backlog-implement/SKILL.md`: front matter (`name: tandem-backlog-implement`, description, `argument-hint: "[slug] [--dry-run]"`, `user-invocable: true`, `disable-model-invocation: false`); the procedure of `contracts/skills.md` steps 1–8 with the exact tool and git commands (lock, `next`, measure first, `.specify/extensions/git/scripts/bash/create-new-feature.sh --json --short-name …`, `start`, Spec Kit skills in order with optional commit hooks treated as accepted and clarify answered per `stop-rules.md`, closing with `remove`, `new` for leftovers, `FEATURE-HISTORY.md` entry, `closing-report.md`, `run-log`, `[NNN]` commit, `git checkout main`, `git merge --ff-only`, stop path with `[NNN] stopped:` commit and `backlog: <slug> blocked (NNN)` commit on `main`, lock release in every path); `--dry-run`; the "never" list; the final message format; one item per run
- [X] T047 [US4] Run quickstart V7 and V8 in a temporary clone of the repository (`git clone` of the feature branch into the scratchpad, its `main` reset to the feature branch), so V8's `nothing-to-do` journal commit and the lock never touch this repository's `main`; record in `specs/242-backlog-system/fix-log.md`; record V9 as owed to the maintainer

**Checkpoint**: autonomous runs are possible and refuse safely.

---

## Phase 7: User Story 5 — Import a GitHub issue as an item (P5)

**Goal**: a GitHub issue becomes an item with its original text.

**Independent test**: quickstart V6.

- [X] T048 [US5] Add tests to `tools/backlog/test_backlog.py` for `import-github` with the HTTP call replaced by a stub (issue + two comments → `issue.md` verbatim with header lines, `reply.md` `state: not-sent`, item `new` with `source: github#N`; second import refused naming the item; network error → exit 1, nothing written)
- [X] T049 [US5] Implement `import-github` in `tools/backlog/backlog.py` per research R6 and `contracts/cli.md` (`urllib.request` to `api.github.com/repos/tandemcommander/tandemcommander/issues/N` and `/comments`, `gh` used when on `PATH`, `User-Agent` header, timeout, no token)
- [X] T050 [US5] Add `import-github` to `.claude/skills/tandem-backlog/SKILL.md` (propose type, severity, area from the text; never post `reply.md`)
- [X] T051 [US5] Run quickstart V6 against a real issue (e.g. #5) on a scratch copy; record in `specs/242-backlog-system/fix-log.md`

---

## Phase 8: Polish & cross-cutting

- [X] T052 Have an independent agent review (refute-first) `tools/backlog/backlog.py`, its tests and both skills against `contracts/` and the spec's FR / SC; fix findings; record in `specs/242-backlog-system/fix-log.md`
- [X] T053 [P] Update the assistant's memory: rewrite `next-work-after-winget.md` (pointer to `backlog/BACKLOG.md` and `/tandem-backlog`, not `specs/NEXT-WORK.md`) and its line in `MEMORY.md`
- [X] T054 Append the feature entry `- 242-backlog-system: …` at the end of `specs/FEATURE-HISTORY.md` (what changed, the traps met, the evidence) and add `242` to its index row for build/tooling
- [X] T055 Run quickstart V1–V8 once more on the final tree, `python tools/backlog/backlog.py check` → `TOTAL: 0`, `git status` shows nothing under `specs/` except this feature's folder, `FEATURE-HISTORY.md`, `NEXT-WORK.md` deletion and the five notes; write `specs/242-backlog-system/closing-report.md` (results, V9 owed to the maintainer, counts from the ledger)

---

## Dependencies & execution order

- **Phase 1 → Phase 2 → stories.**
- **US1** needs Phase 2. **US2** needs US1 (`check`, `sync`). **US3** needs
  US1 and US2 (`new`, `move`, `sync`, `check`). **US4** needs US1 and US2;
  its skill's `stop-rules.md` (T045) takes over *Protocol* from US3's T031,
  so run US4 after US3 or keep T031's ledger row pointing to T045. **US5**
  needs US1 only.
- **Polish** after all stories.

Story completion order: US1 → US2 → US3 → US4; US5 may run any time after
US1.

## Parallel opportunities

- Phase 2: T008, T009 beside T003–T007.
- US1: T010 and T011 (fixtures) in parallel; T018 beside T013–T016.
- US2: T024 beside T021–T023.
- US3: **T027–T032 in parallel** (one agent per source part, each writing
  its own ledger part); T033 then consolidates; T039 beside T038.
- US5 entirely in parallel with US3/US4 once US1 is done.

Example (US3):

```text
Agent A: T027 person steps          Agent D: T030 section D
Agent B: T028 section A             Agent E: T031 numbered sections
Agent C: T029 decided / parked      Agent F: T032 REMAINING-WORK files
→ T033 consolidation → T034 independent ledger review
```

## Implementation strategy

1. **MVP** = Phases 1–3 (US1): the formats, the tool's `check` / `sync` /
   `new` / `list`, the management skill's basic operations. Stop and
   validate with V1 and V4.
2. US2 makes it a plan; US3 makes it the only backlog — after US3 the old
   files are retired, so do not start US3 before US1 + US2 pass.
3. US4 adds the autonomous run; US5 the GitHub import.
4. Commit at the end as `[242] …` (the Spec Kit commit hooks may add
   intermediate `[Spec Kit] …` commits, as configured).
