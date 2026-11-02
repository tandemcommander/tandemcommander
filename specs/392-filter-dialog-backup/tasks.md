# Tasks: Filter dialog keeps a long panel filter whole after a refused edit

**Input**: `specs/392-filter-dialog-backup/` (plan.md, spec.md, research.md, data-model.md, quickstart.md)
**Tests**: the hidden-desktop probe of the spec's Independent Test (no new saltests rule - the change is
"do not write the panel's group", not a pure decision).

## Phase 1: Setup

- [X] T001 Confirm the probe `specs/392-filter-dialog-backup/probe/flt392_probe.ps1` runs from its folder with the default library path (`..\..\098-long-path-overruns\probe\fix_probe_lib.ps1`) and `probe/result_before.txt` records `long-refused` FAIL at fc9b8691

## Phase 2: Foundational

- [X] T002 Enumerate the consumers: every caller of `CFilterDialog` and every reader of the panel `Filter` after the dialog (`src/fileswn9.cpp` `ChangeFilter`), and confirm winliblt runs `Transfer` only after a good `Validate` (`src/common/winlib.cpp`); record in `specs/392-filter-dialog-backup/fix-log.md`

## Phase 3: User Story 1 - a refused edit leaves the panel filter as it was (P1)

**Goal**: `Validate` checks the typed text in a local `CMaskGroup` with the panel filter's mode; the panel's group is never written there.
**Independent test**: probe row `long-refused` PASS (300 of 300 bytes), `short-refused` and `long-valid` PASS.

- [X] T003 [US1] In `src/dialogs3.cpp` `CFilterDialog::Validate`, replace the `char buf[MAX_PATH]` backup / `Filter->GetWritableMasksString()` / `Filter->SetMasksString(buf)` sequence by a local `CMaskGroup` (`SetMasksString("", Filter->GetExtendedMode())`, `ti.EditLine(IDE_FILTER, check.GetWritableMasksString(), MAX_PATH)`, `check.PrepareMasks(errorPos)`), keeping the error box, focus, selection and `ti.ErrorOn` unchanged; English comment naming feature 392
- [X] T004 [US1] Build Debug x64 (`.\build.cmd`) and run the probe on the hidden desktop into `specs/392-filter-dialog-backup/probe/result_after.txt` (quickstart.md); rows long-refused, short-refused, long-valid, long-refused-then-valid
- [X] T005 [US1] Negative control: confirm `result_before.txt` (old code) fails `long-refused` and the after run passes; record both in `specs/392-filter-dialog-backup/fix-log.md`

## Phase 4: Polish

- [X] T006 [P] Encoding guard `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T007 [P] saltests (`build\tandemcommander\Debug_x64\saltests\saltests.exe`) -> `0 failed`
- [X] T008 Update `specs/392-filter-dialog-backup/fix-log.md` with the change, the checks and their numbers

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005; T006 and T007 after T003; T008 last. One story (MVP = US1).

## Parallel opportunities

T006 and T007 run in parallel once the build of T004 exists.
