---
description: "Tasks for feature 385 - FTP server path compare by the file system's name rule"
---

# Tasks: FTP server folder names compared by the file system's name rule

**Input**: `specs/385-ftp-path-name-rule/` (spec.md, plan.md, research.md, contracts/server-path-rule.md)
**Tests**: requested by the item (a saltests check, the probes) - included.

## Phase 1: Setup

- [X] T001 Start `specs/385-ftp-path-name-rule/fix-log.md` with the measurement of step 3 (byte fold on ACP 1250, callers)

## Phase 2: Foundational (measurement before the fix)

- [X] T002 Copy feature 323's server to `specs/385-ftp-path-name-rule/probe/ftpmini385.py` with a `FTPMINI_SYST` environment option for the SYST reply
- [X] T003 Write the probe `specs/385-ftp-path-name-rule/probe/ftp385_probe.ps1` (345's style: CROSS row `/Č` -> `/Ĝ`, ASCII control `/a` -> `/b`, CASE row `/Čaj` -> `/čaj` recorded as information), registry backed up and restored
- [X] T004 Run the probe on the unchanged build -> `specs/385-ftp-path-name-rule/probe/result_before.txt`; record in fix-log.md

## Phase 3: User Story 1 + 3 - the rule (P1)

**Goal**: the path rule in a header, ASCII answers unchanged; the upload cache answers only for its own folder.

- [X] T005 [US1] Create `src/common/salftpsrvpath.h` per contracts/server-path-rule.md (`ESalFtpSrvPathKind`, `SalFtpVmsEscaped`, `SalFtpServerPathIsPrefix`, the walk with `SalNameOrderEqualCI`)
- [X] T006 [US1] Replace the body of `FTPIsPrefixOfServerPath` in `src/plugins/ftp/ftputils.cpp` by the kind mapping and a call of the header
- [X] T007 [US3] Add `TestFtpServerPath385` to `src/saltests/saltests.cpp`: a copy of the old function (legacy byte fold) as a reference; exhaustive ASCII equivalence over generated paths per kind and both modes; non-ASCII rows (case twins, fold collisions `Č`/`Ĝ` and `ĥ`/`Ĺ`, U+0250/U+2C6F lengths, invalid UTF-8, VMS escapes, roots, trailing separators, Unix stays case-sensitive, a non-ASCII folder name over 519 bytes compared whole - FR-007)
- [X] T008 [US3] Negative control: the reference old function fails the non-ASCII rows (count recorded in fix-log.md)

## Phase 4: User Story 2 - callers (P2)

- [X] T009 [US2] Re-check the 22 callers of research.md R2 against the new answers (no caller change; the cycle check of `src/plugins/ftp/operats7.cpp` stays conservative); record in fix-log.md

## Phase 5: Polish & verification

- [X] T010 `python tools/check_encoding.py --strict` -> TOTAL: 0
- [X] T011 `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [X] T012 Probe after the fix -> `specs/385-ftp-path-name-rule/probe/result_after.txt` (CROSS PASS)
- [X] T013 Regression probes 215, 224, 233, 277 -> `specs/385-ftp-path-name-rule/probe/regress_*.txt`
- [X] T014 fix-log.md: before / after, commands, results

## Dependencies

T001 -> T002 -> T003 -> T004 (before any code change) -> T005 -> T006, T007 -> T008 -> T009 -> T010..T014.
Parallel: T006 and T007 (different files) after T005.

## Implementation strategy

MVP = Phase 3 (the rule + saltests); the probe proves the user-visible effect.
