---
description: "Tasks for 345-ftp-upload-cache-user-port"
---

# Tasks: An FTP change made as another user or through another port reaches the running uploads

**Input**: Design documents from `specs/345-ftp-upload-cache-user-port/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: the feature's hidden-desktop probe (spec SC-001..SC-003) - written and run before the fix.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [ ] T001 Measure on `main` with `specs/345-ftp-upload-cache-user-port/probe/ftp345_probe.ps1` (result `probe/result_main.txt`: 11 PASS / 5 FAIL) and record it in `specs/345-ftp-upload-cache-user-port/fix-log.md`

## Phase 2: Foundational

- [ ] T002 Add the static helper `CUploadListingCache::SameIdentity` (declaration and comment) in `src/plugins/ftp/operats.h` and use it in `FindServer` and `StampChange` in `src/plugins/ftp/operats9.cpp` (no behaviour change)

## Phase 3: User Story 1 + 2 - a panel change made as another user / through another port reaches the upload (P1)

**Goal**: a change reported under one identity invalidates the listings of every other identity.
**Independent Test**: probe rows USER-REN, PORT-REN, ALL-REN PASS; ALIAS-REN, SAME-REN stay PASS.

- [ ] T003 [US1] In `CUploadListingCache::InvalidateOtherNamesOfServer` (`src/plugins/ftp/operats9.cpp`) invalidate every entry except `exact` (drop the same-user / same-port filter); update its comment and the declaration's comment in `src/plugins/ftp/operats.h`

## Phase 4: User Story 3 - a panel's old listing is not trusted after a change made elsewhere (P2)

**Goal**: a panel listing started before a change under any other identity is refused.
**Independent Test**: probe rows SEED-USER, SEED-PORT PASS; SEED-SAME stays PASS.

- [ ] T004 [US3] In `CUploadListingCache::ChangedUnderOtherName` (`src/plugins/ftp/operats9.cpp`) count every stamp whose identity is not the listing's own (`!SameIdentity`); update the comments of `ChangeStamps` and `ChangedUnderOtherName` in `src/plugins/ftp/operats.h`

## Phase 5: Polish & verification

- [ ] T005 Build (`build.cmd`), encoding guard (`python tools/check_encoding.py --strict`), saltests
- [ ] T006 Run `ftp345_probe.ps1` after the fix (`probe/result_after.txt`: 16 / 0) and the regressions `specs/341-ftp-upload-cache-alias/probe/ftp341_probe.ps1` and `specs/323-ftp-upload-cache-args/probe/ftp302_probe.ps1`
- [ ] T007 Negative control: the fix reverted in a copy (or a mutant build) -> the five rows FAIL; record in `specs/345-ftp-upload-cache-user-port/fix-log.md`
- [ ] T008 Record before / after, commands and results in `specs/345-ftp-upload-cache-user-port/fix-log.md`

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 -> T008 (one file pair; no parallel work).

## Implementation Strategy

MVP = T002 + T003 (the item's measured row USER-REN); T004 closes the panel-seed path of the same
defect; both are needed to close the item.
