# Tasks: Registry Editor - Delete / Move of a key holding a registry link

**Input**: Design documents from `specs/297-regedt-delete-link/` (plan.md, spec.md, research.md,
data-model.md, contracts/source-link-handling.md, quickstart.md)
**Tests**: the hidden-desktop probe `probe/link297_probe.ps1` (written and run before the fix during
measuring) is the test; no new `saltests` rule (no pure decision added).

## Phase 1: Setup

- [X] T001 Confirm the measurement record in specs/297-regedt-delete-link/fix-log.md and the before result specs/297-regedt-delete-link/probe/link297_before.txt (16 PASS / 14 FAIL) are in the branch

## Phase 2: Foundational (blocks US1 and US2)

- [X] T002 Add `RegKeyIsLink(int root, LPCWSTR key, BOOL& isLink)` in src/plugins/regedt/fs5.cpp per contracts/source-link-handling.md and make `SafeCheckTargetLink` use it instead of its inline open-as-link test (same results for every case of 296)
- [X] T003 Add `SafeRegKeyIsLink` (open-error box, `ERROR_FILE_NOT_FOUND` = no link) and `SafeDeleteRegLink` (OPEN_LINK + DELETE | KEY_QUERY_VALUE, re-check `REG_LINK` on the handle, `NtDeleteKey` / `RtlNtStatusToDosError` by `GetProcAddress`, `IDS_DELETE` box with Retry) in src/plugins/regedt/fs5.cpp; declare both in src/plugins/regedt/regedt.h

## Phase 3: User Story 1 - Delete never removes the key a link points at (P1)

**Independent test**: probe rows DELTREE, DELTOP, DELDANGLE, DELHKCR PASS; DEL control PASS.

- [X] T004 [US1] In `CPluginFSInterface::DeleteKey` (src/plugins/regedt/fs3.cpp), first thing after the cancel test: `SafeRegKeyIsLink(CurrentKeyRoot, keyName, ..., IDS_DELKEY, ...)`; a link -> `return SafeDeleteRegLink(...)` (nothing enumerated or deleted through it); an error -> return as the existing open error does

## Phase 4: User Story 2 - Move / Rename never moves a link into a copy of its target (P1)

**Independent test**: probe rows MOVETREE, MOVESKIP, MOVETOP, RENAMETOP PASS; MOVE control PASS.

- [X] T005 [US2] In `CopyOrMoveKeyRec` (src/plugins/regedt/fs5.cpp), when `move`, first thing after the cancel test: while `SafeRegKeyIsLink(sourceRoot, source)` says link, `RegOperationError(ERROR_NOT_SUPPORTED, IDS_REMOVESOURCE, errorTitle, sourceRoot, source, &skip, &skipAllErrors)` (Retry checks again; Skip / Skip All / Cancel return FALSE) - before `SafeOpenKey` of the source, 296's target check and any write

## Phase 5: User Story 3 - Everything without links works as before (P2)

**Independent test**: probe rows COPYTREE, DEL, MOVE PASS; 296 / 294 / 292 probes PASS.

- [X] T006 [US3] Build Debug x64 (`build.cmd`, BUILD SUCCEEDED) and run `probe/link297_probe.ps1` (English -> probe/link297_after.txt, Czech -> probe/link297_after_czech.txt) per quickstart.md; record in fix-log.md
- [X] T007 [US3] Run the regression probes on the same build: specs/296-regedt-link-target-tree/probe/link296_probe.ps1, specs/294-regedt-move-above-parent/probe/above294_probe.ps1, specs/292-regedt-alias-move-self/probe/alias292_probe.ps1 (outputs into specs/297-regedt-delete-link/probe/); record in fix-log.md

## Phase 6: Polish & cross-cutting

- [X] T008 Negative control: disable the link test of T004 and T005 (e.g. `isLink = FALSE` after the call), rebuild, run the link rows (-Only DEL,MOVE,RENAME), expect FAIL; revert (`git diff` of the two files back to the fix), rebuild, full probe again; record in fix-log.md
- [X] T009 [P] Encoding guard `python tools/check_encoding.py --strict` (TOTAL: 0 finding(s)) and `saltests` (0 failed); record in fix-log.md
- [X] T010 [P] Record the Export / Find / Copy finding of research.md R4 as an Inbox item (`measure:297`) and note it in fix-log.md

## Dependencies

T001 -> T002 -> T003 -> (T004, T005) -> T006 -> T007 -> T008 -> T009; T010 any time.
US1 and US2 touch different functions (fs3.cpp / fs5.cpp) and can be done in either order after T003.

## Parallel examples

- T004 (fs3.cpp) and T005 (fs5.cpp) after T003.
- T009 and T010.

## Implementation strategy

MVP = US1 + US2 together (both P1, both lose the same unselected key); US3 is the regression proof.
