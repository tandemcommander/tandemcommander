# Tasks: An archive member whose name the panel cannot hold never crashes the program

**Input**: `specs/307-tar-long-component/` (spec.md, plan.md, research.md, data-model.md, contracts/, quickstart.md)
**Tests**: `saltests` checks of the pure rule (FR-007) and the hidden-desktop probe are required by the spec.

## Phase 1: Setup

- [ ] T001 Start the running log `specs/307-tar-long-component/fix-log.md` with the measurement at d92d8278 (probe command, GNU-TOOLONG crash, root cause)
- [ ] T002 Write the fixture generator `specs/307-tar-long-component/probe/mktar307.py` (rows GNU-TOOLONG, GNU-DEEP, GNU-255, GNU-LONG, ZIP-TOOLONG, 7Z-TOOLONG; pure ASCII source, CJK built with chr())
- [ ] T003 Write the probe `specs/307-tar-long-component/probe/tar307_probe.ps1` built on `specs/306-tar-pax-headers/probe/pax306_probe.ps1` (registry backup / restore, fixture under %TEMP%\tc307, crash = FAIL, never TaskStop)
- [ ] T004 Run the probe on the unchanged build (label `before`) -> `specs/307-tar-long-component/probe/result_before.txt`; record in fix-log.md

## Phase 2: Foundational

- [ ] T005 Create `src/common/sallistingname.h` (header-only): `SAL_LISTING_NAME_MAX_BYTES`, `SalListingAcceptsFileU8(path, pathLen, name, nameLen)`, `SalListingAcceptsDirU8(path, pathLen, nameLen)` per data-model.md (with a folder part: the feature-222 rule unchanged; without: refuse `nameLen >= SAL_FIND_NAME_U8`)
- [ ] T006 Add saltests checks in `src/saltests/saltests.cpp` (include the header; boundaries 779 / 780 bytes without a folder part, a 300-letter ASCII and a 904-byte CJK name, folder rules unchanged with a folder part, 255 / 256 bytes of the folder part, `static_assert` the bound equals `SAL_FIND_NAME_U8`)

## Phase 3: User Story 2 - No plug-in listing can overflow the panel (P2, the root cause; done first because US1's negative control relies on it)

- [ ] T007 [US2] Use the rule in `CSalamanderDirectory::AddFile` and `AddDir` in `src/zip.cpp` (keep `pathLen` for the add cache; `path == NULL` no longer skips the bound)

## Phase 4: User Story 1 - A tar with an over-long GNU member name opens (P1)

- [ ] T008 [US1] Add `BOOL NameFromGnuLong` to `SCommonHeader` in `src/plugins/tar/tar.h` and reset it in `SCommonHeader::Reset` in `src/plugins/tar/untar.cpp`
- [ ] T009 [US1] Set the flag in the `GNUTYPE_LONGNAME` branch of `CArchive::ReadTarHeader` and extend the feature-306 check in `CArchive::ReadArchiveHeader` to `NameFromPax || NameFromGnuLong` in `src/plugins/tar/untar.cpp` (comments updated)

## Phase 5: User Story 3 - ZIP and 7-Zip archives (P3)

- [ ] T010 [US3] Record the ZIP-TOOLONG and 7Z-TOOLONG rows before / after in `specs/307-tar-long-component/fix-log.md` (no code change expected beyond T007)

## Phase 6: Polish & verification

- [ ] T011 `python tools/check_encoding.py --strict` -> TOTAL: 0; `build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [ ] T012 Probe `tar307_probe.ps1 -Label after` -> `probe/result_after.txt` all PASS; 306 probe -> `probe/regress_306.txt` 28 / 0
- [ ] T013 Negative controls (source restored afterwards): (a) GNU flag never set -> `probe/result_negctl_tar.txt` (GNU rows open without a crash, core refusal); (b) additionally the `path == NULL` branch of the rule accepting everything -> `probe/result_negctl_core.txt` (crash returns); record in fix-log.md
- [ ] T014 Final record in `specs/307-tar-long-component/fix-log.md` (before / after, commands, numbers)

## Dependencies

T001-T004 before any code change (measure first). T005 -> T006, T007. T007 before T013(a). T008 -> T009. T011-T014 after all code.

## Parallel opportunities

T002 / T003 (different files); T006 with T008 (different files).

## Implementation strategy

MVP = US1 + US2 (both remove the measured crash); US3 is a measurement.
