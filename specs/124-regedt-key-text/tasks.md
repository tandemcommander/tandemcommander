# Tasks: Registry Editor shows the "KEY" text correctly in every language (feature 124)

**Input**: `specs/124-regedt-key-text/` - spec.md, plan.md, research.md, data-model.md, quickstart.md
**Tests**: requested by the maintainer ("independent tests for every issue") - the GUI probe and the static check are tasks of their own.

## Phase 1: Setup

- [x] T001 Preserve the 0.1.9 Debug tree as the control build in `build/tandemcommander/Debug_x64_v019` (without `Intermediate`)
- [x] T002 [P] Write the owner-drawn-text helper `specs/124-regedt-key-text/probe/shotocr_lib.ps1` (PrintWindow, crop, Windows text recognition)
- [x] T003 Write the probe `specs/124-regedt-key-text/probe/regkey_probe.ps1` (rows COL, INFO, SEL, FIND, END per language)

## Phase 2: Foundational (measure first)

- [x] T004 Run the probe on the control build in nine languages; record `specs/124-regedt-key-text/probe/regkey_result_before_v019.txt` and the crops in `probe/shots/before_*`
- [x] T005 Start `specs/124-regedt-key-text/fix-log.md` with the measurement and the decisions (research R1-R7)

## Phase 3: User Story 1 - the information line names a key (P1)

**Independent test**: rows `<lang> INFO` and `<lang> COL` of the probe, nine languages.

- [x] T006 [US1] `src/plugins/regedt/regedt.h`: declare `extern char KeyText[100]` (UTF-8), `extern WCHAR KeyTextW[32]`, keep `KeyTextLen`
- [x] T007 [US1] `src/plugins/regedt/fs.cpp`: define both; in `InitFS` copy `LoadStrW(IDS_KEY)` into `KeyTextW` when it is non-empty and shorter than 32 units, else `L"KEY"`; make `KeyText` with `WStrToU8`, on failure both become `KEY`; set `KeyTextLen`
- [x] T008 [P] [US1] Write `specs/124-regedt-key-text/probe/check_key_lengths.py`: id 1007 of every `translations/*/regedt.slt` is non-empty, under 32 UTF-16 units and under 100 UTF-8 bytes; prints a table, exit code = violations

## Phase 4: User Story 2 - the selection text (P1)

**Independent test**: rows `<lang> SEL` of the probe (crops looked at), nine languages.

- [x] T009 [US2] `src/plugins/regedt/regedt.h` + `regedt.cpp`: add `BOOL LoadStrU8(int resID, char* buf, int bufSize)` (wide resource text to UTF-8; when it does not fit or is empty, the code-page text copied whole with `lstrcpyn` and FALSE returned)
- [x] T010 [US2] `src/plugins/regedt/fs4.cpp`: `ExpandPluralSelection` and the size prefix of `GetInfoLineContent` load `IDS_SELECTED1/2/3` and `IDS_SELECTEDSIZE` through `LoadStrU8`; template and format buffers 200 -> 600 bytes

## Phase 5: User Story 3 - the Find window keeps the word (P2)

**Independent test**: rows `<lang> FIND` of the probe (`LVM_GETITEMTEXTW`, exact), nine languages.

- [x] T011 [US3] `src/plugins/regedt/finddlg.cpp` `CFoundFilesData::GetText`, `CI_SIZE`: copy `KeyTextW` instead of `StrToWStr(buffer, 100, KeyText)`

## Phase 5b: User Story 4 - values (added after the review, T016)

**Independent test**: rows `<lang> DEFAULT`, `DATA`, `LONG` of the probe, nine languages.

- [x] T019 [US4] `src/plugins/regedt/fs2.cpp`: the `(Default)` item's name is `DupStrA(LoadStrW(IDS_DEFAULTVALUE))` at both places
- [x] T020 [US4] `src/plugins/regedt/fs2.cpp`: the text-data preview is UTF-8, bounded to `MAX_DATASIZE` bytes, `...` after a whole character
- [x] T021 [US4] `src/plugins/regedt/fs4.cpp`: date and time of a key through the `W` locale functions; `src/plugins/regedt/fs5.cpp`: `(Default)` in the overwrite question through `LoadStrU8`
- [x] T022 [US4] `specs/124-regedt-key-text/probe/regkey_probe.ps1`: rows `DEFAULT`, `DATA`, `LONG`, `SEL3`; fixture values with accented text; `shotocr_lib.ps1`: three sizes per crop, the `near` class

## Phase 6: Tests, gates, records

- [x] T012 Build: `build.cmd full` (Debug x64); `python tools/check_encoding.py` reports `TOTAL: 0`
- [x] T013 Run `probe/check_key_lengths.py` (0 violations)
- [x] T014 Run the probe on the fixed build in nine languages -> `probe/regkey_result.txt`, crops `probe/shots/fixed_*`; look at every `info` and `sel` crop
- [x] T015 Negative control of FR-004: build once with T011 reverted (the report's patch as proposed) and show that the FIND rows fail - or record why the control was not run
- [x] T016 Independent review by a separate agent (refute-first) of the diff and of the test evidence; fix or record every finding
- [x] T017 Records: `fix-log.md` final, entry at the end of `specs/FEATURE-HISTORY.md`, `CHANGELOG.md` `[Unreleased]`, `issues/issue_3_report.md`, `issues/PROGRESS.md`
- [x] T018 Commit on `124-regedt-key-text` (`[124] ...`), nothing pushed

## Dependencies

T006 -> T007 -> T011 (the Find window needs `KeyTextW`); T009 -> T010; T012 after all code tasks; T014-T016 after T012.
US1 and US2 are independent of each other; US3 depends on US1's `KeyTextW`.

## Parallel opportunities

T008 with any code task; T013 with T014.

## Implementation strategy

MVP = US1 (the reported defect). US2 shares the line on screen and ships with it; US3 is the
guard that the fix does no harm.
