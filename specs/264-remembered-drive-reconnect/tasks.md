# Tasks: Remembered network drive reconnects to its exact path

**Input**: Design documents from `specs/264-remembered-drive-reconnect/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/reconnect.md, quickstart.md

**Tests**: the project's rules ask for saltests checks of a pure rule and a hidden-desktop
probe with a negative control; both are included.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [ ] T001 Keep the baseline copy of the HEAD0 build tree in `%TEMP%\tc264base\tree` (made before any source change; hash recorded) and note it in specs/264-remembered-drive-reconnect/fix-log.md

## Phase 2: Foundational (blocking)

- [ ] T002 [P] Add `SalNetDriveSameRemote` to src/common/salnetdrive.h per contracts/reconnect.md (ordinal case-insensitive via `CompareStringOrdinal`, one trailing backslash ignored, NULL -> FALSE)
- [ ] T003 [P] Add saltests checks for `SalNetDriveSameRemote` in src/saltests/saltests.cpp (equal, case, trailing backslash each side, Cyrillic case, prefix only, different tail, NULL, empty)
- [ ] T004 Add `GetRememberedNetDriveRemoteW(char letter)` (wide enumeration of remembered disk connections, heap buffer grown on `ERROR_MORE_DATA`, malloc'd exact copy or NULL) in src/drivelst.cpp
- [ ] T005 Add `GetRememberedNetDriveLogonW(letter, remote, &user, &provider)` (HKCU\Network\<letter> RemotePath / UserName / ProviderName read whole with `RegQueryValueExW`, REG_SZ only, used when `SalNetDriveSameRemote`) in src/drivelst.cpp
- [ ] T006 Refactor the thread machinery of `NonBlockingWNetAddConnection3` so that a wide twin `NonBlockingWNetAddConnection3W` shares the thread object, the re-entrance lock and the wait for a previous attempt; heap-owned wide strings released only after the thread ended; the ANSI function's behaviour unchanged, in src/drivelst.cpp
- [ ] T007 Add `RestoreNetworkDriveW(HWND parent, char drive, const WCHAR* remote)` (the Windows 7+ mapped-letter flow of `RestoreNetworkConnection`, wide, per contracts/reconnect.md) in src/drivelst.cpp and declare it next to `RestoreNetworkConnection` in src/consts.h

## Phase 3: User Story 1 - pick a remembered drive with a non-code-page path (P1) - MVP

**Goal**: the drive menu / drive bar pick reconnects to the exact path.
**Independent test**: probe rows Q1, Q2 (fixed PASS, baseline FAIL), A1 (both PASS).

- [ ] T008 [US1] `CDrivesList::ExecuteItem`: take the remote path from `GetRememberedNetDriveRemoteW`, print the seam `RESTORE <L> <exact UTF-8 path>` (heap `SalWToU8Alloc`), call `RestoreNetworkDriveW`; keep `NORESTORE` seam lines and the listed-letter rule, in src/drivelst.cpp
- [ ] T009 [US1] Write the probe specs/264-remembered-drive-reconnect/probe/run264.ps1 (style of specs/246-network-drive-labels/test-independent/itest246_pickcp.ps1 and specs/241-pack-long-nested-folder/probe/pack241_probe.ps1: Backup-Reg / Restore-Reg, fixture under %TEMP%, mapping snapshot and cleanup verified; rows Q1, Q2, A1, U1; fixed build and `-Baseline`)

## Phase 4: User Story 2 - long remembered path (P1)

**Goal**: a 259-character remembered path with a Cyrillic tail reconnects whole.
**Independent test**: probe row L1 (fixed PASS, baseline FAIL).

- [ ] T010 [US2] Add row L1 (remote path of exactly 259 characters ending in Cyrillic) to specs/264-remembered-drive-reconnect/probe/run264.ps1

## Phase 5: User Story 3 - panel path change to a disconnected remembered drive (P2)

**Goal**: the panel's reconnection uses the exact path.
**Independent test**: probe row P1 (program started with the left panel on `<L>:\` of a disconnected remembered drive).

- [ ] T011 [US3] `CheckAndRestoreNetworkConnection`: mask from `GetNetworkDrives(.., NULL)`, remote from `GetRememberedNetDriveRemoteW`; listed -> `SalCheckPath` on the UTF-8 form; not listed -> `RestoreNetworkDriveW`; no remote -> FALSE with `pathInvalid` FALSE, in src/drivelst.cpp
- [ ] T012 [US3] Add row P1 to specs/264-remembered-drive-reconnect/probe/run264.ps1

## Phase 6: User Story 4 - credentials and cancelling keep working (P3)

**Goal**: saved user name, credential dialog and Esc wait window unchanged.
**Independent test**: code review against the old flow; person step (no keyboard / password-protected share on the hidden desktop).

- [ ] T013 [US4] Compare `RestoreNetworkDriveW` branch by branch with the Windows 7+ path of `RestoreNetworkConnection` (`name != NULL`) and record the mapping in specs/264-remembered-drive-reconnect/fix-log.md; record the credential dialog / Esc rows and the "listed but not answering" recovery of US3 scenario 2 (not producible here) as NOT DRIVEN, verified by reading

## Phase 7: Polish & verification

- [ ] T014 `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`
- [ ] T015 `build.cmd` -> `BUILD SUCCEEDED`; `saltests.exe` -> `0 failed`
- [ ] T016 Run run264.ps1 on the hidden desktop (fixed + baseline); every row as quickstart.md expects; results in specs/264-remembered-drive-reconnect/probe/result_after.txt
- [ ] T017 Repeat the step-3 measurement (`itest246_pickcp.ps1` on the fixed build): `reconnected exactly: True` for PK-Q1 / PK-Q2; record before / after in specs/264-remembered-drive-reconnect/fix-log.md

## Dependencies

- T002 -> T005; T004, T005, T006 -> T007 -> T008, T011.
- T009 needs T008 built; T010, T012 extend T009.
- T014-T017 after all source tasks.

## Parallel opportunities

- T002 and T003 (different files); T004 and T006 (different functions, same file - sequential edits advised).

## Implementation strategy

MVP = Phase 2 + US1 (the item's reproduction). US2 comes free with the wide heap path (only
a probe row); US3 is the second entry point; US4 is a regression guard.
