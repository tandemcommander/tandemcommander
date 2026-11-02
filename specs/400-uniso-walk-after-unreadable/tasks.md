# Tasks: After a folder that cannot be read, the ISO plug-in still lists the later folders

**Input**: `specs/400-uniso-walk-after-unreadable/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: requested by the spec (FR-008 saltests, SC-001..SC-004 probe rows).

## Phase 1: Setup

- [X] T001 Write the probe's image maker `specs/400-uniso-walk-after-unreadable/probe/img400.py` (330's commands plus `isotwo` - folders A and B past the end -, `xboxtwo`, `xboxloop` - folder a with a damaged folder first and two entries pointing back to a -, `xboxloop2` - the same without the damaged folder -, `udfloop` - side.txt in folder a turned into a folder pointing to a) and the seed script `specs/400-uniso-walk-after-unreadable/probe/mkimg400.sh` (330's seeds plus `rd2.iso` of a/side.txt, b/b.txt, top.txt, zlast/z.txt)
- [X] T002 Write the probe `specs/400-uniso-walk-after-unreadable/probe/iso400_probe.ps1` from 330's: the damaged rows expect `zlast/z.txt` of the damaged file system too and the expected box exactly once; new rows RD-TWO, XD-TWO (one box), XD-LOOP, XD-LOOP2, UD-LOOP (answer within 30 s); 330's control rows unchanged
- [X] T003 Run the probe on the current build (main's code) -> `probe/result_before.txt`; record in `fix-log.md` which rows fail and why

## Phase 2: Foundational

- [X] T004 Create `src/common/salisowalk.h` (UTF-8 BOM, SPDX header): `SAL_ISO_WALK_OK/CONTINUE/TERMINATE`, `struct SalIsoWalk`, `SalIsoWalkDescends`, `SalIsoWalkAfterChild`, `SalIsoWalkBoxQuiet`
- [X] T005 Add `TestIsoWalk_400` to `src/saltests/saltests.cpp` (include the header; model trees walked with the rule and with the old rule; every readable file listed, one box, result CONTINUE, out of memory stops later descents; the old rule fails) and call it from the test list
- [X] T006 Build and run saltests; record mutants of `SalIsoWalkDescends` / `SalIsoWalkAfterChild` / `SalIsoWalkBoxQuiet` that fail checks in `fix-log.md`

## Phase 3: User Story 1 - later folders listed (P1)

- [X] T007 [US1] ISO 9660: `src/plugins/uniso/iso9660.h` member `SalIsoWalk Walk`; `src/plugins/uniso/iso9660.cpp` - reset in `ListDirectory` (before the fit walk and the listing walk), saved / restored in `CountUnder`, `ListDirectoryRe` descends with `SalIsoWalkDescends` and combines with `SalIsoWalkAfterChild`; out-of-memory sites and `ADD_FAILED` set `Walk.Stopped`
- [X] T008 [US1] UDF: `src/plugins/uniso/udf.h` / `udf.cpp` - `Walk`, reset in `ListDirectory`; `ScanDir` descends with the rule, combines with `SalIsoWalkAfterChild`; `AddFileDir` out-of-memory sites set `Stopped`
- [X] T009 [US1] Xbox: `src/plugins/uniso/xdvdfs.h` / `xdvdfs.cpp` - as T008 (`new` failure and `AddFileDir` out of memory set `Stopped`)

## Phase 4: User Story 2 - one box (P2)

- [X] T010 [US2] Gate every walk box with `SalIsoWalkBoxQuiet`: `iso9660.cpp` `ListDirectoryRe`, `ChainNotListed`, `AddFileDir` out-of-memory boxes; `udf.cpp` `ScanDir` and `AddFileDir` out-of-memory boxes; `xdvdfs.cpp` `ScanDir` and `AddFileDir` out-of-memory boxes (the core-refusal `IDS_ERROR` boxes stay)

## Phase 5: User Story 3 - loops end (P2)

- [X] T011 [US3] UDF visited set in `src/plugins/uniso/udf.h` / `udf.cpp`: key of the folder's ICB, root inserted in `ListDirectory`, a folder met again not descended, out of memory on insert -> `Stopped`, gated box, `CONTINUE`
- [X] T012 [US3] Xbox visited set in `src/plugins/uniso/xdvdfs.h` / `xdvdfs.cpp`: key = start sector, root inserted, same rules

## Phase 6: Polish & verification

- [X] T013 `python tools/check_encoding.py --strict` -> TOTAL: 0; `.\build.cmd` -> BUILD SUCCEEDED; saltests 0 failed
- [ ] T014 Run `iso400_probe.ps1` after -> `probe/result_after.txt`, all PASS; record in `fix-log.md`
- [ ] T015 Regressions: 328's probe (LOOP rows), 329's and 327's probes -> `probe/regress_*.txt`, all PASS
- [ ] T016 `fix-log.md` complete (before / after, commands, results)

## Dependencies

T001 -> T002 -> T003 (before any source change). T004 -> T005 -> T006 -> T007..T012 (T007, T008, T009 touch different files: parallel; T010 after T007-T009; T011 after T008; T012 after T009) -> T013 -> T014 -> T015 -> T016.

## Parallel examples

- T007 [P-able after T006], T008, T009: separate reader files.
- T011 and T012: separate files.

## Implementation strategy

MVP = US1 (T007-T009) with the rule header; US2 and US3 complete the item's *Notes* (no box flood, no loop) and are required before closing - descending later folders without them is not shippable.
