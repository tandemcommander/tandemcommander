# Tasks: A cpio hard link whose data name normalizes to empty gets its data

**Input**: `specs/394-cpio-empty-name-link/` (spec.md, plan.md, research.md, data-model.md, quickstart.md)
**Tests**: the probe and saltests checks are part of the item (*Expected*: "measured first with a probe row").

## Phase 1: Setup

- [ ] T001 Start `specs/394-cpio-empty-name-link/fix-log.md` with the before measurement (probe `probe/result_before.txt`, PASS 11 / FAIL 9 at 32c55a19)

## Phase 2: Foundational

- [ ] T002 Add the pure rule `SalCpioKeepsGroupMember` to `src/common/salcpiolink.h`
- [ ] T003 [P] Add saltests checks for `SalCpioKeepsGroupMember` and for `.`, `./`, `/`, `..`, `` normalizing to nothing in `src/saltests/saltests.cpp`
- [ ] T004 Add `NameEmpty` to `SCommonHeader` in `src/plugins/tar/tar.h` and reset it in `SCommonHeader::Initialize` in `src/plugins/tar/untar.cpp`

## Phase 3: User Story 1 - the other names get the data (P1)

**Independent test**: probe rows `UNP-EMPTY-*-DEL` (not FIRST / BADSUM), `UNP-CRC-EMPTY-DOT-DEL`, `UNP-RPM-EMPTY-DOT-DEL`, `COPY-EMPTY-DOT`.

- [ ] T005 [US1] In `ReadArchiveHeader` (`src/plugins/tar/untar.cpp`, branch "skip invalid names") set `NameEmpty` for cpio formats and convert time and attributes as the normal path does
- [ ] T006 [US1] `IsCpioGroupMember` in `src/plugins/tar/untar.cpp` uses `SalCpioKeepsGroupMember(..., NameRefused || NameEmpty)`
- [ ] T007 [US1] `DoUnpackArchive` and `UnpackOneFilePass` in `src/plugins/tar/untar.cpp`: a `NameEmpty` member is never asked (`found = FALSE`)

## Phase 4: User Story 2 - never an empty file with success (P1)

**Independent test**: rows `UNP-EMPTY-DOT-FIRST-DEL`, `COPY-EMPTY-DOT-FIRST`, `UNP-CRC-EMPTY-DOT-BADSUM-DEL`.

- [ ] T008 [US2] `WriteOutData` in `src/plugins/tar/untar.cpp`: verify the crc checksum also when an `Ignored` member's data is written (`!simulate`)
- [ ] T009 [US2] Confirm the data-first rows go through feature 310's report (no code change expected) - record in `fix-log.md`

## Phase 5: User Story 3 - nothing else changes (P2)

- [ ] T010 [US3] Build (`.\build.cmd`), saltests, the probe `specs/394-cpio-empty-name-link/probe/cpioempty_probe.ps1` -> all PASS (`probe/result_after.txt`)
- [ ] T011 [US3] Negative control: the probe against a build without T006 (group rule reverted) in a copy -> the US1 rows fail again (`probe/result_negctl.txt`)
- [ ] T012 [US3] Regression probes of 306, 308, 309, 310, 321 (tar + unpack), 393 -> their recorded results (`probe/regress_*.txt`)

## Phase 6: Polish

- [ ] T013 Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0; `fix-log.md` complete

## Dependencies

T001 -> T002..T004 -> T005..T007 -> T008, T009 -> T010 -> T011, T012 -> T013. T003 parallel to T004.

## Implementation strategy

One small change set (US1 + US2 share `untar.cpp`); verify with the probe, then the regressions.
