# Tasks: every finding of the plug-in encoding scan has a verdict

**Input**: `specs/255-plugin-encoding-findings/` (spec.md, plan.md, research.md, data-model.md,
quickstart.md)
**Tests**: no new automated tests (spec: no behaviour change); the checks are the guard's counts,
the build and a negative control (SC-002..SC-004).

## Phase 1: Setup

- [X] T001 Save the scan at e849e68c (`check_encoding.py --plugins --format list`) as the baseline
  in `specs/255-plugin-encoding-findings/baseline_e849e68c.txt` and start
  `specs/255-plugin-encoding-findings/fix-log.md` with the measurement

## Phase 2: Foundational

- [X] T002 Confirm per plug-in how its `LoadStr` returns text (code page or UTF-8) and that it is
  built without `UNICODE`; record in `specs/255-plugin-encoding-findings/fix-log.md` (needed by the
  `mixed-composition` / `ansi-template-number` / sink verdicts)

## Phase 3: User Story 1 - the maintainer knows which findings are real (P1)

**Goal**: 78 of 78 findings have a verdict; false positives annotated; real defects tracked.
**Independent test**: quickstart steps 1, 2, 6.

- [X] T003 [US1] Read the 18 `utf8-to-legacy-sink` sites (7zip, automation, dbviewer, filecomp,
  zip, zip/selfextr) with their producers; verdicts into
  `specs/255-plugin-encoding-findings/verdicts.md`
- [X] T004 [P] [US1] Read the 6 `mixed-composition` and 2 `ansi-template-number` sites (checkver,
  mmviewer, pictview, unmime, zip); verdicts into `verdicts.md`
- [X] T005 [P] [US1] Read the 2 `dead-dispinfow` sites (ftp/dialogs6.cpp, regedt/finddlg2.cpp);
  verdicts into `verdicts.md`
- [X] T006 [P] [US1] Read the 12 `strict-probe-rejects-wtf8` sites; verdicts into `verdicts.md`
- [X] T007 [P] [US1] Read the 38 `lossy-lenient-at-intake` sites; verdicts into `verdicts.md`
- [X] T008 [US1] Put the `// encoding-check: allow <rule> - <reason>` marker on every false-positive
  site in `src/plugins/**` (comments only)
- [X] T009 [US1] Create one Inbox item per plug-in and defect class for the real defects
  (`/tandem-backlog` rules, source `measure:255`) and write their slugs into `verdicts.md`
- [X] T010 [US1] Create the follow-up item "the build runs the plug-in scan strictly" depending on
  the real-defect items (FR-007)
- [X] T011 [US1] Check: the scan's TOTAL equals the `real defect` rows and the listed sites are
  exactly those rows (quickstart 1-2); record in `fix-log.md`

## Phase 4: User Story 2 - a new defect stands out (P2)

**Independent test**: quickstart step 5.

- [X] T012 [US2] Negative control: add one unannotated sink line to a plug-in source, run the
  scan, see +1, remove it; record in `fix-log.md`

## Phase 5: Polish

- [X] T013 `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`; `.\build.cmd` →
  `BUILD SUCCEEDED`; record in `fix-log.md`
- [X] T014 Confirm `git diff main -- src` holds only comment lines (FR-004); record in `fix-log.md`

## Dependencies

T001 → T002 → T003..T007 (T004-T007 parallel) → T008, T009 → T010 → T011 → T012 → T013, T014.

## Implementation strategy

US1 is the whole value; US2 is a check of the same result.
