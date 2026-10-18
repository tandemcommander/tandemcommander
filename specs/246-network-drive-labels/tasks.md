# Tasks: Network drive names and disconnected-drive icons

**Input**: Design documents from `specs/246-network-drive-labels/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: requested by the maintainer ("test everything in great detail, with independent
test agents") — `saltests` checks for the pure rules, a GUI probe with a negative control
on the baseline build, and independent test/review agents.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [X] T001 Build the baseline (Debug x64, `build.cmd`) at the feature's base commit and keep a copy of `tandemcommander.exe` + `saltests.exe` as the negative control in `%TEMP%\tc246\baseline\` (record the commit and the build in `specs/246-network-drive-labels/fix-log.md`)
- [X] T002 Write the GUI probe skeleton `specs/246-network-drive-labels/probe/run246.ps1` (+ helper `probe246.cpp` if needed): registry backup/restore of `HKCU\Software\Tandem Commander`, snapshot of `net use` / `HKCU\Network` / `MountPoints2 ##*` before, free-letter selection (W:, V:, U:, T:), fixture under `%TEMP%\tc246\fx\`, cleanup with verification against the snapshot

## Phase 2: Foundational (blocking)

- [X] T003 Create `src/common/salnetdrive.h` per `contracts/salnetdrive.md`: `SalNetDriveNameKey`, `SalNetDriveCleanName`, `SalNetDriveText`, `SalNetDriveIsDisconnected`, constants `SALNETDRV_ERROR_CONNECTION_UNAVAIL` / `SALNETDRV_WNGC_DISCONNECTED` (UTF-8-BOM, SPDX header, English comments)
- [X] T004 Add `TestNetDrive246()` to `src/saltests/saltests.cpp` (include + call in `main`): key building (plain, trailing `\`, `#`, non-ASCII, spaces, device prefixes, no share, empty component, exact-fit / one-short buffer), cleaning (tabs, CR/LF, DEL, only spaces, NULL), text (no name, name, name equal to path in other case, `&` doubled / not, NULL remote, size query and exact/short buffers, never cut), state truth table (all combinations)
- [X] T005 Measure on the baseline build with the probe (T002) — negative control: named drive shows the path only; after cancelling a remembered connection (without profile update) the drive bar icon stays connected after activation, Alt+F1 open/close and Ctrl+R; record in `fix-log.md` and `probe/results-baseline.md`

## Phase 3: User Story 1 — Recognise a named network drive (P1) 🎯 MVP

**Goal**: menu and tooltip show `Name (path)` for named drives; unnamed unchanged.
**Independent test**: map, name via `_LabelFromReg`, open the menu / hover the bar.

- [X] T006 [US1] In `src/drivelst.cpp` add static helpers: `GetNetDriveRemoteW(char letter, WCHAR* stackBuf, DWORD stackLen, WCHAR** heapBuf, DWORD* connResult)` (WNetGetConnectionW, `ERROR_MORE_DATA` retry on the heap) and `ReadNetDriveNameW(const WCHAR* remote, WCHAR** name)` (key via `SalNetDriveNameKey` on a heap buffer, `RegOpenKeyExW` + `RegQueryValueExW` `_LabelFromReg`, REG_SZ / REG_EXPAND_SZ literal, terminator ensured, `SalNetDriveCleanName`)
- [X] T007 [US1] In `src/drivelst.cpp` add `char* BuildNetDriveTextU8(char letter, BOOL doubleAmpersands, DWORD* connResult)` returning a malloc'd UTF-8 text via `SalNetDriveText` + `SalWToU8Alloc`, or NULL when no remote path is obtainable
- [X] T008 [US1] In `CDrivesList::BuildData` (`src/drivelst.cpp`, `case drvtRemote`) build `drv.DriveText = "X\t" + BuildNetDriveTextU8(..., TRUE)` directly on the heap (no `volumeName` buffer, no `DuplicateAmpersands` cut); keep today's path as the fallback when it returns NULL
- [X] T009 [US1] In `CDrivesList::GetDriveBarToolTip` (`src/drivelst.cpp`, `case drvtRemote`) compute the text fresh with `BuildNetDriveTextU8(..., FALSE)` and copy with `CopyToolTipAnswer`; fall back to the stored text
- [X] T010 [US1] Probe rows for US1 in `probe/run246.ps1`: unnamed / ASCII / `Archiv Test ž` / Cyrillic / CJK / `&` / `#` / long path / name equal to path / blank name / tab in name / renamed while running (menu reopened, tooltip re-shown)

## Phase 4: User Story 2 — See that a network drive is disconnected (P1)

**Goal**: icon follows Windows' connection state; bars catch up on activation.
**Independent test**: remembered mapping connected ↔ unavailable; activate; check icons.

- [X] T011 [US2] In `src/drivelst.cpp` add `BOOL IsNetDriveDisconnected(char letter, BOOL listed, DWORD connResult)` (WNetGetConnection3W `WNGC_INFOLEVEL_DISCONNECTED` only when listed and `connResult == NO_ERROR`; decision by `SalNetDriveIsDisconnected`; `static_assert`s tying the header constants to `winnetwk.h`) and `DWORD GetNetDisconnectedMask(DWORD logicalMask, DWORD netDrives)` (all letters; listed ones only when `GetDriveType == DRIVE_REMOTE`); declare the latter in `src/salamand.h`
- [X] T012 [US2] In `CDrivesList::BuildData` (`src/drivelst.cpp`): compute `CachedNetDisconnectedMask` at the top of the system branch; for `drvtRemote` set `drv.Accessible = !(CachedNetDisconnectedMask & bit)`; in the copy branch take `copyCachedNetDisconnectedMask`; add the member, accessor `GetCachedNetDisconnectedMask()`, constructor init and the new `BuildData` parameter in `src/drivelst.h`
- [X] T013 [US2] Quiet network enumeration: add `BOOL showErrors = TRUE` to `GetNetworkDrives` / `GetNetworkDrivesBody` (`src/drivelst.cpp`, `src/salamand.h`)
- [X] T014 [US2] `CMainWindow::RebuildDriveBarsIfNeeded` (`src/mainwnd3.cpp`, `src/mainwnd.h`): new parameter `DWORD netDisconnectedMask` (+ `BOOL quiet`), compared against each bar's `GetCachedNetDisconnectedMask()`; computed fresh when `!useDrivesMask`; update the callers (`src/drivelst.cpp` Track ×2, `src/mainwnd3.cpp` refresh ×3)
- [X] T015 [US2] `CDriveBar` (`src/toolbar6.cpp`, `src/toolbar.h`): `GetCachedNetDisconnectedMask()`; `CreateDriveButtons` passes the copied mask to `BuildData`
- [X] T016 [US2] Activation check in `WM_USER_END_SUSPMODE` (`src/mainwnd3.cpp`, next to the OneDrive re-check): `RebuildDriveBarsIfNeeded(FALSE, 0, 0, FALSE, 0, TRUE /*quiet*/)`
- [X] T017 [US2] Probe rows for US2: connected → cancel without profile update (unavailable) → activation → bar icon 31 and menu icon 31; reconnect (`WNetRestoreSingleConnectionW` / `net use`) → activation → 33; both bars; no rebuild when nothing changed (bar window not re-created / item count stable); no message box

## Phase 5: User Story 3 — Reconnect reliably (P2)

**Goal**: reconnection uses Windows' remote path, never the displayed text.
**Independent test**: remembered unavailable mapping to a path with `&` → pick → panel lists it.

- [X] T018 [US3] `CDrivesList::ExecuteItem` (`src/drivelst.cpp`): for `!item->Accessible` — letter listed by `GetLogicalDrives()` → no `RestoreNetworkConnection`; else fresh `GetNetworkDrives(netDrives, netRemotePath)` and, if the letter is remembered, `RestoreNetworkConnection(hwnd, "X:", netRemotePath[letter])`; no entry → no reconnect attempt
- [X] T019 [US3] Probe rows for US3: named unavailable drive picked from the menu reconnects to its path; `&` path reconnects; listed-but-disconnected path (if producible) opens without an error box

## Phase 6: Polish & cross-cutting

- [X] T020 `build.cmd` (Debug) and `saltests`; `python tools/check_encoding.py` strict `TOTAL: 0`; clang-format on the touched files
- [X] T021 Run the full probe on the new build (all rows) and on the baseline (negative control); results in `probe/results.md`; verify cleanup
- [ ] T022 Performance: time the Change Drive menu build with four network drives (connected, unavailable, unreachable remembered `\\192.0.2.1\x`, named) on baseline vs new (SC-004); record
- [ ] T023 Independent test agent(s): black-box test of the build against `spec.md` / contracts with their own fixtures (no access to the implementer's reasoning); findings to `fix-log.md`
- [ ] T024 Independent refute-first code review agent(s) of the diff; fix confirmed findings; re-test; second round if anything changed
- [ ] T025 `build.cmd full` (language modules) to confirm no UI string changed; Release build sanity if time permits
- [ ] T026 Documentation: `CHANGELOG.md` entry under the unreleased heading; `specs/FEATURE-HISTORY.md` entry `246-`; PRIVACY.md checked (no change expected — record why); backlog: note in `drive-list-code-page-texts` what 246 converted; person steps (real SMB server off/on; real keyboard) recorded; `closing-report.md`
- [ ] T027 Commit on the branch (no push)

## Dependencies

- T001–T002 → T005 (baseline measurement) ; T003 → T004, T006–T019
- US1 (T006–T010) and US2 (T011–T017) touch the same function `BuildData` → sequential in one file; US3 (T018) after US2 (uses the new `Accessible`)
- Polish after all stories

## Parallel opportunities

- T003/T004 (header + tests) in parallel with T002 (probe skeleton)
- T023 and T024 (independent agents) in parallel

## Implementation strategy

MVP = US1 (names). US2 is equally P1 and lands in the same change; US3 protects US1's
change of the text from breaking reconnection and fixes the `&` defect.
