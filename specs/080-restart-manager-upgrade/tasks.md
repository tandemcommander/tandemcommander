# Tasks: Upgrading Over a Running Instance (Restart Manager)

**Input**: Design documents from `/specs/080-restart-manager-upgrade/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: requested by the feature description (*"vše … otestuj"*): unit tests
for the pure module in `saltests`, and probe-driven validation per
`quickstart.md` V1–V16. Probes already exist under `probe/` (written for the
baseline); tasks below run them, they do not write them again.

**Organization**: by user story of `spec.md`. **One commit per concern**
(constitution III): pure module + tests · request handling · restart
registration · installer step · records. Version stays **0.1.8 / build 192**
(FR-016); plug-in interface stays 106 (FR-014).

**Rules for every code task** — `specs/069-finish-encoding-fixes/contracts/fix-protocol.md`
in spirit: read the site at HEAD before changing it; enumerate the consumers
yourself; UTF-8-BOM, CRLF as found, new comments in English; never touch
`src/plugins/shared/`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: can run in parallel (different files, no dependency on an open task)
- **[Story]**: US1…US5 from spec.md

---

## Phase 1: Setup (machine safety, probes, baseline)

**Purpose**: make every later test harmless for the maintainer's machine, and
measure the starting point. Done during `/speckit-plan`; listed for the record.

- [X] T001 Export `HKCU\Software\Tandem Commander` to the scratchpad and to `temp\tc-config-backup-080.reg`, record its hash and the hashes of `setup\output\*.exe`, confirm no instance is running and the shell is not elevated (fix-log, *baseline*)
- [X] T002 [P] Write `specs/080-restart-manager-upgrade/probe/rm_probe.ps1` (the installer's Restart Manager sequence; refuses to touch a process from outside the registered location)
- [X] T003 [P] Write `specs/080-restart-manager-upgrade/probe/wnd_probe.ps1`, `probe/upgrade_probe.ps1`, `probe/tc_drive.ps1`, `probe/rm_protocol_dummy.ps1`
- [X] T004 Baseline B0–B6, protocol P1–P6, busy states S1–S3 recorded in `specs/080-restart-manager-upgrade/fix-log.md` and `research.md` (FR-001, FR-002)

---

## Phase 2: Foundational (blocking prerequisites)

**Purpose**: the pure decision module and the state every story reads.
**⚠️ No user-story work before this phase is complete.**

- [X] T005 Create `src/common/salcloseapp.h` + `src/common/salcloseapp.cpp` per `data-model.md`: `SalIsCloseAppRequest(lParam, sessionShuttingDown)`, `CSalCloseAppWindow` / `CSalCloseAppSnapshot`, `SalCloseAppWindowIsForeign`, `SalCloseAppDecide` (first match D1…D8), `SalCloseAppDecisionName`, `SalRestartCommandLine` (quoting rule of `GetCmdLine`, never over `RESTART_MAX_CMD_LINE`); no core header included; UTF-8-BOM
- [X] T006 Add `TestCloseApp()` to `src/saltests/saltests.cpp` and call it from `main`: classification of all lParam combinations (close-app, critical, log-off, shutting down), every decision reason alone, the order of reasons when several apply, the window filter (visible/hidden, main/viewer/Find/help/other, captionless tool window vs captionless full-screen window), the restart command line (empty, plain prefix, prefix with spaces, prefix with quotes, icon only, both, over-long prefix dropped, tiny buffer)
- [X] T007 Register the new files: `src/vcxproj/salamand.vcxproj`, `src/vcxproj/saltests/saltests.vcxproj`, `#include "salcloseapp.h"` in `src/precomp.h` (pattern: commit `ad30cad`, `salbugreport`)
- [X] T008 Declare the global `UnattendedClose` (`src/consts.h`, defined in `src/salamdr1.cpp` next to `CriticalShutdown`) with a comment stating it is the opposite policy of `CriticalShutdown` and is never exposed to plug-ins
- [X] T009 Add `CMainWindow::CollectCloseAppSnapshot(CSalCloseAppSnapshot&)` in `src/mainwnd.h` / `src/mainwnd3.cpp` (read-only: `CanClose`, `CanCloseButInEndSuspendMode`, `CannotCloseSalMainWnd`, `SalamanderBusy`, `IsWindowEnabled(HWindow)`, `AlreadyInPlugin`, `ProgressDlgArray.RemoveFinishedDlgs()`, Find windows searching under `WindowsManager.CS`, `AssocUsed` of both panels, `Is(ptPluginFS)` of both panels, `DetachedFSList->Count`, top-level windows of the process classified by class name / `FindDialogQueue`) and the request-state members of `data-model.md` §4
- [X] T010 Build Debug, run `saltests.exe` — `TestCloseApp` passes, total ≥ 1427 + new checks; **commit 1**: *pure module + tests*

