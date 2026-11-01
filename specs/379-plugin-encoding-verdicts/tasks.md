# Tasks: every finding of the plug-in encoding scan has a verdict

**Input**: `specs/379-plugin-encoding-verdicts/` (spec.md, plan.md, research.md, data-model.md,
quickstart.md)

## Phase 1: Setup

- [X] T001 Measure the scan at HEAD 3e0da39c and diff it against 255's baseline; save
  `specs/379-plugin-encoding-verdicts/baseline_3e0da39c.txt` and record in `fix-log.md`
- [X] T002 Carry over 255's markers (`git apply -3`), resolve the `src/plugins/ftp/ftputils.cpp`
  conflict without row 41's marker, copy 255's record into `specs/379-plugin-encoding-verdicts/`

## Phase 2: Foundational

- [X] T003 Re-check every carried marker in the 11 files `main` changed since 255 against its line at
  HEAD (`src/plugins/codeview/intake.cpp`, `filecomp/mainwnd.cpp`, `ftp/ftputils.cpp`,
  `mdview/htmlgen.cpp`, `mdview/viewer.cpp`, `regedt/finddlg2.cpp`, `uncab/uncab.cpp`,
  `uniso/iso9660.cpp`, `uniso/udf.cpp`, `uniso/udfiso.cpp`, `zip/add.cpp`); record in `fix-log.md`

## Phase 3: User Story 1 - the maintainer knows which findings are real (P1)

**Independent test**: the scan reports exactly the *real defect* rows of `verdicts.md`.

- [X] T004 [US1] Drop the markers of rows 3, 67, 68, 75 in `src/plugins/checkver/dialogs.cpp`,
  `src/plugins/tar/tardll.cpp`, `src/plugins/uncab/uncab.cpp`, `src/plugins/unmime/parser.cpp`
- [X] T005 [US1] Add the 4 false-positive markers in `src/plugins/codeview/config.cpp`
- [ ] T006 [US1] Create the backlog items (bin/backlog.sh, Inbox, source `measure:379`): CheckVer
  filter names, TAR / UnCAB / UnMIME archive names in WTF-8 - one per plug-in, bodies complete
- [ ] T007 [US1] Add the TAR and UnCAB items to `depends-on` of
  `backlog/items/plugin-encoding-scan-strict-in-build/desc.md` (via bin/backlog.sh)
- [ ] T008 [US1] Write `specs/379-plugin-encoding-verdicts/verdicts.md`: 82 rows with lines at HEAD
  (scripted from 255's table, the scan and the markers), each false-positive reason equal to its
  marker
- [ ] T009 [US1] Check: the scan's `--format list` sites equal the *real defect* rows; every
  *real defect* slug exists in `backlog/items/`; every false-positive reason equals its marker

## Phase 4: User Story 2 - a new defect stands out (P2)

- [ ] T010 [US2] Negative control: one bad line appended to `src/plugins/dbviewer/dialogs.cpp` is
  reported, file restored; markers stripped in a copy of `tools/` + `src/plugins` under %TEMP% give
  back the 81 of `baseline_3e0da39c.txt`

## Phase 5: Polish

- [ ] T011 `python tools/check_encoding.py --strict` → `TOTAL: 0`; source diff comments only;
  `.\build.cmd` → `BUILD SUCCEEDED`; record in `fix-log.md`

## Dependencies

T001 → T002 → T003 → T004/T005 → T006 → T007 → T008 → T009 → T010 → T011. T004 and T005 are
independent of each other.

## Implementation strategy

US1 is the feature; US2 is its check. No test code (the guard is the test).
