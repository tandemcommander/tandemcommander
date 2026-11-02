# Tasks: User Menu compare names and the Change Icon file are never cut

**Input**: `specs/389-compare-icon-fits/` - plan.md, spec.md, research.md, quickstart.md
**Tests**: the GUI probe `probe/fit389_probe.ps1` (the item asks for probe rows before FAIL /
after PASS and a fitting control).

## Phase 1: Setup

- [X] T001 Record the before measurement (probe `result_before.txt`, `result_before_chi.txt`) and the callers in specs/389-compare-icon-fits/fix-log.md

## Phase 2: Foundational

(none - `DlgItemTextFitsU8` exists, declared in src/dialogs.h)

## Phase 3: User Story 1 - names to compare used whole or refused (P1)

**Goal**: a name over 259 bytes is refused on OK, nothing is started.
**Independent test**: probe rows umc-name1, umc-name2 (refused), umc-ctl (whole).

- [X] T002 [US1] In `CCompareArgsDlg::Validate` (src/dialogs2.cpp) measure `IDE_UMC_NAME1`, then `IDE_UMC_NAME2` with `DlgItemTextFitsU8(HWindow, id, &ti, MAX_PATH)` before the empty checks; return on a refusal

## Phase 4: User Story 2 - the Change Icon file used whole or refused (P2)

**Goal**: a file name over 259 bytes is refused at the reload and on OK, the field keeps it.
**Independent test**: probe rows chi-file (refused twice), chi-ctl (loaded, stored whole).

- [X] T003 [US2] Declare `virtual void Validate(CTransferInfo& ti);` in `CChangeIconDialog` (src/dialogs.h)
- [X] T004 [US2] Implement `CChangeIconDialog::Validate` with `DlgItemTextFitsU8(HWindow, IDE_CHI_FILENAME, &ti, MAX_PATH)` (src/dialogs3.cpp)
- [X] T005 [US2] At the top of `CChangeIconDialog::LoadIcons` (src/dialogs3.cpp) refuse with `DlgItemTextFitsU8(HWindow, IDE_CHI_FILENAME, NULL, MAX_PATH)` and return FALSE before reading the field or touching the list

## Phase 5: Polish & verification

- [X] T006 Encoding guard `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`
- [X] T007 Build `.\build.cmd` → `BUILD SUCCEEDED`; saltests → `0 failed`
- [X] T008 Probe after (quickstart.md) → every row PASS; record in specs/389-compare-icon-fits/fix-log.md
- [X] T009 [P] Regression probes 291 (`specs/291-masks-cut-rest/probe/mask291_probe.ps1`) and 251 (`specs/251-dialog-text-fits/probe/dlg251_probe.ps1`) → 0 FAIL; results in specs/389-compare-icon-fits/probe/
- [X] T010 Negative control: the after-probe against a build without T005 (Validate only) shows chi-file FAIL - record in specs/389-compare-icon-fits/fix-log.md

## Dependencies

T001 → T002..T005 (T002 independent of T003-T005) → T006, T007 → T008, T009, T010.

## Parallel opportunities

T002 and T003-T005 touch different files; T009's two probes run one after the other (they share
the registry key) but in parallel with writing the fix-log.

## Implementation strategy

MVP = US1 (T002). US2 follows; all checks run once on the complete change.