**Checkpoint**: decision logic exists and is proven without a GUI.

---

## Phase 3: User Story 1 — an unattended update succeeds while the program is open (P1) 🎯 MVP

**Goal**: an agreed request closes the program at the instruction stage, completely and without prompts (contract `close-request.md` C1–C4, C7).

**Independent Test**: quickstart V1 (without `-Restart`), V5, V7, then V11 with the real installer.

- [X] T011 [US1] In `src/mainwnd3.cpp`, `WM_QUERYENDSESSION`: when `SalIsCloseAppRequest(lParam, GetSystemMetrics(SM_SHUTTINGDOWN))` and not `CloseAppExecuting` → question stage: collect, decide, set `CloseAppAgreed`, `TRACE_I` decision + reason, `return` TRUE/FALSE — before any existing statement of the shared block (no `SaveCfgInEndSession`/`WaitInEndSession`/`SalamanderBusy` changes; contract C2)
- [X] T012 [US1] In `src/mainwnd3.cpp`, `WM_ENDSESSION`: first thing, for an installer's request — wParam 0 → clear `CloseAppAgreed`, `return 0`; wParam 1 and agreed → clear it, arm the `WM_CLOSE` swallow, decide again (decline → trace, `return 0`), set `UnattendedClose` + `CloseAppExecuting`, re-dispatch `WindowProc(WM_QUERYENDSESSION, 0, lParam)`, clear both flags **without touching members after the window may be destroyed** (globals / locals only), `return 0`; the `IDS_FORCEDSHUTDOWN` branch must be unreachable for this request (contract C3)
- [X] T013 [US1] In `src/mainwnd3.cpp`, `WM_CLOSE`: ignore the first `WM_CLOSE` within 35 s of the start of an execute stage, once (contract C5, protocol fact P2)
- [X] T014 [US1] Execute stage inside the shared block of `src/mainwnd3.cpp`: confirm by reading that with `uMsg == WM_QUERYENDSESSION`, non-critical lParam, the sequence runs to `DestroyWindow` and returns TRUE; correct the comment *"all Windows versions kill the process…"* to say what happens for an installer's request
- [X] T015 [US1] Build Release; run quickstart **V1** (idle), **V5** (internal viewer + idle Find close silently), **V7** (confirm-on-exit not shown) with `probe/rm_probe.ps1`; record times in `fix-log.md` (SC-002: ≤ 10 s)

**Checkpoint**: the idle close works through the two stages.

---

## Phase 4: User Story 2 — closing for an update loses nothing (P1)

**Goal**: every state that would need a question declines promptly and leaves nothing behind; no prompt can appear during an unattended close (contract C5, C6, C8).

**Independent Test**: quickstart V2, V3, V4, V6, V8, V9.

