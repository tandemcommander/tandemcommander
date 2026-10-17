# Tasks: Release Preparation Skill `tandem-release`

**Input**: Design documents from `specs/243-tandem-release-skill/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: requested by the plan (research R14): unit tests of
`tools/release/release.py` on a miniature repository, written with each part.

**Organization**: grouped by the user stories of spec.md. The tool is shared,
so its foundation comes first; each story then adds the commands or rules it
needs and its tests.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T001 Create `specs/243-tandem-release-skill/fix-log.md` (running log: date, step, finding, decision) and the folder `tools/release/fixtures/`
- [X] T002 Create the tool skeleton `tools/release/release.py`: SPDX header and docstring in the style of `tools/backlog/backlog.py` (records list = contracts/records.md, design rules, exit codes 0/1/2), `argparse` with subcommands `status`, `stamp`, `check`, `summary` and the common options `--date`, `--root`, `--offline`, `--json`, `--dry-run` per contracts/cli.md
- [X] T003 [P] Create the miniature records in `tools/release/fixtures/` (`spl_vers.h` with BOM and build-history block, `tandemcommander.iss`, `CHANGELOG.md` with sections 0.1.1 and 0.1.0 plus an unreleased section, `PRIVACY.md` last block, `CLAUDE.md` product line and *Status*, `12-project-reference.md` product line, `RELEASE.md` *Current release*, `versinfo.rh2` copyright line, one `release_notes_v0.1.1.md`, `backlog/items/<slug>/desc.md` for one person step) and `tools/release/fixtures/README.md` explaining how the tests build a git repository from them

## Phase 2: Foundational (blocks every story)

- [X] T004 Implement record I/O in `tools/release/release.py`: read bytes, detect BOM and dominant EOL, expose text with `\n`, write back with the same BOM/EOL atomically (temp file + `os.replace`), skip the write when content is unchanged
- [X] T005 Implement `Version` (canonical regex of research R3, ordering, `same_line`, tag, installer name) and git helpers (`git tag --list 'v*'`, `git show <tag>:<path>`, `ls-remote` with `--offline`/failure → `unknown`, branch, short HEAD, porcelain status) in `tools/release/release.py`
- [X] T006 Implement the parsers in `tools/release/release.py`: `spl_vers.h` macros and build-history entries, `MyAppVersion`, changelog sections (heading, lead, groups, entries per data-model.md), PRIVACY last block, CLAUDE/reference product lines, `## Status (…)`, *Current release* heading and `Gating person steps:` list, release-notes header/sections/footer, `VERSINFO_COPYRIGHT` year
- [X] T007 Implement the release context of data-model.md (prev, prev_build, build, features/issues of the release region, interface_changed, release_branches, gating with open/done, gating_candidates) and the state machine (not-prepared / prepared-earlier / prepared-today / released / inconsistent) in `tools/release/release.py`
- [X] T008 Write the test harness in `tools/release/test_release.py`: build a temp git repo from fixtures (commit + tag `v0.1.0`, `v0.1.1` with the right build numbers), helpers to mutate one record, run commands in-process with `--root` and `--offline`, capture output and exit code; tests of T004 (BOM + CRLF round trip, no rewrite of unchanged file) and T005 (version forms, ordering, previous tag)

**Checkpoint**: `python -m unittest tools/release/test_release.py` green for I/O, versions, parsing and states.

## Phase 3: User Story 1 — Prepare a new version for release today (P1) 🎯 MVP

**Goal**: from a not-prepared tree, `stamp` sets all eight records for x.y.z / build prev+1 / date.
**Independent Test**: fixture repo tagged `v0.1.1` (build 185) with `[Unreleased]` → `stamp 0.1.2 --date 2026-11-02` then the records show 0.1.2 / 186 / 2026-11-02; a second `stamp` prints `unchanged`.

