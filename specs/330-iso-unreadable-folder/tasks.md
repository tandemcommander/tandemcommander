# Tasks: An image whose folder could not be read is kept by Unpack with "Delete archive after unpacking"

**Input**: Design documents from `specs/330-iso-unreadable-folder/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: the hidden-desktop probe is the test (CLAUDE.md working method: measure before and after).

## Phase 1: Setup

- [X] T001 Start the running record `specs/330-iso-unreadable-folder/fix-log.md` with the measurement at ae41208d (review 4's `rderr.iso`, RDERR-UNP-DEL: 1 of 3 files, image deleted)

## Phase 2: Foundational (the probe, run before the fix)

- [X] T002 Write the seed script `specs/330-iso-unreadable-folder/probe/mkimg330.sh` (WSL, `~/tc-genisoimage`): `rd.iso` (`-R`) and `ud.iso` (`-udf`) of `a/side.txt`, `top.txt`, `zlast/z.txt`
- [X] T003 Write `specs/330-iso-unreadable-folder/probe/img330.py`: `isoext` (ISO 9660 folder A's extent past the end), `isorec` (a record in folder A's directory with mismatched both-endian extent), `udfext` (UDF folder A's file entry allocation descriptor past the end), `xbox` / `xboxext` (an Xbox image of the tree, intact / folder A's start sector past the end); each prints what it patched and refuses when the layout is not the expected one
- [X] T004 Write the probe `specs/330-iso-unreadable-folder/probe/iso330_probe.ps1` in the style of `specs/329-uniso-other-readers-refused/probe/iso329_probe.ps1`: Unpack (Alt+F9) rows with "Delete archive after unpacking" - damaged RD-EXT, RD-REC, UD-EXT, XD-EXT (PASS = the "Error reading directory structure" box, `top.txt` extracted, the image kept) and controls RD-OK, UD-OK, XD-OK (PASS = all three files, no box, the image deleted); registry backed up / restored / verified; fixture under `%TEMP%`
- [X] T005 Run the probe on the build before the fix -> `specs/330-iso-unreadable-folder/probe/result_before.txt` (expected: damaged rows FAIL - image deleted; controls PASS); record in fix-log.md

## Phase 3: User Story 1 - Unpack + delete keeps an image whose folder could not be read (P1)

**Goal**: a read error in a folder walk marks the listing incomplete; a whole unpack then fails and the image is kept.
**Independent test**: the damaged rows of `iso330_probe.ps1`.

- [X] T006 [US1] `src/plugins/uniso/iso9660.cpp` `CISO9660::ListDirectory`: the real walk's result other than `ERR_OK` -> `Image->ListingLeftOut.SetIncomplete()` (comment: feature 330, why every failure reaches the top)
- [X] T007 [P] [US1] `src/plugins/uniso/udf.cpp`: `SetIncomplete()` before each `Error(IDS_ERROR_LISTING_IMAGE, ...)` - `CUDF::ListDirectory` (File Set Descriptor read), `CUDF::ScanDir` (first read, continuation read)
- [X] T008 [P] [US1] `src/plugins/uniso/xdvdfs.cpp` `CXDVDFS::ScanDir`: `SetIncomplete()` before its `Error(IDS_ERROR_LISTING_IMAGE, ...)`
- [X] T009 [US1] `.\build.cmd` -> BUILD SUCCEEDED; probe after the fix -> `probe/result_after.txt` (all rows PASS)

## Phase 4: User Story 2 - A readable image is unpacked and deleted as before (P1)

**Independent test**: the control rows of `iso330_probe.ps1` and the regression probes.

- [X] T010 [US2] Regression: `specs/328-uniso-refused-entry/probe/iso328_probe.ps1` (20 / 0) -> `specs/330-iso-unreadable-folder/probe/regress_328.txt`; `specs/329-uniso-other-readers-refused/probe/iso329_probe.ps1` (all PASS) -> `probe/regress_329.txt`
- [X] T011 [US2] Negative control: confirm the damaged rows fail without the fix (T005's before run on the same probe) and pass with it; record in fix-log.md

## Phase 5: Polish

- [X] T012 `python tools/check_encoding.py --strict` -> TOTAL: 0; saltests -> 0 failed (`build\tandemcommander\Debug_x64\saltests\saltests.exe`)
- [X] T013 Inbox idea (`leftover:330`, `iso-plug-in-after-a-folder-that-cannot-be-read-no-later`): after a read error the ISO 9660 / UDF walks descend no later folder (the item's "separate question"); record in fix-log.md

## Dependencies

T001 -> T002/T003 -> T004 -> T005 -> T006..T008 -> T009 -> T010/T011 -> T012/T013. T007 and T008 touch different files than T006 and each other.

## Implementation strategy

MVP = US1 (the mark in the three readers); US2 is the proof that nothing else changed.
