# Tasks: Drive list and folder type names come from Windows as Unicode

**Input**: Design documents from `specs/289-drive-list-wide-texts/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/probe-seam.md, quickstart.md

**Tests**: requested by the project rules (saltests for the pure rule, a hidden-desktop probe with
a negative control on the build before the fix).

## Phase 1: Setup

- [X] T001 Confirm the Debug x64 build of HEAD builds (`.\build.cmd`) before any change; record in specs/289-drive-list-wide-texts/fix-log.md

## Phase 2: Foundational (blocking)

- [X] T002 Create header-only `src/common/saldrivetext.h` (UTF-8-BOM, English comments): `SAL_DRIVE_TEXT_U8_MAX` (3 * MAX_PATH + 1), `SAL_FOLDER_TYPE_U8_MAX` (3 * 80 + 1), `SalDriveNameTrimLetterSuffixW(WCHAR*)` (cut at the last '(' and the spaces before it - the rule of `GetDisplayNameFromSystem`)
- [X] T003 Add saltests checks for `saldrivetext.h` in src/saltests/saltests.cpp (suffix trimmed, spaces before it, no '(' unchanged, '(' at the start, empty string, the bounds hold for 260 / 80 units of 3-byte characters)
- [X] T004 Extend the Debug seam in src/drivelst.cpp per contracts/probe-seam.md: `TYPES` line after `BUILD`; `ProbeDumpToolTips` for every non-separator item; the `TIP` line for every drive type at the end of `GetDriveBarToolTip`
- [X] T005 Write the probe specs/289-drive-list-wide-texts/probe/run289.ps1 (style of specs/241-pack-long-nested-folder/probe/pack241_probe.ps1; registry backup / restore verified; English and Czech; rows TYPES / ITEM / TIP per quickstart.md)
- [X] T006 Build with only T004's seam (no fix yet; the seam is needed to observe and changes no text), run the probe on that build - record result_before / results_before and keep its dump in the probe folder; fix-log.md (expected FAIL: Czech ITEM / TIP rows, TYPES folder)

## Phase 3: User Story 1 - CD / removable drive names (P1)

**Goal**: removable display names and CD labels come from the Unicode APIs as UTF-8, never cut.
**Independent Test**: code check of the two routines + the person step; the probe's rows stay PASS.

- [X] T007 [US1] `GetDisplayNameFromSystem` in src/drivelst.cpp: root via `SalU8ToW`, `SHGetFileInfoW(SHGFI_DISPLAYNAME)`, `SalDriveNameTrimLetterSuffixW`, `SalWToU8` into the caller's buffer (failure -> empty)
- [X] T008 [US1] `ReadCDVolNameThreadFBody` in src/drivelst.cpp: `GetVolumeInformationW`, `SalWToU8` into a `SAL_DRIVE_TEXT_U8_MAX` buffer, no ANSI retry; whole copy into `ReadCDVolNameBuffer`
- [X] T009 [US1] `ReadCDVolNameBuffer` to `SAL_DRIVE_TEXT_U8_MAX` in src/salamdr5.cpp and src/consts.h; the copies from it in `BuildData` / `GetDriveBarToolTip` (src/drivelst.cpp) use the real sizes
- [X] T010 [US1] `volumeName` buffers of `BuildData` and `GetDriveBarToolTip` (src/drivelst.cpp) to `2 * SAL_DRIVE_TEXT_U8_MAX + 100`, `DuplicateAmpersands` / `GetDisplayNameFromSystem` / `GetVolumeInformationU8Menu` calls get the real sizes

## Phase 4: User Story 2 - Folder type names (P2)

**Goal**: `FolderTypeName` and `UpDirTypeName` are UTF-8.
**Independent Test**: probe row TYPES.

- [X] T011 [P] [US2] `ReadDirectoryIconAndTypeAux` in src/icncache.cpp: `GetSystemDirectoryW` + `SHGetFileInfoW(SHGFI_TYPENAME)` + `SalWToU8` into `FolderTypeName`
- [X] T012 [P] [US2] `FolderTypeName[SAL_FOLDER_TYPE_U8_MAX]` in src/salamdr1.cpp and src/consts.h; `UpDirTypeName = DupStr(LoadStrU8(IDS_UPDIRTYPENAME))` in src/salamdr1.cpp

## Phase 5: User Story 3 - The drive menu's texts in one encoding (P3)

**Goal**: every localized word of the drive list is UTF-8.
**Independent Test**: probe rows ITEM / TIP.

- [X] T013 [US3] src/drivelst.cpp `BuildData`: `LoadStrU8` for IDS_FLOPPY350/525/800, IDS_REMOVABLE_DISK, IDS_LOCAL_DISK, IDS_COMPACT_DISK; `PrintDiskSize(p, freeSpace, 0, TRUE)`
- [X] T014 [US3] src/drivelst.cpp `AddToDrives` (`LoadStrU8(textResId)`) and the OneDrive item texts (IDS_ONEDRIVE, IDS_ONEDRIVEPERSONAL) in `BuildData` and the OneDrive drop-down; `ExecuteItem` and the drop-down measure `LoadStrU8(IDS_ONEDRIVE)`
- [X] T015 [US3] src/drivelst.cpp `GetDriveBarToolTip`: `LoadStrU8` for every word, `PrintDiskSize(..., 0, TRUE)`

## Phase 6: Polish

- [X] T016 Grep the touched functions for any remaining `LoadStr(` / `SHGetFileInfo(` / `GetVolumeInformation(` feeding these texts (record in fix-log.md)
- [X] T017 `python tools/check_encoding.py --strict` -> TOTAL: 0; `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [X] T018 Run the probe on the fixed build (result_after) - all rows PASS; then decode every ITEM / TIP / TYPES line of the before and after dumps the way the sinks do (UTF-8, else the code page) and compare: the displayed texts must be equal (SC-002, FR-007); record in fix-log.md
- [X] T019 Record the person step (CD / USB labelled outside the code page; display language outside the code page) in fix-log.md

## Dependencies

T001 -> T002 -> T003; T004 -> T005 -> T006 (before any fix); US1 (T007-T010), US2 (T011-T012),
US3 (T013-T015) after T006, independent of each other except that all edit src/drivelst.cpp
(serial within that file); Polish last.

## Parallel examples

T011 and T012 (different files); T002/T003 alongside T004.

## Implementation strategy

Seam and probe first (negative control on the unfixed code), then US1 (the reported symptom),
US2, US3, then the checks.
