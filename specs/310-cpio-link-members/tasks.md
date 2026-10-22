# Tasks: Links in a cpio or rpm are extracted or reported, never dropped silently

**Input**: Design documents from `specs/310-cpio-link-members/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

Tests: saltests checks for the pure rule and the hidden-desktop probe are required by the project
(CLAUDE.md working method), so they are part of the tasks.

## Phase 1: Setup

- [X] T001 Start `specs/310-cpio-link-members/fix-log.md` with the measurement before the fix (commands, `probe/result_before.txt` 13 PASS / 7 FAIL)

## Phase 2: Foundational

- [ ] T002 Create the header-only rule `src/common/salcpiolink.h`: `SalCpioIsLinkGroupMember(bool newcOrCrc, unsigned long mode, unsigned long nlink)` and `SalCpioLinkDecide(bool asked, bool hasData, int state, bool anyWaiting)` with the actions and states of `data-model.md`
- [ ] T003 [P] Add `TestCpioLink310` to `src/saltests/saltests.cpp` (include `salcpiolink.h`; every row of the decision table, the grouping rule: odc / binary, folders, symlinks, nlink 1 never grouped) and call it from `main`
- [ ] T004 Add `CpioIno`, `CpioNLink`, `CpioDevMajor`, `CpioDevMinor` to `SCommonHeader` in `src/plugins/tar/tar.h` (reset in `SCommonHeader::Initialize`, `src/plugins/tar/untar.cpp`); read fields 0, 4, 7, 8 in `CArchive::ReadNewASCIIHeader`; include `salcpiolink.h` in `src/plugins/tar/tar.h`

## Phase 3: User Story 1 - every name of a hard-linked file arrives with its content (P1)

Goal: newc / crc names stored with size 0 get the data stored with another name of the file.
Independent test: probe rows CPIO-HARD-DEL, CPIO-CRC-HARD-DEL, CPIO-HARD-FIRST-DEL, CPIO-HARD-DEV-DEL, COPY-CPIO-ALL, COPY-CPIO-ONE, VIEW-CPIO-ONE, VIEW-CPIO-FIRST.

- [ ] T005 [US1] Add the per-operation group store (key -> state, written target, data name, waiting names) and helpers (copy the waiting names via `WriteOutLinkCopy`, report via `ReportLinkMember`, write empty files at the end) in `src/plugins/tar/untar.cpp` / `src/plugins/tar/tar.h`
- [ ] T006 [US1] Apply `SalCpioLinkDecide` in `CArchive::DoUnpackArchive` (`src/plugins/tar/untar.cpp`): WRITE / WRITE_FOR_WAITING (header name swapped for the waiting member's while writing) / WAIT / COPY / REPORT / SKIP; flush waiting groups as empty files at the trailer and at end of data; nothing more is written on an error or Cancel
- [ ] T007 [US1] In `CArchive::UnpackOneFile` (`src/plugins/tar/untar.cpp`): a found grouped name with size 0 reads on to the group's data member and writes its data under the asked name; empty at the end when no member carried data; reported (fail) when the data came earlier
- [ ] T008 [P] [US1] Add VIEW-CPIO-ONE and VIEW-CPIO-FIRST rows (F3, cached copy in `SAL*.tmp`) to `specs/310-cpio-link-members/probe/cpio310_probe.ps1` and their fixtures to `specs/310-cpio-link-members/probe/mkcpio310.py`

## Phase 4: User Story 2 - a symbolic link that is left out keeps the archive (P1)

Goal: a cpio symlink asked for is reported once and fails the operation.
Independent test: probe row CPIO-SYM-DEL.

- [ ] T009 [US2] In `CArchive::ReadArchiveHeader` (`src/plugins/tar/untar.cpp`): for a cpio `CP_IFLNK` member set `LinkType = SAL_TAR_TYPE_SYMLINK`, read its target (1..4096 bytes) into `LinkName`, count it in `Offset`, set the size to 0; the existing feature 309 code reports it

## Phase 5: User Story 3 - what worked keeps working (P2)

Independent test: probe rows CPIO-HARD-EMPTY-DEL, CPIO-ODC-HARD-DEL, CPIO-FIFO-DEL; 309 / 308 / 306 probes.

- [ ] T010 [US3] Build (`build.cmd`), run saltests, run the probe after the fix (`probe/result_after.txt`) and the 309, 308, 306 probes (`probe/regress_309.txt`, `regress_308.txt`, `regress_306.txt`)
- [ ] T011 [US3] Negative control: disable the group handling (decision forced to WRITE) and confirm the hard-link rows fail again; restore and record in `specs/310-cpio-link-members/fix-log.md`

## Phase 6: Polish

- [ ] T012 Encoding guard `python tools/check_encoding.py --strict` (TOTAL: 0); clang-format the changed sources; record everything in `specs/310-cpio-link-members/fix-log.md`

## Dependencies

T001 -> T002 -> (T003, T004) -> T005 -> T006 -> T007; T009 after T004; T008 any time; T010 after T006, T007, T009; T011 after T010; T012 last.

## Parallel examples

T003 (saltests) beside T004 (header fields); T008 (probe rows) beside T005-T007.

## Implementation strategy

MVP: US1 + US2 together (both P1, both fail the item's measurement), then US3 regressions.
