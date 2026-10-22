# Tasks: Drive Information writes the volume label as typed

**Input**: Design documents from `specs/300-volume-label-wide/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: no unit tests (no pure decision to extract - the change is one conversion at an OS
boundary); the proof is the import table, the checker report and a hidden-desktop probe.

## Phase 1: Setup (measure before)

- [X] T001 Start `specs/300-volume-label-wide/fix-log.md` with the measurement of the specify input (site, reachability, checker in-memory 39 → 40, mojibake bytes)
- [X] T002 Build the HEAD state (PowerShell `.\build.cmd`) and record in `specs/300-volume-label-wide/fix-log.md` the `dumpbin /imports` lines matching `VolumeLabel` of `build\tandemcommander\Debug_x64\tandemcommander.exe` (expected `SetVolumeLabelA`)
- [X] T003 Write the probe `specs/300-volume-label-wide/probe/vol300_probe.ps1` (style of `specs/270-mask-filter-label-fits/probe/mask270_probe.ps1`, 098's library, registry backup / restore / verify; rows `vol-fail`, `vol-same`, `vol-long` as plan.md *Measurement*; every typed path inside the fixture)
- [X] T004 Run the probe on the HEAD build on the hidden desktop → `specs/300-volume-label-wide/probe/result_before.txt`; record the rows in `fix-log.md`

## Phase 2: Foundational

- [X] T005 Add `SetVolumeLabel` to `ANSI_NAME_API` in `tools/check_encoding.py`; run `python tools/check_encoding.py --rule ansi-api-on-utf8-path` (expected 40, `dialogs3.cpp` `SetVolumeLabel` listed) and `--strict` (TOTAL: 0); record in `fix-log.md`

## Phase 3: User Story 1 - a non-ASCII label is written as typed (P1)

**Goal**: the label and the volume path reach Windows as wide text.
**Independent Test**: the import table names only `SetVolumeLabelW`; the checker report has no `SetVolumeLabel` hit.

- [X] T006 [US1] In `src/dialogs3.cpp` `CDriveInfo::Validate`: convert `volumePathWithBackslash` and `newName` with `SalU8ToWAlloc` before the hands-off; call `SetVolumeLabelW`; free both
- [X] T007 [US1] Build, then `dumpbin /imports` → only `SetVolumeLabelW`; checker report back to 39 without `SetVolumeLabel`; record in `fix-log.md`

## Phase 4: User Story 2 - a failed write is still reported (P2)

**Goal**: a refused conversion and a failed write both show the existing message, the dialog stays.
**Independent Test**: probe rows `vol-fail`, `vol-same`, `vol-long` PASS after.

- [X] T008 [US2] In `src/dialogs3.cpp` `CDriveInfo::Validate`: when either conversion returns NULL write nothing, set `err` to `ERROR_NOT_ENOUGH_MEMORY` (size query succeeds) or `ERROR_NO_UNICODE_TRANSLATION`, and take the existing error branch (message `IDS_UNABLETOCHANGEDRIVELABEL`, `ti.ErrorOn(IDE_VOLNAME)`) without the hands-off
- [X] T009 [US2] Run the probe on the new build → `specs/300-volume-label-wide/probe/result_after.txt`; record in `fix-log.md`

## Phase 5: User Story 3 - the checker covers the call (P3)

**Goal**: a code-page label call with a UTF-8 argument is reported.
**Independent Test**: negative control.

- [X] T010 [US3] Negative control: run the checker's `ansi-api-on-utf8-path` rule against the old call (in-memory copy of `src/dialogs3.cpp` with `SetVolumeLabelW(pathW, nameW)` replaced by `SetVolumeLabel(volumePathWithBackslash, newName)`) → reported; record the method and result in `fix-log.md`

## Phase 6: Polish

- [X] T011 `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`; `& "build\tandemcommander\Debug_x64\saltests\saltests.exe"` → 0 failed; record in `fix-log.md`
- [X] T012 Record the person step (real write on a USB stick / VHD, including clearing the label to empty) in `fix-log.md` *Owed to a person*

## Dependencies

T001 → T002 → T003 → T004 → T005 → T006 → T007 → T008 → T009 → T010 → T011 → T012. T006 and
T008 edit the same function (written together, built once; T007 after both is acceptable).
No parallel tasks: one function, one build.

## Implementation strategy

MVP = US1 (the wide call). US2's refusal branch is part of the same edit; US3 is the checker
change done first (T005) and proven by T010.
