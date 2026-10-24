# Tasks: A hybrid disc image whose HFS+ part does not open is kept by Unpack with "Delete archive after unpacking"

**Input**: Design documents from `specs/333-uniso-hfs-part-missing/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

Tests: the spec asks for unit checks of the pure rule (FR-004) and probe rows (SC-001 / SC-002).

## Phase 1: Setup

- [X] T001 Start `specs/333-uniso-hfs-part-missing/fix-log.md` with the measurement at e9f777da (probe `probe/result_before.txt`, 9 PASS / 5 FAIL), the APM install image finding and the design decision of research.md R1

## Phase 2: Foundational (blocking)

- [X] T002 Add `SalHfsVolumeHeaderDeclaresHfsPlus(const unsigned char* hdr, size_t size)` to `src/common/salhfscatalog.h` ("H+" -> true; "BD" with "H+" at bytes 124-125 and size >= 126 -> true; everything else, NULL, size < 2 -> false), with a feature 333 comment
- [X] T003 Add `TestHfsVolumeDeclared333` to `src/saltests/saltests.cpp` (H+, BD+H+, BD original HFS, BD cut at 125 bytes, HX, zeros, the EFI FAT boot sector bytes, NULL, size 0 / 1) and call it from the test list

## Phase 3: User Story 1 - a declared HFS+ part that does not open keeps the image (P1)

**Goal**: H-VER / H-CAT / H-SIZE / H-EXT keep the image.
**Independent Test**: `probe/iso333_probe.ps1` rows H-VER, H-CAT, H-SIZE, H-EXT PASS.

- [X] T004 [US1] Add `BOOL Declared` (public, read by `CUDFISO`) to `CHFS` in `src/plugins/uniso/hfs.h`; initialise to FALSE in the constructor and set it in `CHFS::Open` in `src/plugins/uniso/hfs.cpp` right after the first volume header read succeeds, from `SalHfsVolumeHeaderDeclaresHfsPlus((const unsigned char*)&VolHeader, dwBytesRead)`
- [X] T005 [US1] In `CUDFISO::Open` (`src/plugins/uniso/udfiso.cpp`) mark `PartMissing` when the HFS part did not open and `hfs->Declared` is TRUE (read before `delete hfs`); keep the quiet open; update the feature 330 comment
- [X] T006 [US1] Build (`.\build.cmd`), run saltests, run the probe `probe/iso333_probe.ps1` -> `probe/result_after.txt`; record in fix-log.md

## Phase 4: User Story 2 - valid images and images without an HFS+ volume unchanged (P1)

**Goal**: H-OK, APM-EFI, H-NOSIG still delete the image after a full unpack.
**Independent Test**: those three probe rows PASS.

- [X] T007 [US2] Check the control rows of `probe/result_after.txt`; run the regression probes of features 322, 329, 330, 332 (`specs/3xx-*/probe/*.ps1`) on the new build -> `probe/regress_3xx.txt`
- [X] T008 [US2] Negative control: a build where `Declared` is forced TRUE must FAIL APM-EFI / H-NOSIG, or a saltests mutant that ignores the signature must fail - record which was done in fix-log.md

## Phase 5: Polish

- [X] T009 `python tools/check_encoding.py --strict` -> TOTAL: 0; record the checks in fix-log.md
- [X] T010 Inbox items: the APM install image's "Cannot read sector #00000200." box; the decision on APFS / original HFS / HFSX parts that are never listed

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010. US2 shares the code of
US1 (it is the guard on the same change); no parallel work.

## Implementation Strategy

One small change (MVP = US1 + its guard US2), proven by the probe before / after and saltests.
