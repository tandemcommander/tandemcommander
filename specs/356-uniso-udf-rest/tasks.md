# Tasks: A UDF-only disc image is kept when it holds more than its listing shows

**Input**: `specs/356-uniso-udf-rest/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: required by the project (pure rule → `saltests`; GUI → hidden-desktop probe).

## Phase 1: Setup

- [X] T001 Run the probe on the main build (before) once no Tandem Commander runs and record the rows in specs/356-uniso-udf-rest/fix-log.md (probe specs/356-uniso-udf-rest/probe/iso356_probe.ps1, result_before.txt)

## Phase 2: Foundational (the pure rule)

- [X] T002 Add the UDF parsers to src/common/salisotrack.h: `SalIsoUdfTagValid`, `SalIsoUdfReadAnchor` / `SalIsoUdfAnchor`, `SalIsoUdfAnchorOf`, `SalIsoUdfPartitionEnd`, `SalIsoUdfLvdHasVirtualMap`, `SalIsoUdfFileEntryAt`, `SalIsoUdfExtentEnd` (data-model.md)
- [X] T003 Add `SalIsoUdfVolume`, `SalIsoUdfRestDecision` (reusing `SalIsoCookedRestDecision`) and `SalIsoUdfRestSectorEmpty` to src/common/salisotrack.h
- [X] T004 Add `TestIsoUdfRest_356` to src/saltests/saltests.cpp: tag checksum / location, anchor extents, partition end, virtual map, file entry, decision rows (closed at end, VAT, descriptors' end + 16 / 17 / 512 / 513, short file, unknown anchor / partition), rest sector (zero, own anchor, other anchor, data, partial)

## Phase 3: User Story 1 - a UDF-only image holding a second volume is kept (P1)

- [X] T005 [US1] Add `CISOImage::UdfRestMarks(LONGLONG fileSize)` to src/plugins/uniso/isoimage.h and src/plugins/uniso/isoimage.cpp: read sector 256, the main sequence (at most 64 sectors), the file's last sector and the one 256 before it, the rest sector by sector; fails closed on any short read
- [X] T006 [US1] Call it in `CISOImage::Open`'s `cookedIso` block when sector 16 is not an ISO 9660 primary descriptor, marking `ListingLeftOut` (src/plugins/uniso/isoimage.cpp)
- [X] T007 [US1] Build, saltests, probe rows R-TWO, R-TWOIMG, R-TWOABS, R-REST17 (after)

## Phase 4: User Story 2 - plain one-volume UDF images still deleted (P2)

- [X] T008 [US2] Probe rows C-PLAIN, C-U250, C-REST16, C-ZERO100, C-ANCHORREST, C-ZERO512, C-ANCHOR600, C-MKHD, C-MKDVD, C-MKCDRW, C-MKCDR, C-MKCDRC, C-MKDVDR, C-MKBDR (after)

## Phase 5: User Story 3 - an end that cannot be read keeps the image (P3)

- [X] T009 [US3] Probe rows R-ZERO513, R-ZERO300, R-ZEROLATE, R-SHORT, R-NOANCHOR, R-MKHD512 (after)

## Phase 6: Polish

- [X] T010 Negative control: a mutant whose `SalIsoUdfRestDecision` always keeps - saltests and probe must fail; record in fix-log.md
- [X] T011 Regressions: probes of 354 (iso354_probe.ps1) and 355 (iso355_probe.ps1) on the fix; encoding guard `python tools/check_encoding.py --strict`
- [X] T012 fix-log.md: before / after, commands, results

## Dependencies

T001 independent (needs no running Tandem Commander); T002 → T003 → T004; T003 → T005 → T006 → T007 → T008, T009 → T010 → T011 → T012.
Parallel: T001 with T002 - T004. MVP: Phase 2 + US1.
