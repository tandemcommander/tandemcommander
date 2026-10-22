# Tasks: Link members of a tar are extracted or reported, never dropped silently

**Input**: Design documents from `specs/309-tar-link-members/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

Tests: the item asks for a probe (Unpack + Delete rows) and the project rule asks for saltests of pure
rules - both are included.

## Phase 1: Setup

- [ ] T001 Move the scratch probe into `specs/309-tar-link-members/probe/link309_probe.ps1` and its fixture into `specs/309-tar-link-members/probe/mklink309.py` (names and comments updated), copy the before-measurement to `specs/309-tar-link-members/probe/result_before.txt`, start `specs/309-tar-link-members/fix-log.md` with the measurement at f0187403 and the enumerated consumers (research R6)

## Phase 2: Foundational (blocking)

- [ ] T002 Create `src/common/saltarlink.h`: `SalTarNormalizeNameU8(src, dst)` with the normalization loop moved byte-for-byte from `CArchive::ReadArchiveHeader`, and `SalTarLinkDecide(linkType, targetWritten)` per data-model.md
- [ ] T003 [P] Extend `src/common/salpaxheader.h`: `LinkPathState` / `LinkPath` in `SalPaxValues`, freed by `SalPaxClear`, the `linkpath` keyword in `SalPaxApply` (NUL inside = BAD), `SalPaxEffectiveLinkPath`; update the header comment
- [ ] T004 [P] Add `<string>` and `<unordered_set>` to `src/plugins/tar/precomp.h` before the Debug `new` macro
- [ ] T005 Add `TestTarLink309` to `src/saltests/saltests.cpp` (normalization: `./a.txt`, `a.txt`, `sub//b.txt`, `sub/../a.txt`, `../../x`, `.`; linkpath set / deleted / global / NUL; decision table) and call it

## Phase 3: User Story 1 - a hard-linked file arrives under every name (P1)

**Goal**: hard links whose target was written are extracted as copies. **Independent test**: probe rows UNP-HARD-DEL, UNP-HARD-PAX-DEL, UNP-HARD-GNU-DEL, COPY-HARD.

- [ ] T006 [US1] `src/plugins/tar/tar.h`: `SCommonHeader::LinkType`, `LinkName`; `CArchive::LinkReportShown`, `ReportLinkMember`, `WriteOutLinkCopy`; `WriteOutData` optional `BOOL* written`
- [ ] T007 [US1] `src/plugins/tar/untar.cpp` `ReadTarHeader`: keep the link type, the ustar `linkname`, a GNU 'K' long link name and the PAX `linkpath` (precedence PAX > 'K' > ustar); `SCommonHeader::Initialize` frees `LinkName`
- [ ] T008 [US1] `src/plugins/tar/untar.cpp` `ReadArchiveHeader`: use `SalTarNormalizeNameU8` for the name; decode (`ConvertNameToU8`) and normalize `LinkName` the same way
- [ ] T009 [US1] `src/plugins/tar/untar.cpp`: `WriteOutData` reports `written`; `WriteOutLinkCopy` (source opened read / share-read only, identity check against an existing destination, `SafeFileCreate`, copy, time, attributes, progress text)
- [ ] T010 [US1] `src/plugins/tar/untar.cpp` `DoUnpackArchive`: the written-member set; a found hard link with a written target -> `WriteOutLinkCopy`; record written names

## Phase 4: User Story 2 - a link that cannot be reproduced keeps the archive (P1)

**Goal**: symbolic links and hard links to unwritten targets are reported once and fail the operation. **Independent test**: probe rows UNP-SYM-DEL, UNP-HARD-MISSING-DEL.

- [ ] T011 [US2] `src/plugins/tar/untar.cpp`: `ReportLinkMember` (system text + `name -> link name`, once per operation); `DoUnpackArchive` reports per `SalTarLinkDecide` and returns `!refused`; `UnpackOneFile` reports a link member asked for and returns FALSE

## Phase 5: User Story 3 - a link never damages the file it names (P2)

**Goal**: a destination that is the target itself is not written. **Independent test**: probe row UNP-HARD-TWIN-DEL.

- [ ] T012 [US3] Verify in `src/plugins/tar/untar.cpp` `WriteOutLinkCopy` that the source handle denies writing and that `SalFileIdMatch == simEqual` skips the write and counts the link as written (code review against research R4)

## Phase 6: Polish & verification

- [ ] T013 `python tools/check_encoding.py --strict` -> TOTAL: 0; `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed (record in fix-log.md)
- [ ] T014 Probe `specs/309-tar-link-members/probe/link309_probe.ps1 -Label after` -> every row PASS (`probe/result_after.txt`)
- [ ] T015 Negative controls: (A) `DoUnpackArchive` ignores `refused` from links; (B) the link copy disabled - the probe must fail the matching rows; sources restored byte for byte, re-run after
- [ ] T016 Regressions: 308 probe 12 / 0, 306 probe 28 / 0 (`probe/regress_308.txt`, `probe/regress_306.txt`)
- [ ] T017 Complete `specs/309-tar-link-members/fix-log.md` (change, checks, controls)

## Dependencies

T001 -> T002..T005 -> T006 -> T007 -> T008 -> T009 -> T010 -> T011 -> T012 -> T013 -> T014..T016 -> T017.
T003 and T004 can run in parallel with T002. US2 and US3 build on US1's header fields and copy routine.

## Parallel examples

- T003 (salpaxheader.h) and T004 (precomp.h) touch different files.
- T014 and T016 are separate probe runs (run one after another: probes share the registry key).

## Implementation strategy

MVP = US1 + US2 together (both P1: the copy and the report are the item's Expected); US3 is the safety
guard of the copy and lands with it.
