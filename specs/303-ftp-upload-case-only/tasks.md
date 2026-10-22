# Tasks: An FTP upload asks before replacing a server file whose name differs only in case

**Input**: `specs/303-ftp-upload-case-only/` (plan.md, spec.md, research.md, data-model.md,
contracts/case-only-lookup.md, quickstart.md)
**Tests**: requested by the spec (FR-008 saltests checks, SC-001..SC-005 probe rows).

## Phase 1: Setup

- [X] T001 Record the "before" measurement (already run: `probe/result_before.txt`, PASS 5 / FAIL 3) and the caller enumeration in specs/303-ftp-upload-case-only/fix-log.md

## Phase 2: Foundational (the pure rule)

- [X] T002 Create src/common/salftpupname.h with `SalFtpFindCaseOnlyName(count, getName, name)` per contracts/case-only-lookup.md (UTF-8-BOM, SPDX header, English comments, includes salnameorder.h)
- [X] T003 Add `TestFtpCaseOnlyName303` to src/saltests/saltests.cpp (include `salftpupname.h // feature 303`, call it from main): B.txt vs b.txt found; c.txt not; exact-only listing -> -1; lowest index of several twins; Č/č found; NFC vs NFD not; Kelvin sign vs k not; NULL name / NULL entries / count 0 -> -1
- [X] T004 Build (`.\build.cmd`) and run saltests; then a negative control (the rule replaced by a byte comparison) must fail the new checks - record both in fix-log.md

## Phase 3: User Story 1 - the overwrite question for a case-only name (P1)

**Goal**: an upload of `B.txt` beside `b.txt` asks the question. **Independent test**: probe rows CASE-UP, CASE-CZ, CASE-OVR.

- [X] T005 [US1] Add `BOOL caseOnlyCounts` to `CUploadListingCache::GetListing` and `CUploadListingsOnServer::GetListing` declarations in src/plugins/ftp/operats.h (comment: what it means)
- [X] T006 [US1] Implement it in src/plugins/ftp/operats9.cpp: pass through in `CUploadListingCache::GetListing`; in `CUploadListingsOnServer::GetListing` after `FindItem` fails and `caseOnlyCounts`: `SalFtpFindCaseOnlyName` over `listing->ListingItem`; found -> `nameExists`, copy with `ByteSize = UPLOADSIZE_UNKNOWN`
- [X] T007 [US1] Pass TRUE at the file upload start check (`fwssWorkStartWork`) in src/plugins/ftp/operatsb.cpp; FALSE at both folder sites in src/plugins/ftp/operatsa.cpp

## Phase 4: User Story 2 - unrelated names upload as before (P2)

**Goal**: no question without a twin; the exact twin wins. **Independent test**: probe row CASE-NEW; saltests exact-only check.

- [X] T008 [US2] Confirm by reading that the exact `FindItem` hit is tried first and unchanged in src/plugins/ftp/operats9.cpp, and that a configured automatic answer (US1 scenario 4: `GetUploadFileAlreadyExists` overwrite / skip / auto-rename / resume in operatsb.cpp `fwssWorkUploadFileExists`) applies to a case-only match through the same branch; no new string (FR-007) - record in fix-log.md

## Phase 5: User Story 3 - auto-rename and resume stay safe (P3)

**Goal**: no auto-rename name colliding by case, no resume at a twin's size. **Independent test**: by reading + saltests.

- [X] T009 [US3] Pass TRUE at `fwssWorkUploadGetFileSizeFromListing` and `fwssWorkUploadGenNewName` in src/plugins/ftp/operatsb.cpp; record the unknown-size branches they reach in fix-log.md

## Phase 6: Polish & verification

- [X] T010 `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s); `.\build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed
- [X] T011 Run the probe after the fix (`probe/result_after.txt`): CASE-UP, CASE-CZ, CASE-NEW, CASE-OVR PASS, END rows PASS, registry identical
- [X] T012 [P] Regression probes: specs/288-ftp-per-server-encoding/probe/ftp288_probe.ps1 and specs/224-ftp-utf8-server-names/probe/ftp224_probe.ps1 (`probe/regress_288.txt`, `probe/regress_224.txt`) - no new FAIL
- [X] T013 Update specs/303-ftp-upload-case-only/fix-log.md with after-measurements and the commands

## Dependencies

T001 -> T002 -> T003 -> T004 -> T005 -> T006 -> T007 / T009 -> T008 -> T010 -> T011, T012 -> T013.
US1 is the MVP (the data loss); US2 is verified by the same build; US3 depends on T006.

## Parallel opportunities

T012's two regression probes are independent of T011's result but must not run at the same time
(one program instance per probe); T008 (reading) can run beside T007.

## Implementation strategy

MVP = Phase 2 + Phase 3 (the question appears); then US3's two call sites; one build, one probe run.
