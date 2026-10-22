# Tasks: Registry Editor - Copy / Move through a registry link in the target tree

**Input**: `specs/296-regedt-link-target-tree/` (spec.md, plan.md, research.md, data-model.md,
contracts/target-link-check.md, quickstart.md)
**Tests**: the hidden-desktop probe `probe/link296_probe.ps1` (written during the measurement) is the
acceptance test; the probes of 292 / 294 are the regression.

## Phase 1: Setup

- [X] T001 Start `specs/296-regedt-link-target-tree/fix-log.md` with the measurement at 4420aae1 (scratch link experiment, probe before 14 / 15) and the decisions of the spec

## Phase 2: Foundational

- [X] T002 Move 294's identity-pair loop out of `CPluginFSInterface::CopyOrMoveFromFS` into a static helper `SafeRegKeyIdsReachSource` and call it from there, behaviour unchanged, in `src/plugins/regedt/fs5.cpp`
- [X] T003 Split `CopyOrMoveKey` into the public wrapper (same signature, declared in `src/plugins/regedt/regedt.h`) and a static recursion `CopyOrMoveKeyRec` carrying a `CRegCopyTop` (source root, heap copy of the selected key's path, identities read lazily) in `src/plugins/regedt/fs5.cpp`

## Phase 3: User Story 1 - A Move through a link to the source loses nothing (P1) - MVP

**Independent test**: probe rows LINKMOVE, LINKALIAS, LINKOK, LINKUP.

- [X] T004 [US1] Add `SafeCheckTargetLink` (open the target as a link, read `SymbolicLinkValue`; for a link read the operation's source identities once and the link's identities with links followed; refuse by `SalRegKeyIdsAnyWithin` or `SafeRegKeyIdsReachSource`) in `src/plugins/regedt/fs5.cpp`
- [X] T005 [US1] Call it in `CopyOrMoveKeyRec` before `SafeCreateKey`; a refusal shows `IDS_CANTMOVETOITSELF2` / `IDS_CANTCOPYTOITSELF2` with the whole `<root>\<source>` name (OK = skip, Cancel = stop) and writes nothing of that key, in `src/plugins/regedt/fs5.cpp`

## Phase 4: User Story 2 - A Copy through a link to the source is refused too (P2)

**Independent test**: probe row LINKCOPY.

- [X] T006 [US2] Confirm the same check serves Copy (the copy text of the box, the source unchanged) - no separate code path, in `src/plugins/regedt/fs5.cpp`

## Phase 5: User Story 3 - A dangling link is not created through (P2)

**Independent test**: probe rows LINKDANGLE, LINKTOP.

- [X] T007 [US3] In `SafeCheckTargetLink`, a link whose identities give `ERROR_FILE_NOT_FOUND` goes through `RegOperationError(ERROR_CANT_RESOLVE_FILENAME, IDS_OPEN, ...)` (Retry re-checks; Skip / Skip All / Cancel), other errors through the open-error box, in `src/plugins/regedt/fs5.cpp`

## Phase 6: User Story 4 - Other links and plain copies work as before (P3)

**Independent test**: probe rows LINKUPOK, LINKOTHER, MOVE; the probes of 292 and 294.

- [X] T008 [US4] Build (`build.cmd`) and run `probe/link296_probe.ps1` on the hidden desktop in English and Czech (`probe/link296_after.txt`, `probe/link296_after_czech.txt`), every row PASS
- [X] T009 [US4] Run `specs/292-regedt-alias-move-self/probe/alias292_probe.ps1` and `specs/294-regedt-move-above-parent/probe/above294_probe.ps1` on this build (results into `specs/296-regedt-link-target-tree/probe/`), every row PASS

## Phase 7: Polish

- [X] T010 Encoding guard `python tools/check_encoding.py --strict` (TOTAL: 0) and `saltests` (0 failed)
- [X] T011 Record before / after, commands and results in `specs/296-regedt-link-target-tree/fix-log.md`

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> (T006, T007) -> T008 -> T009 -> T010 -> T011. All code tasks
touch the same file (`fs5.cpp`), so none runs in parallel; T009's two probes cannot share the desktop.

## Implementation strategy

MVP = Phase 3 (the data loss). Phases 4-5 are the same check's other outcomes; Phase 6 proves nothing
else changed.
