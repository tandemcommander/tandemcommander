# Tasks: ISO plug-in - an ISO 9660 file stored in several extents is listed once and extracted whole

**Input**: Design documents from `specs/368-uniso-multi-extent/` (spec.md, plan.md, research.md, data-model.md,
contracts/salisoextent.md, quickstart.md)
**Tests**: requested by the project rules (pure rule -> saltests; GUI probe on the hidden desktop).

## Phase 1: Setup

- [X] T001 Record the measurement before (probe result, images, commands) in specs/368-uniso-multi-extent/fix-log.md and keep specs/368-uniso-multi-extent/probe/result_before.txt

## Phase 2: Foundational (the pure rule)

- [X] T002 Create src/common/salisoextent.h per contracts/salisoextent.md (SalIsoExtent, SalIsoRecordContinues, SalIsoExtentSectors, SalIsoExtentSectorBytes, SalIsoExtentsSize, SalIsoExtentChain, SalIsoChainRecord, SalIsoChainEnd, SalIsoChainReadable), UTF-8 BOM, SPDX header
- [X] T003 Add TestIsoMultiExtent_368 to src/saltests/saltests.cpp (include salisoextent.h; grouping, broken chains by name / folder / end, folder with the bit, read plan bytes, sizes above 4 GiB, track check) and call it from main
- [X] T004 Add the CFilePos extent list (Extents, ExtentCount, destructor, no copy) in src/plugins/uniso/isoimage.h and CISOImage::ChainReadable (track of each extent, track extent offset, Form 2 layout) in src/plugins/uniso/isoimage.cpp

## Phase 3: User Story 1 - a file over 4 GiB extracts whole (P1)

**Independent test**: probe rows G-BIG, C-PLAIN, U-PLAIN.

- [X] T005 [US1] In src/plugins/uniso/iso9660.cpp / iso9660.h move the file-record listing of ListDirectoryRe into a helper (name, Rock Ridge / ISO choice, XA, AddFileDir) that takes the record's data and an optional extent list
- [X] T006 [US1] In ListDirectoryRe (src/plugins/uniso/iso9660.cpp) keep a SalIsoExtentChain: HELD records are not listed, CHAIN_DONE lists the first record's name with the extents when ChainReadable, else reports as broken
- [X] T007 [US1] In AddFileDir (src/plugins/uniso/iso9660.cpp) list a chain with the sum of the lengths and an owned copy of the extents in CFilePos; no Form 2 / examine for a chain
- [X] T008 [US1] In CISO9660::UnpackFile (src/plugins/uniso/iso9660.cpp) read a chain extent by extent, sector by sector (SalIsoExtentSectorBytes), single-extent path unchanged

## Phase 4: User Story 2 - every name kind (P1)

**Independent test**: probe rows U-RR, U-RRFIRST, U-JOLIET, U-DIRFLAG, C-JOLIET.

- [X] T009 [US2] Check the grouping uses the raw identifier for ISO 9660, Rock Ridge and Joliet records and that the fit-check count walks count a chain once (src/plugins/uniso/iso9660.cpp)

## Phase 5: User Story 3 - a damaged chain is reported (P2)

**Independent test**: probe rows U-BRKNAME, U-BRKEND.

- [X] T010 [US3] Report a broken chain (another identifier, a folder, the directory's end; not readable by ChainReadable; out of memory) with Error(IDS_ERROR_LISTING_IMAGE, FitCheck, block) and ListingLeftOut.SetIncomplete() outside fit checks, without stopping the walk (src/plugins/uniso/iso9660.cpp)

## Phase 6: Polish & verification

- [X] T011 Build (.\build.cmd) and run saltests; negative control: mutate the rule (chain never broken / read plan) and see saltests fail
- [X] T012 Run specs/368-uniso-multi-extent/probe/iso368_probe.ps1 on the hidden desktop with -BigSeed -> result_after.txt, every row PASS; record in fix-log.md that Unpack of a selection and View (F3) reach the same reader (UnpackArchive / UnpackOneFile -> CISOImage::UnpackFile -> CISO9660::UnpackFile)
- [X] T013 Regression probes 338 (specs/338-uniso-skip-fails-unpack/probe/iso338_probe.ps1) and 337 keep their results -> specs/368-uniso-multi-extent/probe/regress_*.txt
- [X] T014 python tools/check_encoding.py --strict -> TOTAL: 0; fix-log.md before / after

## Dependencies

T001 -> T002 -> T003; T002 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010 -> T011 -> T012 -> T013 -> T014.
US2 and US3 build on US1's walk changes (same function).

## Parallel opportunities

T003 (saltests) and T004 (isoimage) touch different files after T002.

## Implementation strategy

MVP = US1 (the chain listed and read); US2 is verification of the same code on other trees; US3 the fail-closed
branch. All in one build and one probe run.
