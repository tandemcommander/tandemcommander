# Tasks: ISO plug-in - an HFS+ file whose content is not in its data fork is not extracted empty

**Input**: `specs/339-uniso-hfs-fork-content/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: the spec asks for unit checks of the rule (FR-005, SC-003) and probe rows (SC-001, SC-002).

## Phase 1: Setup

- [X] T001 Record the before-measurement and the decisions in specs/339-uniso-hfs-fork-content/fix-log.md (probe/result_before.txt: 12 / 6)

## Phase 2: Foundational (the pure rule)

- [X] T002 Add `SalHfsFileContentKind(rec, avail)` and `SAL_HFSFILE_DATA / COMPRESSED / RESOURCE_ONLY / SHORT` (offsets 41, 42, 88, 168; TN1150's uninitialised file mode) with a header comment to src/common/salhfscatalog.h
- [X] T003 Add `TestHfsFileContent339` (ordinary, empty, compressed with resource fork / inline / with data, flag with mode 0, resource only, both forks, short / NULL record, flags of other bits, a type-bits-only mode, a symbolic link record with its target in the data fork) to src/saltests/saltests.cpp and call it from main
- [X] T004 Build (`.\build.cmd`) and run saltests; run the two mutants (flag ignored, mode check dropped / resource check dropped) and record that each fails checks in fix-log.md

## Phase 3: User Story 1 - a refused file keeps the image (P1)

**Independent test**: probe rows H-RSRC, H-COMP, H-COMPIN, H-FLAG (box, Skip, side.txt not written, image kept); H-OK.

- [X] T005 [US1] Add `IDS_ERR_HFS_FILE_COMPRESSED 1062` and `IDS_ERR_HFS_FILE_RSRC_ONLY 1063` to src/plugins/uniso/uniso.rh2 and their English texts to src/plugins/uniso/lang/lang.rc2
- [X] T006 [US1] In `CHFS::UnpackFile` (src/plugins/uniso/hfs.cpp) after the record checks and before the name / buffer / `SafeFileCreate`: ask `SalHfsFileContentKind`; for COMPRESSED / RESOURCE_ONLY show `DialogError(..., BUTTONS_SKIPCANCEL, fileData->Name, LoadStrU8(text), LoadStr(IDS_ERROR))` when `silent == 0`, Skip all sets `silent = 1`, Cancel returns `UNPACK_CANCEL`, otherwise return `UNPACK_ERROR`

## Phase 4: User Story 2 - Skip all and Cancel (P2)

**Independent test**: probe rows H-SKIPALL, H-CANCEL.

- [X] T007 [US2] Confirm in specs/339-uniso-hfs-fork-content/probe/iso339_probe.ps1 that H-SKIPALL counts one box and both files missing and H-CANCEL only side.txt missing (the T006 code serves both); add row H-EXIST (FR-003: the target holds the user's own a/side.txt = OLD; hdh_comp.iso answered Skip: side.txt stays OLD, the image kept)

## Phase 5: User Story 3 - ordinary files unchanged (P3)

**Independent test**: probe rows H-OK, H-NOMODE, H-BOTH.

- [X] T008 [US3] Run the probe after the fix (`probe/result_after.txt`): every row PASS; regression probes 332 (16 / 0) and 333 (20 / 0) into probe/regress_332.txt and probe/regress_333.txt

## Phase 6: Polish

- [X] T009 Translations: two-stage `.slt` refresh of module `uniso` (stop-rules 2.13: export, dry run = 2 gaps a language, merge `--formality prefer_more`, read back, pin, `slt --verify`), then `.\build.cmd full`
- [X] T010 `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s)
- [X] T011 Inbox items: the resource fork of a file that also has data is dropped while the image is deleted (`measure:339`); the person check with a Mac-made image (at closing, `leftover:339`)
- [X] T012 fix-log.md: after-measurement, checks with numbers, translations section

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010 -> T012; T011 any time after T006.
US2 and US3 depend on T006 only (one code change serves all three stories).

## Parallel opportunities

T003 and T005 touch different files ([P] in spirit); the run executes sequentially.

## Implementation strategy

MVP = Phase 2 + US1 (the image is kept); US2 / US3 are verification of the same change.
