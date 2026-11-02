# Tasks: An ISO 9660 folder whose length cannot be a directory of the image is a folder that cannot be read

**Input**: `specs/403-uniso-dir-length/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: requested by the spec (FR-005 `saltests`, SC-001 / SC-002 probes).

## Phase 1: Setup

- [X] T001 Record the measurement before (probe 6 / 6, memory box, Ignore ends the program) in specs/403-uniso-dir-length/fix-log.md and keep specs/403-uniso-dir-length/probe/result_before.txt

## Phase 2: Foundational (the pure rules)

- [X] T002 Add `SAL_ISO_DIR_MAX_LENGTH`, `SalIsoDirLengthReadable` and `SalIsoDirLastBlock` (64-bit, no wrap) to src/common/salisowalk.h
- [X] T003 Add `TestIsoDirLength403` (bounds 0 / 1 / limit / limit+1 / 0x7FFFF800 / 0x80000000 / 0xFFFFF800 / 0xFFFFFFFF; last block of 1 sector, 3 sectors, a non-2048 sector size, past 0xFFFFFFFF, length 0, sector size 0) and call it in src/saltests/saltests.cpp

## Phase 3: User Story 1 - a length of 2 GiB or more never offers to end the program (P1)

**Independent test**: probe rows IS-NEG, IS-NEG2, IS-MIN - one read-error box, the other folders extracted, the image kept.

- [X] T004 [US1] Add the inline accessor `GetSectorUserSize()` to `CISOImage` in src/plugins/uniso/isoimage.h
- [X] T005 [US1] In `CISO9660::ListDirectoryRe` (src/plugins/uniso/iso9660.cpp) hold the length as `DWORD`; before the allocation refuse a length `SalIsoDirLengthReadable` refuses through the existing failed-read path (box once per walk, ERR_TERMINATE / ERR_CONTINUE for the root); keep the `size == 0` case and the visited check as they are

## Phase 4: User Story 2 - implausible or past-the-end lengths refused before memory is taken (P2)

**Independent test**: probe rows IS-HUGE, IS-PAST; `TestIsoDirLength403`.

- [X] T006 [US2] In `CISO9660::ListDirectoryRe` (src/plugins/uniso/iso9660.cpp) read the last sector (`SalIsoDirLastBlock`, 1 byte through `Image->ReadBlock`) of a folder longer than one sector before the allocation; a refused block or a failed read takes the same failed-read path

## Phase 5: User Story 3 - valid folders unchanged (P1)

**Independent test**: probe row IS-EDGE; regression probes.

- [X] T007 [US3] Build (`.\build.cmd`), run saltests and `iso403_probe` after (12 / 0) into specs/403-uniso-dir-length/probe/result_after.txt
- [X] T008 [US3] Run the regression probes of 328, 400, 401, 402 into specs/403-uniso-dir-length/probe/regress_<NNN>.txt
- [X] T009 [US3] Negative control: the length rule off (a mutant) - saltests fail; record in specs/403-uniso-dir-length/fix-log.md

## Phase 6: Polish

- [X] T010 Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0; update specs/403-uniso-dir-length/fix-log.md with after-results

## Phase 7: Review 1

- [X] T011 [US2] Budget of the buffers held at once: `SalIsoDirTake` / `SalIsoDirGive` in src/common/salisowalk.h, `CISO9660::DirBytesHeld` in src/plugins/uniso/iso9660.h, taken and given back (RAII) in `ListDirectoryRe` (src/plugins/uniso/iso9660.cpp); checks in `TestIsoDirLength403` (src/saltests/saltests.cpp)
- [X] T012 [US2] Probe rows IS-DEEP and IS-OVER (specs/403-uniso-dir-length/probe/img403.py, iso403_probe.ps1); negative control with the budget off; regression probes again (regress_<NNN>_review1.txt)

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 / T009 -> T010. US2 builds on US1's site;
US3 verifies both. MVP: US1 (T002-T005).

## Parallel

T003 and T004 touch different files ([P]-able after T002); probes run one at a time (one desktop).
