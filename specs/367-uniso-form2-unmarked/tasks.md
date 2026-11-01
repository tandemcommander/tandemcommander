# Tasks: ISO plug-in - a video file in Form 2 sectors without an XA Form 2 attribute extracts whole

**Input**: Design documents from `specs/367-uniso-form2-unmarked/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md
**Tests**: required by the project (saltests for the pure rules, FR-009; hidden-desktop probe, SC-001..003).

## Phase 1: Setup

- [X] T001 Start `specs/367-uniso-form2-unmarked/fix-log.md` with the measurement before (56a44fba: rows C-MIXED, C-NOXA, C-F1SUB 608,256 bytes, image deleted) and the enumerated sites and consumers of `CFilePos::Form2` (Grep `Form2` in `src/plugins/uniso/`)

## Phase 2: Foundational (the pure rules)

- [X] T002 Add `SAL_ISO_SECTOR_UNKNOWN/FORM1/FORM2`, `SalIsoSectorForm`, rewrite `SalIsoSectorIsForm2` on it, add `SalIsoFileNeedsSectorScan` and `SalIsoSectorScan` (+ `SalIsoSectorScanInit`, `SalIsoSectorScanAdd`, `SalIsoSectorScanKind`, `SalIsoSectorScanSize`) in `src/common/salisotrack.h`
- [X] T003 Add `TestIsoSectorScan_367` (sector forms incl. 2336 / 2352, triggers, kinds, sizes for none / all / mixed / partial last, whole run stops at unknown and at a partial last non-Form-2 sector; 335's `SalIsoSectorIsForm2` results unchanged) and call it in `src/saltests/saltests.cpp`
- [X] T004 Build and run saltests; mutate each new rule once (script in `specs/367-uniso-form2-unmarked/probe/mutants367.ps1`) - each mutant fails a check

## Phase 3: User Story 1 + 2 - examined files listed and read whole, per sector (P1)

**Goal**: C-NOXA / C-MIXED AVSEQ01.DAT 690,228 bytes; C-F1SUB AVSEQ02.DAT 689,952 bytes, listed with the same size.

- [X] T005 [US1] Extend `CFilePos` (`Form2` 0/1/2 documented, `Scanned`, `WholeSectors`) and declare `ExamineFileSectors`, `ReadMixedBlock` in `src/plugins/uniso/isoimage.h`
- [X] T006 [US1] Implement `CISOImage::ExamineFileSectors` (start track, `SalIsoTrackStoresForm2`, first sector, trigger, 64-sector block reads, out of memory marks the listing) and `CISOImage::ReadMixedBlock` in `src/plugins/uniso/isoimage.cpp`
- [X] T007 [US1] `CISO9660::AddFileDir` takes the XA attributes (`xaKnown`, `xaAttrs`); 366's branch first, else `ExamineFileSectors` sets `Form2`, size, `Scanned`, `WholeSectors`; update the caller in `ListDirectoryRe` and the declaration in `src/plugins/uniso/iso9660.h` / `src/plugins/uniso/iso9660.cpp`
- [X] T008 [US2] `CISO9660::UnpackFile` reads a `Form2 == 2` file with `ReadMixedBlock` (2324-byte buffer, `nbytes = min(read, remain)`) in `src/plugins/uniso/iso9660.cpp`
- [X] T009 [P] [US2] `CRawFS::UnpackFile` the same in `src/plugins/uniso/rawfs.cpp`

## Phase 4: User Story 3 - coverage counts what is read whole (P1)

- [X] T010 [US3] `CISOImage::NoteListedFileStarts`: a `Scanned` file's span from `WholeSectors` (x 2048, by 2048) in `src/plugins/uniso/isoimage.cpp`

## Phase 5: Probe (US1-US4)

- [X] T011 [US1] `specs/367-uniso-form2-unmarked/probe/img367.py` from 366's `img366.py`: expectations by the new rule (per-sector content of an examined file); new rows C-NOXA-NRG (2336 layout, rawfs path), C-MIXED-BIN (raw .bin, the ISO 9660 reader), C-BADSUB (C-NOXA plus one damaged subheader in the middle: that sector 2048, the image kept), C-LASTF1 (AVSEQ01 without XA, record ending inside a Form 1 last sector: mixed with the remainder, the image kept)
- [X] T012 [US1] `specs/367-uniso-form2-unmarked/probe/iso367_probe.ps1` from 366's probe with 367's rows and image fates
- [X] T013 Run the probe on the hidden desktop (`probe/result_after.txt`), every row PASS, registry restored
- [X] T014 [US4] Negative control: the probe with main's `uniso.spl` (worktree build) - the 367 rows fail (`probe/result_negative_main.txt`)
- [X] T015 [US4] Regressions: 337's (with 336 / 335 rows), 365's, 334's probes on the feature build (`probe/regress_*.txt`)

## Phase 6: Polish

- [X] T016 `python tools/check_encoding.py --strict` -> TOTAL: 0; clang-format of the changed lines
- [X] T017 fix-log.md: implementation, checks, probe numbers; SC-005 verified from the code path (one 24-byte read per file on a Form-2-storing track before the trigger decides; an examined file read 64 sectors a read)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008/T009 -> T010 -> T011 -> T012 -> T013 -> T014/T015 -> T016 -> T017.
US1 and US2 share the listing and readers (one increment); US3 depends on the `Scanned` data of US1; US4 is
verified by the control and regression rows.

## Parallel

T008 and T009 (different files). T014 and T015 run one after another on the hidden desktop (probes share the
registry key) - not in parallel.

## Implementation strategy

MVP = Phases 2-4 (rules, listing, readers, coverage), then the probe proves it on the real vcdimager images.