- [X] T016 [US2] `src/mainwnd3.cpp` shared block, `UnattendedClose` guards: `LockedUIReason` message box not shown; `CExitingOpenSal` not executed → refuse; Find close query sent *quiet*; `IDS_SHELLEXTBREAK3` → as *Continue* (refuse) without the message box
- [X] T017 [P] [US2] `src/plugins1.cpp` `CPluginData::Unload`: `IDS_PLUGINFORCEUNLOAD` → as *No* under `UnattendedClose` (also `IDS_PLUGINSAVEFAILED` if `ask`) 
- [X] T018 [P] [US2] `src/fileswn2.cpp` `CFilesWindow::PrepareCloseCurrentPath`: under `UnattendedClose` return FALSE before `IDS_ARCHIVECLOSEEDIT` / `CheckAndPackAndClear` when `AssocUsed`; `IDS_ARCHIVEFORCECLOSE` (both sites) and `IDS_FSFORCECLOSE` → as *No*
- [X] T019 [P] [US2] `src/mainwnd4.cpp` `CMainWindow::CloseDetachedFS`: `IDS_FSFORCECLOSE` → as *No* under `UnattendedClose`
- [X] T020 [US2] Sweep the exit path once more for any other `SalMessageBox*` / `Execute()` reachable between the top of the shared block and `DestroyWindow` (grep the callees: `Plugins.UnloadAll`, `CanUnloadPlugin`, `SalShExtPastedData.CanUnloadPlugin`, `PrepareCloseCurrentPath`, `CloseCurrentPath`, `SaveConfig`, `DiskCache.PrepareForShutdown`); guard or document each in `fix-log.md`
- [X] T021 [US2] Build Release; run quickstart **V2** (modal), **V3** (file operation — incl. *the program keeps running after the copy ends*), **V4** (Code Viewer open), **V6** (Find searching), **V9** (two instances); each: 351 within 5 s, nothing new on screen (`tc_drive -Action dialogs` before/after), no later exit; record in `fix-log.md` (SC-004, SC-005, SC-010)
- [X] T022 [US2] Quickstart **V8**: configuration equivalence — same state closed by hand and through `rm_probe`, export `HKCU\Software\Tandem Commander\0.1` both times, diff, list and justify every differing value in `fix-log.md` (SC-006); repeat with *Save configuration on exit* off (stored configuration untouched)
- [X] T023 [US2] **Commit 2**: *request handling* — `mainwnd3.cpp`, `mainwnd.h`, `mainwnd4.cpp`, `fileswn2.cpp`, `plugins1.cpp`, `consts.h`, `salamdr1.cpp`

**Checkpoint**: US1 + US2 together are the safe close.

---

## Phase 5: User Story 3 — the program comes back after the update (P2)

**Goal**: `RegisterApplicationRestart`, update-only, identity-only command line (contract `restart-registration.md`).

**Independent Test**: quickstart V1 with `-Restart`, V10, V13.

- [X] T024 [US3] `src/salamdr1.cpp`: after `MainWindow->CanClose = TRUE`, call `RegisterApplicationRestart(SalRestartCommandLine(...), RESTART_NO_CRASH | RESTART_NO_HANG | RESTART_NO_REBOOT)` using `cmdLineParams` (`SetTitlePrefix`/`TitlePrefix`, `SetMainWindowIconIndex`/`MainWindowIconIndex`); UTF-8 prefix → wide via `SalU8ToW`; trace a failure, never fail start-up; not called on the early-exit paths (`WM_USER_FORCECLOSE_MAINWND` posted during start-up)
- [X] T025 [US3] Build Release; quickstart **V1** with `-Restart` (`restartable=True`, restarted pid, panels/tabs as stored — compare `Left Panel`/`Right Panel` keys before and after), **V10** (`-t Work -i 2` survives), record in `fix-log.md` (SC-003)
- [X] T026 [US3] **Commit 3**: *restart registration*

---

## Phase 6: User Story 5 — an upgraded installation no longer contains the removed helper (P2)

**Goal**: contract `installer-cleanup.md`.

**Independent Test**: quickstart V12, V15, V16.

- [X] T027 [US5] `setup/tandemcommander.iss` `[Code]`: `CurStepChanged(ssPostInstall)` deleting `{app}\utils\salmon.exe` with a ~5 s retry, `Log()` for absent / deleted / left behind, never failing, never a message box; a comment block explaining why this is **not** an `[InstallDelete]` entry (measured B6) in the style of the feature-072 comment
- [X] T028 [US5] Compile the installer into the scratchpad (`ISCC /O /F`), run quickstart **V12** (running 0.1.7 → exit 0, helper gone, log line, program restarted), **V15** (0.1.7 not running), **V16** (clean install, then over itself: nothing to do); compare the upgraded folder's file list with a fresh installation's (SC-009)
- [X] T029 [US5] **Commit 4**: *installer step*

---

## Phase 7: User Story 1 end to end + User Story 4 — nothing else changed (P1/P2)

**Goal**: the real installer, and proof that sign-out / shutdown / normal exit are untouched.

