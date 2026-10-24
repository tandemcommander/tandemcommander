# Tasks: An HFS+ image whose catalog records were skipped as damaged is kept by Unpack with "Delete archive after unpacking"

**Input**: `specs/332-uniso-hfs-skipped-records/` - spec.md, plan.md, research.md, data-model.md, quickstart.md
**Tests**: the spec asks for unit rules (SC-003) and probe rows (SC-001, SC-002).

## Phase 1: Setup

- [ ] T001 Probe files in `specs/332-uniso-hfs-skipped-records/probe/` (`iso332_probe.ps1`, `mkimg332.sh`, `img332.py`) and the before run `probe/result_before.txt` (H-TYPE / H-KEY / H-LONG / H-SHORT FAIL, controls and U-FILE PASS) recorded in `fix-log.md`

## Phase 2: Foundational

- [ ] T002 Add `SalHfsCatalogRecordClass` and `SAL_HFSREC_*` / `SAL_HFSCAT_FOLDER_REC_SIZE` (88) / `SAL_HFSCAT_FILE_REC_SIZE` (248) to `src/common/salhfscatalog.h` exactly as the table of `data-model.md`
- [ ] T003 Add `TestHfsRecordClass332` to `src/saltests/saltests.cpp` (built with `Hfs322Record`): FOLDER / FILE at 88 / 248 bytes, DAMAGED at 87 / 247, threads (types 3, 4) NOT_ENTRY, empty-named folder DAMAGED unless parent 1, the volume label NOT_ENTRY only with the label in use, 255 units listed / 256 DAMAGED, type 5 and a named thread type UNKNOWN, a U+0000 name NOT_ENTRY (folder / file) / DAMAGED (type 5), NULL / short / key length 0xFFFF DAMAGED, the probe's four damages; call it from the test list

## Phase 3: User Story 1 - Unpack + delete keeps an HFS+ image whose catalog record was skipped (P1)

**Independent test**: probe rows H-TYPE, H-KEY, H-LONG, H-SHORT - image kept.

- [ ] T004 [US1] `src/plugins/uniso/hfs.cpp` `CHFS::ListDirectory`: classify each record with `SalHfsCatalogRecordClass`; NOT_ENTRY skipped; DAMAGED - `Image->ListingLeftOut.SetIncomplete()`, skipped; UNKNOWN - `SetIncomplete()`, `return FALSE` (the listing ends as before); a name whose UTF-8 conversion fails - `SetIncomplete()`, skipped; `static_assert` the two record sizes against `sizeof(HFSPlusCatalogFolder)` / `sizeof(HFSPlusCatalogFile)`
- [ ] T005 [US1] Build (`build.cmd`), `saltests` 0 failed, a mutant of the rule (threads DAMAGED) fails `TestHfsRecordClass332`, record in `fix-log.md`
- [ ] T006 [US1] Probe after: `probe/result_after.txt` - every row PASS

## Phase 4: User Story 2 - An intact HFS+ or UDF image is unpacked and deleted as before (P1)

**Independent test**: probe rows H-OK, U-OK, U-FILE; regression probes.

- [ ] T007 [US2] Regression probes 322 (`iso322_probe.ps1`), 328, 329, 330 on the fixed build - their earlier results; `probe/regress_*.txt`

## Phase 5: Polish

- [ ] T008 Encoding guard `python tools/check_encoding.py --strict` TOTAL: 0; `fix-log.md` complete (before / after, commands, results)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008. T002 / T003 touch different files ([P]-able
in principle; T003 needs T002's names). US2 checks the same build as US1.

## Implementation strategy

One small change (MVP = US1); US2 is the regression proof of the same change.
