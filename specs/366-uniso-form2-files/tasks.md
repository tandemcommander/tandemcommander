# Tasks: The ISO plug-in extracts Video CD / SVCD video files whole

**Input**: Design documents from `specs/366-uniso-form2-files/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: required by the project (CLAUDE.md: pure rules with `saltests` checks; a hidden-desktop probe).

## Phase 1: Setup

- [X] T001 Record the measurement before (real images, probe rows, content comparison) in specs/366-uniso-form2-files/fix-log.md

## Phase 2: Foundational (rules, blocking every story)

- [X] T002 Add `SalIsoXaAttributes`, `SalIsoXaIsForm2File`, `SalIsoTrackStoresForm2`, `SalIsoForm2FileSize` and a bytes-a-sector parameter of `SalIsoFileSectorSpan` (default 2048) in src/common/salisotrack.h
- [X] T003 Add `TestIsoXaForm2_366` (XA record found / absent / short / bad signature / odd and even identifier lengths; attribute combinations 0x1555, 0x3555, 0x0D55, 0x3D55, 0x8D55, 0; track layouts 2352/24, 2336/8, 2448/24, 2448/16, 2352/16, 2048/0; sizes 0, 1, 2048, 2049, 608256, 0xFFFFFFFF; spans with 2324) and call it from main in src/saltests/saltests.cpp
- [X] T004 Build and run saltests; try mutants (Form 1 bit ignored, header check dropped, size rounding down, span with 2048) and record that each fails checks, in specs/366-uniso-form2-files/fix-log.md

## Phase 3: User Story 1 - Video CD video files extract whole (P1)

**Independent test**: real VCD (CCD, NRG) and SVCD images - extracted file content equals the 2324-byte read.

- [X] T005 [US1] Add `BYTE Form2` to `CISOImage::CFilePos` (constructor FALSE) and declare `FileIsForm2(DWORD extent)` and `ReadForm2Block(DWORD block, void* data)` in src/plugins/uniso/isoimage.h
- [X] T006 [US1] Implement `CISOImage::FileIsForm2` (the extent's track by `GetTrackFromExtent`, `SalIsoTrackStoresForm2`, the first sector read at its stored position and `SalIsoSectorIsForm2`) and `CISOImage::ReadForm2Block` (2324 bytes at `GetSectorOffset(block)`, 0 when the open track does not store Form 2 data) in src/plugins/uniso/isoimage.cpp
- [X] T007 [US1] In `CISO9660::ListDirectoryRe` read the file record's XA attributes and pass them to `AddFileDir`; in `AddFileDir` set `filePos->Form2` and the size `SalIsoForm2FileSize` for a Form 2 file (not in the fit-check pass) in src/plugins/uniso/iso9660.cpp
- [X] T008 [US1] `CISO9660::UnpackFile`: read a `Form2` file with `ReadForm2Block`, 2324 bytes a sector, in src/plugins/uniso/iso9660.cpp
- [X] T009 [US1] `CRawFS::UnpackFile`: the same for a `Form2` file in src/plugins/uniso/rawfs.cpp
- [X] T010 [US1] Write the image generator (real VCD / SVCD as CCD and NRG, a plain raw `.bin`, control images) with `expect.json` (size and SHA-256 per file) in specs/366-uniso-form2-files/probe/img366.py
- [X] T011 [US1] Write the probe (whole Unpack with "Delete archive after unpacking", SHA-256 of every extracted file against `expect.json`, the image's fate) in specs/366-uniso-form2-files/probe/iso366_probe.ps1, built on 335's `review3/rev335c_probe.ps1`

## Phase 4: User Story 2 - everything else as before (P1)

**Independent test**: the control rows and the regression probes.

- [X] T012 [US2] Control rows in img366.py / iso366_probe.ps1: mixed attributes 0x3D55, no XA record, Form 1 first sector under a Form 2 attribute, cooked 2048-byte image - each extracts the 2048-byte content (main's result); and a VCD image cut inside the last video track (the Form 2 file's last sectors missing: a read error, no file written whole, the image kept) in specs/366-uniso-form2-files/probe/
- [X] T013 [US2] Run the probe on main's build (negative control: the US1 rows fail, the control rows pass) and on the feature build; record in specs/366-uniso-form2-files/fix-log.md

## Phase 5: User Story 3 - coverage counts the new size (P2)

**Independent test**: 337's probe rows; a partly covering Form 2 file keeps the image.

- [X] T014 [US3] `CISOImage::NoteListedFileStarts` passes 2324 to `SalIsoFileSectorSpan` for a `Form2` file in src/plugins/uniso/isoimage.cpp
- [X] T015 [US3] Probe row: a VCD whose `AVSEQ01.DAT` record is shortened (fewer sectors than its stream, XA Form 2) keeps the image, in specs/366-uniso-form2-files/probe/
- [X] T016 [US3] Regression probes 337 (with 336 / 335 rows), 365, 334 on the feature build; results into specs/366-uniso-form2-files/probe/ and fix-log.md

## Phase 6: Polish

- [X] T017 Encoding guard `python tools/check_encoding.py --strict` (TOTAL: 0), `build.cmd`, saltests, clang-format of the changed lines only; record in specs/366-uniso-form2-files/fix-log.md

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005..T009 (in order; T008 / T009 after T006) -> T010 -> T011 -> T012 -> T013;
T014 after T005; T015 after T011; T016 after T014; T017 last.

## Parallel opportunities

T008 and T009 (different files); T010 while the build runs.

## Implementation strategy

MVP = US1 (the cut fixed) with US3's span change in the same build (data safety); US2's controls prove nothing
else changed.