- [X] T009 [US1] Implement `status` output (text and `--json`) per contracts/cli.md in `tools/release/release.py` (refusals left to US3)
- [X] T010 [US1] Implement `stamp` for `spl_vers.h` (MAJOR/MINORA/MINORB, `VERSINFO_BUILDNUMBER`, history entry `// N - Tandem Commander x.y.z (TODO-SUMMARY; see CHANGELOG.md)` inserted above `// ! DULEZITE` only if missing) and `tandemcommander.iss` in `tools/release/release.py`
- [X] T011 [US1] Implement the changelog fold of research R4 for one unreleased section (heading `## [x.y.z] — <date>`, lead kept or placeholder `**Build N.** TODO-KIND release. TODO-SUMMARY`, history verification against tags) in `tools/release/release.py`
- [X] T012 [US1] Implement `stamp` for `PRIVACY.md` (describes `<ver>`, shift `In <P-old>, the version before it,` → `In <P-old>:` and insert `In <P>, the version before it, TODO-PRIVACY.` for a new version, `Last updated <date>.`) in `tools/release/release.py`
- [X] T013 [US1] Implement `stamp` for the product lines of `CLAUDE.md` and `architecture/12-project-reference.md` (version, build, release dated, feature range from the section, previous version/build/tag) and the `## Status (<date>)` heading, and for the `RELEASE.md` *Current release* heading, in `tools/release/release.py`
- [X] T014 [US1] Implement the release-notes skeleton / header update (`**Released <d Month yyyy> · build N · Windows 11 or newer, 64-bit · TODO-KIND**`, sections with `TODO`, fixed footer, UTF-8 without BOM, CRLF like the other notes) in `tools/release/release.py`
- [X] T015 [US1] Tests in `tools/release/test_release.py`: new-version stamp of all eight records, PRIVACY shift, feature range, notes skeleton, idempotence (second stamp = `unchanged`, no file mtime change), long date format for single-digit days

**Checkpoint**: US1 independently testable.

## Phase 4: User Story 2 — Re-prepare a prepared, unpublished version (P1)

**Goal**: prepared-earlier tree → dates move, later unreleased sections fold in, build kept.
**Independent Test**: fixture with `[0.1.2] — 2026-10-14` + `[0.1.3] — unreleased` above it, source at 0.1.2/186 → `stamp 0.1.2 --date 2026-10-17` gives one section dated 2026-10-17, entries of 0.1.3 first, build 186 kept, all dates moved.

- [X] T016 [US2] Extend the fold in `tools/release/release.py`: several sections above prev (`[Unreleased]`, `[higher] — unreleased`, dated `[x.y.z]`), keep the target's own lead, drop the others and print `dropped-lead:` lines, refuse when more than one section has `###` groups
- [X] T017 [US2] Make every `stamp` step date-aware for an already stamped version (changelog heading date, PRIVACY `Last updated`, `release dated`, `## Status`, notes header) and keep an existing build-history entry in `tools/release/release.py`
- [X] T018 [US2] Tests in `tools/release/test_release.py`: fold of 2 sections with dropped lead, order of entries, groups refusal, date move in all records, build kept, `prepared-today` after the stamp and the check fixes

## Phase 5: User Story 3 — Refuse what must not be prepared (P1)

**Goal**: every refusal of contracts/cli.md stops `status` and `stamp` with nothing changed.
**Independent Test**: for each condition, `stamp` exits 1 and `git status --porcelain` is empty.

- [X] T019 [US3] Implement refusals `version-form`, `tag-exists` (local, remote), `not-higher`, `line-change`, `dirty-tree`, `lock-held` (via `python tools/backlog/backlog.py lock status`, skipped when the tool is absent in the test root), `copyright-year`, `no-previous-tag`, `inconsistent: <why>` and warnings `branch-not-main`, `minorb-skip`, `remote-unknown`, `build-dir`, `certificate`, `release-branch-ahead` in `tools/release/release.py`
- [X] T020 [US3] Tests in `tools/release/test_release.py`: one per refusal (tree unchanged), one per warning, `stamp` refuses whenever `status` refuses

## Phase 6: User Story 4 — Verify the prepared tree (P2)

**Goal**: `check` and `summary` find every inconsistency, naming file and line.
**Independent Test**: after a correct stamp + wording, `check` = 0 findings; each seeded defect yields exactly its rule.

- [X] T021 [US4] Implement `summary` in `tools/release/release.py` as an exact replica of `Get-ReleaseSummary`, `Format-BlockScalar` and the `#`-line drop of `Render-Template` (`tools/winget/publish.ps1:135-207`)
- [X] T022 [US4] Implement `check` with the rules of contracts/cli.md except the `notes-*` rules in `tools/release/release.py`
- [X] T023 [US4] Tests in `tools/release/test_release.py`: summary replica against known inputs (links, bold, dashes, quotes, > 900 cut, a wrapped line starting with `#`, a bullet lead); one seeded defect per non-notes rule
- [X] T024 [US4] Cross-check the replica on the real tree: compute `summary 0.1.9` and compare with `ReleaseNotes` of `tools/winget/manifests/0.1.9/PavelStupka.TandemCommander.locale.en-US.yaml`; record the result in `specs/243-tandem-release-skill/fix-log.md`

## Phase 7: User Story 5 — Release notes in the established format (P2)

**Goal**: the notes file is checked for header, sections, footer, issues, encoding.
**Independent Test**: the published `release_notes/release_notes_v0.1.9.md` passes the notes rules for 0.1.9 (with its own date and build); each seeded defect yields its rule.

