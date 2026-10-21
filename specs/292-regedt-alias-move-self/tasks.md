---
description: "Tasks for feature 292 - Registry Editor Copy / Move onto itself through another root name"
---

# Tasks: Registry Editor - Copy / Move of a key onto itself through another root name

**Input**: `specs/292-regedt-alias-move-self/` (plan.md, spec.md, research.md, data-model.md, contracts/key-identity.md)
**Tests**: requested by the spec (FR-007 `saltests`; SC-001..003 the probe).

## Phase 1: Setup

- [X] T001 Start `specs/292-regedt-alias-move-self/fix-log.md` with the measurement before (probe `alias292_before.txt`, 18 PASS / 9 FAIL; NtQueryKey findings) and the consumer list of research R4

## Phase 2: Foundational (the pure rule)

- [X] T002 Create `src/common/salregkeyid.h` (UTF-8 BOM, header-only) per `contracts/key-identity.md`: `SAL_REGKEYID_MAX`, `SAL_REGKEYIDS_MAX`, `CSalRegKeyIds`, `SalRegKeyIdSame`, `SalRegKeyIdWithin`, `SalRegKeyIdsAdd`, `SalRegKeyIdsAnySame`, `SalRegKeyIdsAnyWithin`
- [X] T003 Add `TestRegKeyId292` to `src/saltests/saltests.cpp` (include the header, call it from `main`): equal / case / different length / empty; within at a whole element, not "Key2" in "Key", outer longer than key; join with and without a name, refused when too long or full (set unchanged); any-pair tests incl. an HKCR-like set of three; the spec's edge case "HKEY_USERS\<SID> into HKEY_CURRENT_USER\" modelled as sets (target = HKCU root identity + name lies within the source `\REGISTRY\USER\<SID>`)
- [X] T004 Include `../../common/salregkeyid.h` in `src/plugins/regedt/precomp.h`

## Phase 3: User Story 1 - a key or value moved onto itself under another root name is not lost (P1)

**Independent test**: probe rows ALIASMOVE, ALIASVALUE, HKCRMOVE.

- [X] T005 [US1] In `src/plugins/regedt/fs5.cpp` add `QueryRegKeyId(HKEY, CSalRegKeyIds&)` (NtQueryKey KeyNameInformation through `GetProcAddress`, status -> Win32 via `RtlNtStatusToDosError`, too long -> `ERROR_FILENAME_EXCED_RANGE`) and `GetRegKeyIds(int root, LPCWSTR key, CSalRegKeyIds&, BOOL mayNotExist)` with the root rules of research R2 and the HKCR rule of R3
- [X] T006 [US1] In `CPluginFSInterface::CopyOrMoveFromFS` (`src/plugins/regedt/fs5.cpp`): after the target folder exists, build the panel-folder and target-folder identity sets (error -> `ErrorL(err, IDS_ACCESS, ...)` and back to the dialog); the "onto itself" block runs when the text check or `SalRegKeyIdsAnySame` says the same folder

## Phase 4: User Story 2 - Copy onto itself and Move into itself refused (P2)

**Independent test**: probe rows ALIASCOPY (covered by T006) and ALIASINTO.

- [X] T007 [US2] In the key branch of the item loop of `CopyOrMoveFromFS` (`src/plugins/regedt/fs5.cpp`): build the source-key set (opened key + panel folder joined with the name) and the target-key set (target folder joined with the new name + opened target key when it exists); `into` = the text check or `SalRegKeyIdsAnyWithin(target, source)` -> the existing 1065 / 1067 box; an identity error -> the existing `RegOperationError(..., IDS_OPEN, ...)` box (Retry / Skip / Skip All / Cancel), the key is not copied

## Phase 5: User Story 3 - legitimate operations keep working (P3)

**Independent test**: probe rows ALIASRENAME, ALIASOTHER, MOVE, MOVESELF, SAMEMOVE.

- [X] T008 [US3] Review the changed code for the rename path (`useTargetName` with another name under the same folder by identity -> `sourceEqualsTarget`, focus name) and the same-root paths: no other behaviour change in `src/plugins/regedt/fs5.cpp`

## Phase 6: Polish & checks

- [X] T009 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [X] T010 `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> `0 failed`
- [X] T011 Probe after the fix (English, then `-Lang czech`) on the hidden desktop -> all rows PASS, registry restored identical; negative control: the same probe on the build without the fix fails the data-loss rows (already measured: `alias292_before.txt`)
- [X] T012 Record the results, decisions and limits in `specs/292-regedt-alias-move-self/fix-log.md`

## Dependencies

T001 -> T002 -> T003, T004 -> T005 -> T006 -> T007 -> T008 -> T009..T012. US2 and US3 build on the
helpers of US1 (one function in one file - no parallel work).

## Parallel opportunities

T003 and T004 (different files) after T002.

## Implementation strategy

MVP = US1 (T005-T006): stops the data loss. US2 adds the into-itself check; US3 is verification.
