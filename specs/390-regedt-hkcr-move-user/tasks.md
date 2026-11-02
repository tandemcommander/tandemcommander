# Tasks: Registry Editor - Move from HKCR into the user's Classes key does nothing

**Input**: `specs/390-regedt-hkcr-move-user/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: the measurement is the acceptance test (constitution: measure first) - the probe and the
`saltests` rule are part of the work.

## Phase 1: Setup

- [ ] T001 Start `specs/390-regedt-hkcr-move-user/fix-log.md` with the measurement at 129136b4 (probe `result_before.txt` / `hkcr390_before.txt`)
- [ ] T002 Replace the probe's mis-designed control USERHKCR (a new HKCR subkey is created in the machine half, research R6) by USERCLS (F6 into `\HKEY_CURRENT_USER\Software\Classes\TcProbe390\Cil\`) in `specs/390-regedt-hkcr-move-user/probe/hkcr390_probe.ps1`

## Phase 2: Foundational

- [ ] T003 Add `SalRegHkcrDeleteHalf` (enum `SAL_HKCR_DELETE_VIEW` / `_MACHINE` / `_USER`) and `SalRegJoinClassesPath` (never cut) to `src/common/salregkeyid.h`, header comment included
- [ ] T004 Add `TestRegHkcrHalf390` (all four half combinations; join: fits, exactly fits, one unit too long, empty key, Czech key) to `src/saltests/saltests.cpp` and call it next to `TestRegKeyId292`

## Phase 3: User Story 1 - a Move out of the merged view moves, or says why it cannot (P1)

**Goal**: the delete of a Move from HKCR goes to the half that was copied. **Independent test**: probe rows MACHUSER / MACHUSERU.

- [ ] T005 [US1] In `src/plugins/regedt/fs5.cpp` add a helper that reads which halves hold an HKCR path (`HKLM` / `HKCU` `Software\Classes\<path>`, open error other than not-found -> the existing open-error box, fails closed) and a helper that deletes one half by its real path with the `IDS_REMOVESOURCE` box naming the real key (the HKCR source when the real name would not fit `MAX_KEYNAME`)
- [ ] T006 [US1] In `CopyOrMoveKeyRec` (`src/plugins/regedt/fs5.cpp`): for a Move whose source root is HKCR read the halves before `SafeCreateKey`; at the end delete by `SalRegHkcrDeleteHalf` (VIEW = the old `SafeDeleteKey`)
- [ ] T007 [US1] Build (`.\build.cmd`), run `saltests`, run the probe after the fix (`result_after.txt` / `hkcr390_after.txt`): MACHUSER / MACHUSERU PASS

## Phase 4: User Story 2 - other Moves out of HKCR behave as before (P2)

**Goal**: no regression. **Independent test**: USERMOVE / USERCLS and the probes of 292, 294, 296, 297.

- [ ] T008 [US2] Run the probes of 292 (`specs/292-regedt-alias-move-self/probe/alias292_probe.ps1`), 294 (`specs/294-*/probe/above294_probe.ps1`), 296 (`specs/296-*/probe/link296_probe.ps1`) and 297 (`specs/297-regedt-delete-link/probe/link297_probe.ps1`) on the new build; record results in `specs/390-regedt-hkcr-move-user/fix-log.md`
- [ ] T009 [US2] Negative control: the fix's delete forced back to VIEW (in a copy of the source or a temporary edit reverted afterwards) makes MACHUSER fail again; record in `specs/390-regedt-hkcr-move-user/fix-log.md`

## Phase 5: Polish

- [ ] T010 Encoding guard `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`; record checks in `specs/390-regedt-hkcr-move-user/fix-log.md`
- [ ] T011 Czech run of the probe (`-Lang czech`) -> 0 FAIL; result in `specs/390-regedt-hkcr-move-user/probe/`

## Dependencies

T001-T002 -> T003-T004 -> T005-T006 -> T007 -> T008-T011. US2 depends on US1's code (the same function).
Parallel: T003 / T004 are different files ([P] in spirit, but T004 needs T003's names); T008 rows and
T010 can run while reviewing.

## Implementation strategy

MVP = US1 (the item). US2 is the regression guard of the same change.
