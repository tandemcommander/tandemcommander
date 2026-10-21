# Tasks: FTP - names go to each server in that server's own encoding

**Input**: design documents in `specs/288-ftp-per-server-encoding/` (plan.md, spec.md, research.md,
data-model.md, contracts/server-encoding-rule.md, quickstart.md)
**Tests**: saltests checks of the pure rule (stop-rules §2.5) and the hidden-desktop probe
`probe/ftp288_probe.ps1` (already written and measured before - `probe/result_before.txt`, 8 / 4).

## Phase 1: Setup

- [X] T001 Record the measurement before, the consumers and the decisions in specs/288-ftp-per-server-encoding/fix-log.md (done with the plan; check it is complete)

## Phase 2: Foundational (blocks every story)

- [X] T002 [P] Write the pure rule `SalFtpServerEncState`, `SalFtpNameGoesInCodePage`, `SalFtpSameServerUser`, `SalFtpSameServerHost`, `SalFtpSameServer` (contracts/server-encoding-rule.md) in src/common/salftpsrvenc.h (UTF-8 BOM, SPDX header like salftplisting.h)
- [X] T003 [P] Add `TestFtpServerEncoding288` (every state, the decision table of data-model.md, anonymous / empty / NULL users, host ASCII case, bytes >= 0x80 not folded, NULL hosts, port) and its call in src/saltests/saltests.cpp
- [X] T004 Replace 224's process-wide set by the per-server registry in src/plugins/ftp/ftputils.cpp: `CFTPServerEnc` (host, port, user, SawUtf8, SawCodePage; at most 1,000), `FTPGetServerEnc`, code-page names tagged with their server (bound 200,000 kept), `FTPFreeServerEncodings` (ftp.cpp calls it instead of `FTPFreeCodePageNames`)
- [X] T005 Add `CFTPListingServerScope` (thread-local server of the listing being parsed, nests) and make `FTPListingFieldToU8` record evidence for that server only (UTF-8 evidence for a valid non-ASCII field, code-page evidence + the name for a field read in the code page; no server = no evidence) in src/plugins/ftp/ftputils.cpp and src/plugins/ftp/ftputils.h
- [X] T006 `FTPGetDirectoryFromReply(.., CFTPServerEnc* srv)` and its in-place decode: a path read in the code page gives code-page evidence for `srv`, a valid UTF-8 path none, in src/plugins/ftp/ftputils.cpp / ftputils.h
- [X] T007 `FTPU8NameToServer(u8, buf, bufSize, srv)`: ASCII unchanged; code page when `SalFtpNameGoesInCodePage(state of srv, the name or a component / leading part is a code-page name of srv)` and the code page holds it; else UTF-8, in src/plugins/ftp/ftputils.cpp / ftputils.h
- [X] T008 `PrepareFTPCommand(CFTPServerEnc* srv, ...)` passes `srv` to every `FTPU8NameToServer` in src/plugins/ftp/ctrlcon2.cpp and its declaration in src/plugins/ftp/ctrlcon.h
- [X] T009 `CControlConnectionSocket::GetServerEnc()` (Host / Port / User copied under SocketCritSect) in src/plugins/ftp/ctrlcon.h and a ctrlcon*.cpp; `CFTPOperation::GetServerEnc()` (under OperCritSect) in src/plugins/ftp/operats.h and src/plugins/ftp/operats2.cpp

## Phase 3: User Story 1 - new names reach a legacy server in its code page (P1)

**Independent test**: probe rows LEG-MKD, LEG-REN, LEG-UP PASS.

- [X] T010 [US1] The panel's listing parse sets the scope (`FTPGetServerEnc(Host, Port, User)`) around the `GetNextItemFromListing` loop in src/plugins/ftp/fs2.cpp `CPluginFSInterface::ParseListing`
- [X] T011 [US1] The panel connection's callers pass `GetServerEnc()` (NULL for commands without a name) in src/plugins/ftp/ctrlcon1.cpp, ctrlcon2.cpp, ctrlcon3.cpp, ctrlcon4.cpp, ctrlcon5.cpp - also `FTPGetDirectoryFromReply` in ctrlcon3.cpp and ctrlcon5.cpp
- [X] T012 [US1] The workers' callers pass `Oper->GetServerEnc()` in src/plugins/ftp/operats4.cpp, operats6.cpp, operats7.cpp, operats8.cpp, operatsa.cpp, operatsb.cpp - also `FTPGetDirectoryFromReply` in operats7.cpp and operatsa.cpp; the worker's listing parse sets the scope in operats6.cpp `CFTPWorker::ParseListingToFTPQueue`
- [X] T013 [US1] The upload listing cache sets the scope (`FTPGetServerEnc(Host, Port, User)` of `CUploadListingsOnServer`) around its three `CUploadPathListing::ParseListing` calls in src/plugins/ftp/operats9.cpp

## Phase 4: User Story 2 - one server does not decide another (P1)

**Independent test**: probe row CROSS-DEL PASS.

- [X] T014 [US2] Check by reading that no site looks names up across servers (no remaining caller of a server-less lookup; `FTPHasCodePageName` takes the server) in src/plugins/ftp/ftputils.cpp; record in fix-log.md

## Phase 5: User Story 3 - everything that worked keeps working (P2)

**Independent test**: probe rows UTF-MKD, UNK-MKD PASS; 224 16 / 0; 269, 277 as recorded.

- [X] T015 [US3] Confirm the server-type test dialog (src/plugins/ftp/dialogs4.cpp) parses with no scope (no evidence, decoding unchanged) and that the comments of 224 / 269 / 277 sites still describe the code (ftputils.cpp, ctrlcon3.cpp, parser2.cpp)

## Phase 6: Polish and verification

- [X] T016 `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s); clang-format (the repository's .clang-format) of the changed sources src/common/salftpsrvenc.h, src/saltests/saltests.cpp (the new test), src/plugins/ftp/*.cpp / *.h touched - only the changed lines
- [X] T017 `build.cmd` -> BUILD SUCCEEDED; saltests -> 0 failed (record the count) in fix-log.md
- [X] T018 Probe after: specs/288-ftp-per-server-encoding/probe/result_after.txt -> all PASS
- [X] T019 Regression probes 224, 269, 277 -> specs/288-ftp-per-server-encoding/probe/regress_224.txt, regress_269.txt, regress_277.txt as recorded
- [X] T020 Negative control: the saltests rule with a broken decision (temporarily) fails; record in fix-log.md and restore
- [X] T021 Record the work, results and limits in specs/288-ftp-per-server-encoding/fix-log.md; FR-006: the probe's server logs show no command the plug-in did not send before (no FEAT / OPTS), and the diff adds no registry or file write
- [X] T022 CHANGELOG.md: an entry at the top of the `— unreleased` section (symptom, feature 288, what it does now, the limits: unknown servers get UTF-8, no FEAT), or into closing-report.md when no such section exists

## Dependencies

T002 -> T003; T004 -> T005, T006, T007 -> T008 -> T009 -> T010..T013 (one build: all signatures
change together) -> T014, T015 -> T016..T022. US1 and US2 are delivered by the same change
(per-server registry + plumbing); US2 needs no code of its own beyond T004/T007.

## Parallel opportunities

T002 and T003 alongside T004; the caller edits T011, T012, T013 touch different files.

## Implementation strategy

One increment: the rule + registry + plumbing (Phases 2-3) make the whole probe pass; Phases 4-5
are checks; Phase 6 verifies.
