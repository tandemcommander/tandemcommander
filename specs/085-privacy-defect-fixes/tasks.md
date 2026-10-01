# Tasks: Privacy defect fixes (085)

**Input**: `spec.md`, `plan.md`, `research.md`, `contracts/history-password-strip.md`
**Protocol**: `specs/069-finish-encoding-fixes/contracts/fix-protocol.md` — each
group starts with "still defective at HEAD?" (done for all in research.md, at
`7f50632`), ends with a build, the group's evidence and an independent review
by an agent that did not write the change; one commit per group.

## Phase 1 — F1: passwords in typed addresses (US1, P1)

- [x] T001 [US1] Create `src/common/salurlpwd.h` / `salurlpwd.cpp` (C1–C3 of the contract)
- [x] T002 [US1] Add both files to `src/vcxproj/salamand.vcxproj` (+ `.filters` if present) and `src/vcxproj/saltests/saltests.vcxproj`
- [x] T003 [US1] `TestUrlPasswordStrip085` in `src/saltests/saltests.cpp`: ≥ 40 cases (every spec edge case, C5 invariants: no growth, no-`@` identity, idempotence, UTF-8), C3 dedupe/compaction; run — 0 failed
- [x] T004 [US1] Core add sites: `CChangeDirDlg::Transfer`, `CCopyMoveDialog::Transfer`, `CCopyMoveMoreDialog::Transfer` (`src/dialogs3.cpp`), `CFindDialog::Transfer` Look-in (`src/finddlg1.cpp`), command line (`src/editwnd.cpp`)
- [x] T005 [US1] Plugin service: `CSalamanderGeneral::AddValueToStdHistoryValues` (`src/zip.cpp`) — clean when the array is `CopyHistory` or `ChangeDirHistory`
- [x] T006 [US1] Load: after `LoadHistory` of the four arrays in `CMainWindow::LoadConfig` (`src/mainwnd2.cpp`)
- [x] T007 [US1] FTP: add `salurlpwd.cpp` to `src/plugins/ftp/vcxproj/ftp.vcxproj`; Quick Connect writes back the stripped Address (`src/plugins/ftp/dialogs1.cpp`); clean `HostAddressHistory` after load (`src/plugins/ftp/ftp.cpp`)
- [x] T008 [US1] Debug build (core + ftp), `saltests`; independent review; commit `[085] F1 …`

## Phase 2 — F3: navigation without a click (US2)

- [x] T009 [US2] `src/common/webhost/webhost.cpp`: `NavigationStarting` and `NewWindowRequested` forward to `OnActivateLink` only when `IsUserInitiated` (failure = FALSE)
- [x] T010 [US2] Hostile fixture `probe/autonav.md` (meta refresh external, relative `.md`, local file; one ordinary link) for the owed GUI check
- [x] T011 [US2] Debug build (mdview + codeview); independent review; commit `[085] F3 …`

## Phase 3 — F2: remote image requests (US3)

- [x] T012 [US3] Move `FetchRemote` verbatim to `src/plugins/mdview/remotefetch.{h,cpp}` (`MdFetchRemote`), add to `mdview.vcxproj`; webglue calls it
- [x] T013 [US3] In the moved function: user agent `TandemCommander-mdview`; cookies + automatic authentication disabled on the request; status 200–299 required before the body is read; comment corrected
- [x] T014 [US3] Probe `probe/fetch_probe.cmd` + `probe/fetch_server.py` + `probe/fetch_main.cpp`: builds the moved file alone, runs against a local logging server (UA, Set-Cookie then no Cookie, 404 → fail, 200 → bytes); green
- [x] T015 [US3] Debug build (mdview); independent review; commit `[085] F2 …`

## Phase 4 — F7 and F6 (US4, US5)

- [x] T016 [US4] `src/plugins/sftp/dialogs.cpp` `ConnectReadFields`: a failed Master Password prompt → no blob, `Save…` off, checkbox unchecked (password and passphrase)
- [x] T017 [US4] Debug build (sftp); independent review; commit `[085] F7 …`
- [x] T018 [US5] `src/pwdmngr.cpp` `FillBufferWithRandomData` → `BCryptGenRandom` (system-preferred RNG), traced fallback; `#pragma comment(lib, "bcrypt.lib")`
- [x] T019 [US5] Debug build; check `dumpbin /imports` shows `bcrypt.dll`; independent review; commit `[085] F6 …`

## Phase 5 — F4/F5: viewer engine crash upload (US6)

- [x] T020 [US6] `src/common/webhost/webenvopts.h` (internal); `TcWebBuildEnvOptions()` non-static, sets `IsCustomCrashReportingEnabled = TRUE`; `webkeeper.cpp` uses it, its own builder deleted
- [x] T021 [US6] `architecture/11-webview2-integration.md`: the options rule (one builder, crash reporting) + corrected description of the user data folder (F5)
- [x] T022 [US6] Debug build (mdview + codeview); guard `rg -c put_IsCustomCrashReportingEnabled src/` (outside `dep/`) == 1; independent review; commit `[085] F4 …`

## Phase 6 — Records and gates

- [x] T023 `PRIVACY.md`: history limitation gone, SFTP cancel limitation gone, identification `TandemCommander-mdview`, no cookies, documents cannot open links by themselves, viewer engine crash dumps kept locally; validity line
- [x] T024 `CHANGELOG.md` *Unreleased*: Fixed/Changed entries in the user's terms, limitations stated
- [x] T025 `specs/NEXT-WORK.md` item 7 (F1–F7 done, F9 + F8 question remain); `CLAUDE.md` *Recent Changes* entry
- [x] T026 `fix-log.md` (per group: HEAD check, change, evidence, review verdict) and `quickstart.md` (owed GUI steps)
- [x] T027 Full gates: `build.cmd` Debug, `build.cmd full release`, `saltests`, `python tools/check_encoding.py`; plugin interface still 106 (`git diff --stat src/plugins/shared/` empty)
- [x] T028 Final independent review of the public claims (PRIVACY.md, CHANGELOG.md) against the code; commit records

## Dependencies

Phase 1 first (P1). Phases 2–5 are independent of each other and of Phase 1
except for shared build gates. Phase 6 last.
