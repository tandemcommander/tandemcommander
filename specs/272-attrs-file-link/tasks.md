# Tasks: Change Attributes on a file symbolic link changes the link, not its target file

**Input**: Design documents from `specs/272-attrs-file-link/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: the spec asks for unit checks of the decision (FR-007, SC-002) and the probe rows
(SC-001, SC-003).

## Phase 1: Setup

- [ ] T001 Confirm the probe `specs/272-attrs-file-link/probe/attrs_flink272_probe.ps1` and the before records (`result_before.txt`, `result_before_nonlink.txt`) are in the feature folder and described in `specs/272-attrs-file-link/fix-log.md`

## Phase 2: Foundational (the decision)

- [ ] T002 Widen the feature 253 section of `src/common/salreparse.h`: `SalAttrsEntryIsDirLink` -> `SalAttrsEntryIsLink(listedAttr, linkByRule)` (reparse bit and the rule, any entry kind); `SalAttrsOpenFlags(isDir, isLink)` = backup semantics for a folder | open reparse point for a link; `SalAttrsLinkRefusesEncryption` parameter renamed `isLink`; header comment names 272
- [ ] T003 Adjust `TestAttrsLink253` and add `TestAttrsFileLink272` (registered in the test list) in `src/saltests/saltests.cpp`: file link is a link, a non-surrogate reparse file and a plain file are not, open flags of a file link / plain file / folder / directory link, encryption refusal of a file link and the "state matches" case

## Phase 3: User Story 1 + 2 - compression and times of a file link stay on the link (P1)

**Independent test**: probe rows COMP, UNCOMP, SUBC, TIME.

- [ ] T004 [US1] In `DoChangeAttrs` (`src/worker.cpp`) decide `isLink` for every entry listed with the reparse bit (`DeleteAsDirLink`, fail closed) via `SalAttrsEntryIsLink` and pass it to `UncompressFile` / `CompressFile`; update their `ownEntry` comments (file links too)
- [ ] T005 [US2] In `DoChangeAttrs` (`src/worker.cpp`) open the time handle with `SalAttrsOpenFlags(isDir, isLink)`

## Phase 4: User Story 3 - encryption of a file link refused (P2)

**Independent test**: saltests; person step (ENC NOT DRIVEN).

- [ ] T006 [US3] Pass `isLink` to both `SalAttrsLinkRefusesEncryption` calls in `DoChangeAttrs` (`src/worker.cpp`); update the feature 253 comment there to say file links too

## Phase 5: User Story 4 - everything else unchanged (P1)

**Independent test**: probe rows PLAIN, NONLINK; 253's and 213's probes.

- [ ] T007 [US4] Diff reading in `src/worker.cpp`: for a plain file / folder and a directory link the flags and calls are identical to before; Copy / Move callers of `CompressFile` / `UncompressFile` / `MyEncryptFile` / `MyDecryptFile` unchanged (Grep the callers); record in `specs/272-attrs-file-link/fix-log.md`

## Phase 6: Polish & verification

- [ ] T008 clang-format the changed lines of `src/common/salreparse.h`, `src/worker.cpp`, `src/saltests/saltests.cpp`; `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [ ] T009 `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> `0 failed`
- [ ] T010 Probe after (`specs/272-attrs-file-link/probe/result_after.txt`): COMP, UNCOMP, TIME, SUBC, PLAIN, NONLINK PASS; ENC NOT DRIVEN; registry identical
- [ ] T011 Regressions: 253's probe (`specs/272-attrs-file-link/probe/regress_253.txt`) 10 / 0 (1 NOT DRIVEN), 213's probe (`specs/272-attrs-file-link/probe/regress_213.txt`) 8 / 0
- [ ] T012 Record the checks, before / after and what is owed to a person (ENC) in `specs/272-attrs-file-link/fix-log.md`

## Dependencies

T001 -> T002 -> T003 -> T004 / T005 / T006 (same function, sequential) -> T007 -> T008 -> T009 ->
T010 / T011 -> T012. No parallel tasks: the three code changes are in one function.

## Implementation strategy

MVP = Phases 2-3 (compression and times, the measured defect); Phase 4 completes the item's
"refuses what a link cannot take"; Phase 5-6 prove nothing else changed.
