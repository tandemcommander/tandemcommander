# Tasks: Change Attributes on a junction changes the junction, not its target folder

**Input**: Design documents from `specs/253-attrs-link-own-entry/` (plan.md, spec.md, research.md,
data-model.md, quickstart.md)
**Tests**: requested by the spec (FR-007 unit rule, SC-001 probe rows).

## Phase 1: Setup

- [ ] T001 Start `specs/253-attrs-link-own-entry/fix-log.md` with the measurement before (OS test, probe `probe/result_before.txt` 4 FAIL / PLAIN PASS / ENC NOT DRIVEN)

## Phase 2: Foundational (blocks every story)

- [ ] T002 Add the feature 253 section to `src/common/salreparse.h`: `SalAttrsEntryIsDirLink`, `SalAttrsOpenFlags`, `SalAttrsLinkRefusesEncryption` (header-only, comments in English)
- [ ] T003 Add `TestAttrsLink253()` to `src/saltests/saltests.cpp` (folder link / plain folder / cloud folder / file with reparse bit; open flags for file, folder, link; refusal set / clear / already matching / ChangeEncryption off / not a link) and call it from the test list
- [ ] T004 In `src/worker.cpp` `DoChangeAttrs`: compute `isDirLink` once before the retry loop (`DeleteAsDirLink` only when the listed attributes hold both the directory and the reparse bit) and `refuseCrypt`

## Phase 3: User Story 1 - compression stays on the link (P1)

**Independent test**: probe rows COMP, UNCOMP, SUBC.

- [ ] T005 [US1] `src/worker.cpp`: `CompressFile` / `UncompressFile` take `BOOL ownEntry = FALSE`, open with `SalAttrsOpenFlags(TRUE, ownEntry)`; `DoChangeAttrs` passes `isDirLink`; the Copy / Move callers keep the default

## Phase 4: User Story 2 - times stay on the link (P1)

**Independent test**: probe row TIME.

- [ ] T006 [US2] `src/worker.cpp` `DoChangeAttrs`: the time handle opens with `SalAttrsOpenFlags(isDir, isDirLink)`

## Phase 5: User Story 3 - encryption of a link refused (P2)

**Independent test**: saltests refusal checks; person step on a machine with an EFS certificate.

- [ ] T007 [US3] `src/worker.cpp` `DoChangeAttrs`: in the decrypt and encrypt branches, when `refuseCrypt`, set `error = ERROR_NOT_SUPPORTED` and the title `IDS_ERRORENCRYPTING` instead of calling `MyDecryptFile` / `MyEncryptFile` (not `showEncryptErr`)

## Phase 6: User Story 4 - ordinary entries unchanged (P1)

**Independent test**: probe row PLAIN; 213's probe 8 / 0.

- [ ] T008 [US4] Read the diff of `src/worker.cpp`: every non-link path passes the same flags and calls as before (record in `fix-log.md`)

## Phase 7: Polish & verification

- [ ] T009 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [ ] T010 `.\build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> `0 failed`
- [ ] T011 Probe after: `specs/253-attrs-link-own-entry/probe/result_after.txt` (COMP, UNCOMP, TIME, SUBC, PLAIN PASS; ENC NOT DRIVEN; registry identical)
- [ ] T012 Regression: 213's `attrs_case_link_probe.ps1` -> `specs/253-attrs-link-own-entry/probe/regress_213.txt` 8 / 0
- [ ] T013 Record after / commands / results in `specs/253-attrs-link-own-entry/fix-log.md`

## Dependencies

T001 -> T002 -> T003, T004 -> T005, T006, T007 (same file, sequential) -> T008 -> T009 - T013.
US1, US2, US3 share `DoChangeAttrs`; no parallel work in that file. T003 [different file] can run
beside T004 - T007.

## Implementation strategy

MVP = US1 + US2 (the measured defects); US3 completes the item; US4 is the guard.