- [X] T030 [US1] Quickstart **V11**: branch installer over the running branch build, **5 runs**, exit 0 each, restarted each (SC-001, SC-003); **V13** `/NORESTARTAPPLICATIONS`; **V14** declined update (exit 5 within seconds, installation unchanged, program running, nothing on screen; record what Inno Setup does about restarting after a failure)
- [X] T031 [US4] Normal-exit regression with `probe/tc_drive.ps1 -Action close`: idle; *Confirm on program exit* on (confirmation appears); file operation running (*Exiting* dialog appears); Code Viewer open (plug-in question appears) — all as before 080
- [X] T032 [US4] `probe/wnd_probe.ps1 -Query -EndSession -Flags 0` against an idle instance (ordinary sign-out query, no close-app flag): the pre-080 path runs — the program closes inside the query
- [X] T033 [US4] **Independent review** of `git diff main -- src/` by an agent that did not write it, refute-first, with the questions: which pre-existing path changed behaviour? can any prompt still appear under `UnattendedClose`? is any member touched after `DestroyWindow`? can `CloseAppAgreed` / the swallow leak into a later ordinary close? Fix what it finds (re-run the affected V-scenarios), record verdict and corrections in `fix-log.md`

---

## Phase 8: Polish, records, machine restore

- [X] T034 [P] `CHANGELOG.md`, section `## [0.1.8] — unreleased`: *Changed* — the program closes for an update without asking and comes back afterwards; declines (update fails as before) while a file operation runs, a search runs, a plug-in window is open or a plug-in connection is live — no prompt, no later exit; *Fixed* — upgraded installations no longer keep `salmon.exe`; truthful about the 0.1.7 root cause; lead paragraph untouched unless needed
- [X] T035 [P] User manual under `help/`: find the page(s) on exiting the program / installation / updating; add a short note on updating while the program is running (what closes silently, what declines), house style of the post-rebrand page `configuration_cmdshell.htm`
- [X] T036 [P] Records: `specs/NEXT-WORK.md` item 2 → done with the corrected root cause and the follow-ups; `specs/072-winget-distribution/REMAINING-WORK.md` P1 → closed with a pointer; `CLAUDE.md` *Recent Changes* entry 080; write `specs/080-restart-manager-upgrade/REMAINING-WORK.md` (plug-in-visible unattended close so viewer windows can close silently; restart after reboot; the owed human steps of quickstart §5)
- [X] T037 Gates: full Debug + Release build (`build.cmd full`, `build.cmd full release`), `saltests` total, `python tools/check_encoding.py` strict `TOTAL: 0`, `git diff --stat main -- src/plugins/shared` empty, `tools/check_runtime_deps.py` green on the Release tree
- [X] T038 Machine restore per quickstart §9: uninstall the scratch installation, delete + import the configuration backup, re-export and compare, verify `setup\output` hashes, the `HKLM` 0.1.7 uninstall key, absence of the `HKCU` uninstall key, no leftover processes; delete `temp\tc-config-backup-080.reg` only after the comparison passes
- [X] T039 `specs/080-restart-manager-upgrade/closing-report.md` + final `fix-log.md` status; **commit 5**: *records*

---

## Dependencies & Execution Order

- Phase 1 → Phase 2 → everything else.
- **US1 (Phase 3)** needs Phase 2. **US2 (Phase 4)** builds on US1's handler
  block (same function) — sequential, one commit for both.
- **US3 (Phase 5)** needs only T005/T007 (`SalRestartCommandLine`); independent
  of US1/US2 in code, verified together with them.
- **US5 (Phase 6)** is independent of all `src/` work (installer script only);
  its verification V12 also exercises US1 and US3.
- **Phase 7** needs US1–US3 and US5 built into one Release tree + installer.
- **Phase 8** last; T038 is the very last action that touches the machine.

### Parallel opportunities

T002/T003 (done) · T017, T018, T019 (three files, one rule) · T034, T035, T036
(three record sets). The rest is one function in one file and is sequential by
nature.

## Implementation Strategy

MVP = Phase 2 + Phase 3: the two-stage close for the idle case. It is not
shippable alone — without Phase 4 the execute stage could still raise a prompt
in the race window — so US1 and US2 land in one commit. US3 and US5 are
separate, independently revertible commits. Every phase ends with probe
results written to `fix-log.md` before the next one starts.