- [X] T025 [US5] Implement the `notes-missing`, `notes-header`, `notes-sections`, `notes-footer`, `notes-issues`, `notes-todo`, `notes-encoding` rules in `tools/release/release.py` (a notes-only check mode usable on a published version for the test above)
- [X] T026 [US5] Tests in `tools/release/test_release.py`: one seeded defect per notes rule; the real 0.1.9 notes copied into the fixture repo pass

## Phase 8: User Story 6 — The skill, hand-over report and dry run (P3)

**Goal**: `/tandem-release` runs the procedure of contracts/skill.md; `--dry-run` changes nothing.
**Independent Test**: quickstart V2/V3 on the real tree (no change) and V4/V5 on a throw-away worktree.

- [X] T027 [US6] Implement `stamp --dry-run` (same output, no write) and the final `changed: N file(s)` / `unchanged` line in `tools/release/release.py`; test in `tools/release/test_release.py`
- [X] T028 [US6] Write `.claude/skills/tandem-release/reference.md`: the eight records and their formats (contracts/records.md), the wording rules (lead, build comment, privacy sentence, release notes style with examples from 0.1.9/0.1.10, *Status*, *Current release*), the privacy triggers, the traps of research F1–F13, the maintainer's steps
- [X] T029 [US6] Write `.claude/skills/tandem-release/SKILL.md`: front matter of contracts/skill.md, arguments, contract (never-list, tools, quoting rules), steps 1–10 with the exact questions, content review, wording, verification, backlog, commit template, final report
- [ ] T030 [US6] Run quickstart V2 and V3 on the real tree; record outputs and any fix in `specs/243-tandem-release-skill/fix-log.md`

## Phase 9: Polish & cross-cutting

- [X] T031 Rewrite the procedure parts of `backlog/RELEASE.md`: new *Release records* section (the eight records), *Preparing the tree* = run `/tandem-release <x.y.z>`, `temp/` → `release_notes/`, *Releasing* step 1 "another day = run the skill again", SHA-256/VirusTotal step removed, closing-pass reference `8e5d6c8a`, and `Gating person steps:` list in *Current release* with the four slugs of 0.1.10
- [X] T032 [P] Amend `.specify/memory/constitution.md` to 3.2.0 (*Release Documentation*: groups optional, bullets citing feature/issue accepted, lead `**Build N.** <Kind> release.` required, record list → `backlog/RELEASE.md` *Release records* and `/tandem-release`; Sync Impact Report; Last Amended 2026-10-17)
- [X] T033 [P] Update `CLAUDE.md`: *Where things are* row for releasing (`/tandem-release`, `tools/release/`), *Product identity* "A release bumps …" → pointer to *Release records* and the skill, constitution v3.2.0, one standing-rule line (243)
- [X] T034 Add the two *Inbox* items through `python tools/backlog/backlog.py new` (source `review:243`): old copyright notices without the Tandem holder; stale `PrivilegesRequiredOverridesAllowed` claim in `tools/winget/README.md:204` (related `winget-records-stale-claims-from-072-audit`); fill their bodies; `backlog.py check` 0 findings
- [ ] T035 Run quickstart V4 and V5 on a throw-away worktree of `main` in the scratch directory (dry run of the skill procedure end to end with `stamp`, wording, `check`, `check_encoding`, commit there), remove the worktree; record in `specs/243-tandem-release-skill/fix-log.md`
- [ ] T036 Independent refute-first review (agent) of `tools/release/`, the skill and the record changes; fix confirmed findings; record in `specs/243-tandem-release-skill/fix-log.md`
- [ ] T037 Add entry `243-tandem-release-skill` to `specs/FEATURE-HISTORY.md` and write `specs/243-tandem-release-skill/closing-report.md`; final run of `python -m unittest tools/release/test_release.py`, `python tools/backlog/backlog.py check`, `python tools/check_encoding.py --strict`

## Dependencies & Execution Order

- Phase 1 → Phase 2 → stories. US1 (T009–T015) before US2 (extends the
  fold and stamp). US3 needs only Phase 2 and T009. US4 needs US1's records.
  US5 independent of US2–US4 after Phase 2. US6 needs US1–US5 (the skill
  calls every command). Polish T031–T033 can run in parallel with US6;
  T035–T037 last.

### Parallel opportunities

- T003 with T002; T032 with T033 (different files); T025–T026 alongside
  T021–T024 once Phase 2 is done (same file `release.py` though — sequential
  edits in practice).

## Implementation Strategy

MVP = Phase 1–3 (stamp of a new version) + US3 refusals; then US2 (the
0.1.10 situation), US4/US5 checks, the skill, and the record changes. Each
checkpoint keeps the unit tests green.
