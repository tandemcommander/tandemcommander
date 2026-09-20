# Fix Log — Feature 080 (upgrading over a running instance)

Running record, newest entries at the bottom of each section. Written while
working, not reconstructed afterwards. The whole Spec Kit flow
(specify → plan → tasks → implement) runs autonomously; the maintainer is away.

**Baseline**: branch `080-restart-manager-upgrade` from `main` at `e6466db`
(0.1.8 / build 192 in the tree, **unreleased**; last published version 0.1.7).

## Status

| Phase | State | Notes |
|---|---|---|
| specify | done 2026-09-20 | `spec.md`, checklist 16/16, no clarification markers (three decisions recorded as assumptions) |
| plan | done 2026-09-20 | baseline B0–B6, protocol P1–P6, busy states S1–S3 measured; `research.md` R1–R9, `plan.md`, `data-model.md`, 3 contracts, `quickstart.md` V1–V16; spec revised (Background, US1.5, US5, FR-021/022, SC-009/010) |
| tasks | done 2026-09-20 | `tasks.md`: 39 tasks (4 done during planning), 8 phases, 5 planned commits |
| implement | done 2026-09-20 | 39/39 tasks; commits `3ad8551` `f4b1836` `8151f9c` `a1a8982` + records; independent review (no blocker, 3 SHOULD-FIX fixed); gates green; machine restored and verified |

## Log

### 2026-09-20 — specify

- Branch created by the Spec Kit git hook: `080-restart-manager-upgrade`
  (feature number 080). `.specify/feature.json` points at the new directory.
- Read before writing: `specs/NEXT-WORK.md` item 2,
  `specs/072-winget-distribution/REMAINING-WORK.md` P1 and `quickstart.md`
  §2b, `setup/tandemcommander.iss`, the exit sequence in
  `src/mainwnd3.cpp` (`WM_ENDSESSION` / `WM_QUERYENDSESSION` /
  `WM_USER_CLOSE_MAINWND`, one shared handler).
- First observations from the code, to be confirmed by the baseline:
  - The handler never looks at `ENDSESSION_CLOSEAPP`; an installer's request
    is treated as an ordinary (non-critical) sign-out: the **whole interactive
    exit runs inside the question stage** — waiting windows, plug-in unload,
    panel close, configuration save, `DestroyWindow` — and only then returns
    TRUE. Any prompt on that path blocks an unattended requester.
  - A comment at the end of the handler states the design premise: *"all
    Windows versions kill the process as soon as the main window is destroyed
    during shutdown, so the following code is dead code in that case"*. For an
    installer's request that premise is false — nobody kills the process; it
    has to end by itself.
  - Nothing in `src/` calls `RegisterApplicationRestart`.
  - The installer script sets neither `CloseApplications` nor
    `RestartApplications`, so Inno Setup's defaults apply (close: yes,
    restart: yes).
- The 072 evidence also named `salmon.exe` as holding files; the helper was
  removed in feature 079, so the baseline has to be taken again at HEAD
  (spec FR-001).
- Decisions made without the maintainer (spec *Assumptions*): no program
  option for the restart; state survives through the stored configuration;
  restart after reboot/sign-out excluded.

### 2026-09-20 — plan, phase 0: the baseline (spec FR-001) — **the premise was wrong**

Safety first: `HKCU\Software\Tandem Commander` exported to
`<scratchpad>/080/tc-config-backup-080.reg` (SHA-256 `4c501e9c…dc5c7`, second
copy in the git-ignored `temp\`); `setup\output` hashes recorded
(0.1.7 = `6731e146…f64dd`); no instance of the program was running; the shell
is not elevated; the machine-wide 0.1.7 in `C:\Program Files` is untouched by
everything below (per-user installs into the scratchpad, `/CURRENTUSER /DIR=`).

Probes written for this (committed under `probe/`):
`rm_probe.ps1` (the installer's Restart Manager sequence without an
installer; refuses to act if the list contains a process from outside the
registered location), `wnd_probe.ps1` (top-level windows of one pid, and the
window protocol by hand), `upgrade_probe.ps1` (a real silent installer run over
a running scratch installation).

| # | Scenario | Result |
|---|---|---|
| B0 | `rm_probe` against the HEAD Release build, idle | `RmShutdown` = 0 after **1.3 s**, process ended. `restartable=False`. |
| B1 | published 0.1.7 installer over running 0.1.7 (the 072 situation, per-user) | **exit 5** in 1.0 s — reproduced. Log: RM found **two** applications, *Tandem Commander, File Manager* and *Tandem Commander Bug Reporter*; *Some applications could not be shut down* came **20 ms** after *Shutting down* — nobody was even asked. Both processes kept their pids. |
| B2 | `rm_probe -InstallDir` on that installation | `salmon.exe` is `RmUnknownApp` with **0 top-level windows**; `RmShutdown` = 351 `ERROR_FAIL_SHUTDOWN` after **0.0 s**. |
| B3 | `rm_probe -ExePath` on the 0.1.7 main executable alone | `RmShutdown` = 0 after 1.2 s; `salmon.exe` ends with its parent. |
| B4 | HEAD installer over running **0.1.7** | **exit 0** (4.3 s). The HEAD package has no `salmon.exe`, so it is not registered with RM; only the main program is listed and it closes. |
| B5 | HEAD installer over running HEAD, 3 runs | **exit 0** 3/3 (3.0–3.1 s). *Attempting to restart applications* is logged, **nothing is restarted** — the program is not registered for restart. |

**Root cause of the 072 failure**: the crash-reporting helper. A process
without a top-level window cannot be closed by the Restart Manager, and the
Restart Manager fails the *whole* shutdown immediately when the list contains
one — without sending a single message to the main program. The main
program's handler was never exercised in the failing run; asked on its own it
closes in about a second, in 0.1.7 as well as at HEAD. Feature 079 removed the
helper for unrelated reasons (antivirus) and thereby removed this failure.
(The name *"Tandem Commander, File Manager"* is one application — its file
description contains a comma.)

So at HEAD the headline defect is **already gone**, and the upgrade path that
matters to real users — 0.1.7 running, 0.1.8 installer — works (B4).
What is left, and is the real scope of this feature:

1. The program **vanishes** after an update and is not started again (B5).
2. The close happens **inside the question stage** and is the fully
   **interactive** exit: any state that makes a manual exit ask something puts
   a prompt on an unattended machine and leaves the installer waiting for its
   timeout (to be measured next).
3. **New finding, outside the original description**: after B4 the file
   `utils\salmon.exe` is **still on disk**. The installer never deletes files
   it stopped shipping (the script has no `[InstallDelete]`), so every
   installation upgraded from <= 0.1.7 keeps the very file antivirus engines
   flag — feature 079's goal is not reached for upgraders. And the obvious
   fix is a trap: `[InstallDelete]` entries are registered with the Restart
   Manager just like `[Files]`, so listing `salmon.exe` there would bring
   failure B1 straight back for anyone upgrading with the program open.
   To be verified, then solved without registering the file.

### 2026-09-20 — plan, phase 0: the protocol, measured (research R2)

`probe/rm_protocol_dummy.ps1` builds a small window program that logs what the
Restart Manager sends and behaves as told. Facts, all measured on this machine
(Windows 11 Pro 26200):

| # | Fact |
|---|---|
| P1 | Every top-level window of the process gets `WM_QUERYENDSESSION` (wParam 0, lParam `0x1` = `ENDSESSION_CLOSEAPP`), then `WM_ENDSESSION` with the same lParam and wParam 1 (everyone agreed) or 0 (someone refused). |
| P2 | Right after `WM_ENDSESSION`(1) — 1 to 5 ms later — the **main window only** also receives **`WM_CLOSE`**. A second top-level window of the same process gets the two session messages and no `WM_CLOSE`. After a refusal no `WM_CLOSE` is sent. |
| P3 | After `WM_ENDSESSION` the Restart Manager waits **30 s** for the process to end: a dummy that exits 8 s later counts as success (`RmShutdown` = 0 after 8.0 s); one that never exits gives 351 after 30.0 s. |
| P4 | A window that does not answer the query within **5 s** fails the shutdown (351 after 5.0 s — seen with the program itself, below). |
| P5 | Exiting *inside* the query (what the program does today) is accepted: `RmShutdown` = 0. |
| P6 | A process registered with `RegisterApplicationRestart` shows `restartable=True` in `RmGetList` and **is restarted by `RmRestart` even when it had been running for 3 seconds** — the 60-second rule of crash restarts does not apply. The registered command line arrives intact. |

### 2026-09-20 — plan, phase 0: what the program does today when it is *not* idle

Driver `probe/tc_drive.ps1` (posts messages to one pid only). HEAD Release
build, English UI (language value switched for the tests; the whole key is
restored from the backup at the end).

| # | State | What happened on `RmShutdown` |
|---|---|---|
| S1 | modal dialog open (Copy dialog) | 351 after **0.0 s**, nothing shown — fine already |
| S2 | copy in progress (held at the *Confirm File Overwrite* question) | 351 after **5.0 s**; the dialog ***Exiting Tandem Commander*** stays on the screen and the main window stays disabled. When the copy ended minutes later **the program exited by itself** — long after the installer had given up and rolled back. |
| S3 | a Code Viewer window open (F3 on a `.txt` — the plug-in viewer is the default, so this is the everyday state) | 351 after **5.0 s**; the plug-in's question *"viewer windows are open, close them?"* and the *saving configuration* wait window stay on the screen, main window disabled. Answering *Yes* minutes later: **the program exits**. |

So the real defects at HEAD are: an unattended machine is left with a
**prompt**, the installer waits for a **timeout** instead of getting an answer,
and the program may **exit later by surprise**, with no installer around to
start it again. None of that is visible in the idle case the backlog
described.

B6 — the `[InstallDelete]` trap, verified: a variant installer (the script plus
`[InstallDelete] Type: files; Name: "{app}\utils\salmon.exe"`, compiled into the
scratchpad, the temporary `.iss` deleted again) over a running 0.1.7:
**exit 5**, *Found 12 files to register* (one more than B4's 11), the helper is
listed again, *Some applications could not be shut down* after 20 ms. The stale
file must be removed by code that runs after the files are installed, not by a
section the Restart Manager learns about.

The uninstaller, by the way, does remove the stale file: the uninstall log is
cumulative, so an installation upgraded 0.1.7 → HEAD and then uninstalled left
nothing behind.

### 2026-09-20 — plan, phase 1: design decisions (details in `research.md`)

- **Decide at the question, act at the instruction** (R4). The execute stage
  re-enters the existing handler as a non-critical session request, marked by
  the program's own flag, *synchronously* — a posted close would be the smaller
  change but could be cut off in the middle of a configuration save when the
  close-app flag comes from a servicing restart instead of an installer.
- **Scope guard**: close-app flag set, critical flag not set,
  `SM_SHUTTINGDOWN` = 0. Everything else keeps its old path.
- **One pure decision function** over a snapshot, reasons D1–D8, in
  `src/common/salcloseapp.*` under `saltests`.
- **An open plug-in window declines** (D8). Survey of the 20 shipped plug-ins'
  `Release(parent, force)`: four viewers *ask* when windows are open (Database
  Viewer with a raw `MessageBox` the core cannot see), FTP asks when transfers
  exist. Closing viewer windows silently needs either `force` (cancels FTP
  transfers) or a plug-in-visible notion of an unattended close (plug-in
  interface addition, excluded). Handed over as follow-up.
- **`WM_CLOSE` swallow**: measured P2 — the Restart Manager sends `WM_CLOSE` to
  the main window right after the instruction; without the swallow an abandoned
  unattended close would be followed by an interactive one.
- **Restart**: `RESTART_NO_CRASH | RESTART_NO_HANG | RESTART_NO_REBOOT`; the
  command line carries `-t` / `-i` (identity) and nothing about location.
- **Stale helper**: `[Code]` at `ssPostInstall`, never `[InstallDelete]` (B6).
- The spec was revised rather than left describing a defect that no longer
  exists; the checklist carries a note about the revision.

### 2026-09-20 — implement: pure module (commit `3ad8551`)

- `src/common/salcloseapp.*` + `TestCloseApp080` — `saltests` **1427 → 1524**, 0 failed.
- Registered in `salamand.vcxproj` (+ `.filters`), `saltests.vcxproj`, `precomp.h`.
- Tooling note: the Bash tool's heredocs collapse doubled backslashes, which
  twice corrupted text written through them (a path in this log, a regular
  expression in a helper). Everything containing backslashes is now written
  with the Write tool or from a script file.

### 2026-09-20 — implement: request handling + restart registration

Code (one build, split into two commits afterwards):

- `src/mainwnd3.cpp`
  - file-scope request state (`CloseAppAgreed`, `CloseAppExecuting`,
    `CloseAppSwallowClose`, `CloseAppExecuteTime`) — file scope on purpose: the
    `WM_ENDSESSION` branch touches it after the window object may be gone;
  - `CMainWindow::DecideCloseApp()` — read-only snapshot → `SalCloseAppDecide`;
  - `WM_QUERYENDSESSION`: question stage, first statement of the shared block,
    returns before anything else runs; a new query always clears a pending
    agreement;
  - `WM_ENDSESSION`: instruction stage before the old code (so the *forced
    shutdown* message box is unreachable for an installer's request) — only
    when we had agreed; wParam 0 → forget; else arm the swallow, decide again,
    re-enter the handler as the execute stage with `UnattendedClose` set;
  - `WM_CLOSE`: one-shot swallow, 35 s window;
  - guards in the shared block: `LockedUIReason` box, `CExitingOpenSal`, Find
    close query sent *quiet*, `IDS_SHELLEXTBREAK3`;
  - `RegisterRestartForUpdates()`.
- Guards elsewhere: `plugins1.cpp` (`IDS_PLUGINFORCEUNLOAD`), `fileswn2.cpp`
  (edited-archive information + pack-back dialog, both `IDS_ARCHIVEFORCECLOSE`
  sites, `IDS_FSFORCECLOSE`), `mainwnd4.cpp` (`CloseDetachedFS`),
  `finddlg1.cpp` (`CFindDialog::CanCloseWindow` — the shell-extension box is
  raised in the Find window's own thread), `regwork.cpp` (the two *Error
  Saving Configuration* boxes — **found by the sweep of task T020**; the
  loading boxes are not on the exit path and were left alone).
- Restart registration is refreshed when the identity changes at run time:
  another instance hands over `-t` / `-i` (`ApplyCommandLineParams`), and the
  Configuration dialog drops a forced prefix (`dialogs5.cpp`). The source of
  truth is `Configuration.*Forced`, not the start-up command line.
- Sweep T020, other callees of the exit path: `SaveConfig`,
  `DeleteManager.PluginMayBeUnloaded`, `DiskCache.PrepareForShutdown`,
  `CloseCurrentPath`, `CSalShExtPastedData::CanUnloadPlugin` — no prompt.
  `CFilesWindow::CanUnloadPlugin` leaves an archive through
  `ChangePathToDisk` → `PrepareCloseCurrentPath`, i.e. through the guarded
  site. What stays unguardable from the core: a plug-in's **own** dialogs
  inside `Release()` / `SaveConfiguration()` — kept out of reach by decision
  D8 (no plug-in window open) and D7 (no plug-in file system).

Results with the Release build of this branch (`probe/rm_probe.ps1`,
`probe/tc_drive.ps1`):

| # | Scenario | Before (HEAD) | Now |
|---|---|---|---|
| V1 | idle, close + restart | closed 1.3 s, not restarted | **closed 1.3 s, `restartable=True`, restarted**, title prefix kept, panels as stored |
| V2 | modal dialog | 351 / 0.0 s | 351 / 0.0 s, dialog untouched |
| V3 | copy in progress | 351 / **5.0 s**, *Exiting* dialog left, main window disabled, **exits by itself later** | **351 / 0.0 s**, nothing shown, main window enabled; 10 s after the copy ended **still running** |
| V4 | Code Viewer window open | 351 / **5.0 s**, plug-in question + wait window left, **exits when answered** | **351 / 0.0 s**, nothing shown, viewer still open, still running |
| V5 | internal viewer + idle Find | — | closed 1.4 s, all windows gone, restarted |
| V6 | Find searching `C:\` | — | 351 / 0.0 s, search continues, no *stop searching?* |
| V7 | *Confirm on program exit* on | — | closed 1.2 s, **no confirmation**; control: an ordinary `WM_CLOSE` still shows the *Question* dialog |
| V9 | two instances, one copying | (HEAD: the idle one closes at the question) | 351 / 0.0 s, **both** still running |
| V9b | the same two, both idle | — | closed 1.3 s, **both restarted**, each with its own title prefix (`T080`, `BUSY`) |
| V10 | started with `-t "Work 2" -i 2` | — | restarted command line: `-t "Work 2" -i 2` |
| T032 | ordinary sign-out query (`lParam` 0, `wnd_probe -Query -Flags 0`) | closes inside the query | unchanged: answered TRUE, process ended 1.3 s later |

**V8 — configuration equivalence** (`probe/config_equivalence.ps1`, new): same
starting configuration, two more tabs in the left panel, one tab back; once
closed by hand, once through the Restart Manager.

- *Save on exit* on: **2104 values in both exports, 1 differs** — byte 77 of
  the File Comparator plug-in's 92-byte `Configuration` blob (`02` vs `01`).
  Repeating the experiment showed the same byte differing between **two manual
  exits** and between **two close-app runs**: it is an uninitialised byte the
  plug-in has always written (pre-existing, harmless, not part of this
  feature). Everything else — both panels, all tabs, the active tab,
  histories — is identical.
- *Save on exit* off: **0 differences**, and the stored left panel still has
  the 1 tab of the starting configuration although the closed instance had 3:
  the stored configuration is not touched (FR-004).

Help window (`scawHelp`): could not be exercised — the build tree and the
package contain no help files (*Help Error* box). The classification stays; it
cannot matter while no help ships.

### 2026-09-20 — implement: the real installer (branch build, per-user into the scratchpad)

Installer compiled with `ISCC /O<scratch>\installer /Ftc-080-branch`;
`setup\output` untouched (7 archived installers, as before).

| # | Scenario | Result |
|---|---|---|
| V12 | branch installer over a **running published 0.1.7** (helper running) | **exit 0** (4.3 s); 11 files registered with the Restart Manager (the helper is not among them); log: *Feature 080: removed the obsolete crash-reporting helper*; `utils\` = `sqlite.dll` only. The old 0.1.7 is closed but **not started again** — it never registered for restart; the registration lives in the *old* process, so the restart works from 0.1.8 onward. |
| V11 | branch over running branch, **5 runs** | **exit 0 five times**, 3.0–3.1 s each; each time *After: NEW (restarted)* (pids 11372 → 6896 → 18228 → 14364 → 22180) |
| V13 | `/NORESTARTAPPLICATIONS` | exit 0, no *Attempting to restart applications* line, nothing runs afterwards |
| V14 | installed instance with a copy in progress | **exit 5 after 0.5 s** (not a timeout), *Some applications could not be shut down*, rollback; same pid, same three windows, nothing new on screen; `tandemcommander.exe` hash unchanged. The instance had been started with `-t V14` two updates earlier and still carried the prefix — identity survives real installer restarts. |
| V15 | 0.1.7 installed, not running | exit 0, helper removed, log line present |
| V16 | clean install, then over itself | exit 0 twice, **no** removal line in either log |
| SC-009 | file list, upgraded (0.1.7 → branch) vs fresh | **IDENTICAL**, 360 files (uninstaller records excluded) |
| V17 (new) | helper file held open without delete sharing | **exit 0** after 6.6 s (the 5 s of retries), log: *could not be deleted and was left behind*; the next update removes it |

Observed on the way:

- Inno Setup performs *Attempting to restart applications* **before**
  `ssPostInstall`. Irrelevant for the helper (only a 0.1.7 has one, and a
  0.1.7 is never restarted), but worth knowing.
- **`Start-Process -Wait` waits for the whole process tree.** The program the
  installer starts again is a descendant of the installer, so the first V11
  attempt sat for 614 s until the restarted program was closed. The probe now
  waits for the installer process only (`WaitForExit`), like a package manager.
  The same trap is in `specs/072-winget-distribution/quickstart.md` §2b —
  corrected there as part of the records.
- Two more tooling traps: MSYS path conversion turned the switch
  `/NORESTARTAPPLICATIONS` into `C:/Program Files/Git/NORESTARTAPPLICATIONS`
  (the first V13 run "failed" because the installer never saw the switch —
  run such commands from PowerShell); and `config_equivalence.ps1` resets the
  configuration to the backup, which switches the UI back to Czech, so dialog
  titles the driver matches by name (*Copy*) no longer match. The driver also
  has to put the cursor on the file in **both** panels, because which panel is
  active comes from the stored configuration.

### 2026-09-20 — independent review (task T033)

An agent that had not written the change reviewed `git diff -- src/` plus the
pure module, refute-first, against eight questions (which old path changed
behaviour; can any prompt still appear; object lifetime after `DestroyWindow`;
state leaks; side effects at the question stage; the pure module; the restart
registration; anything else). 101 tool calls, read-only.

**Verdict: no blocker; three SHOULD-FIX, eleven notes.** What it confirmed by
reading: every hunk is inert while the four flags are FALSE (the rewritten
condition in `fileswn2.cpp` reduces to the old expression, the inserted
`else if` in `CPluginData::Unload` leaves `ret` exactly as *No* would);
`CMainWindow` is deleted in `CWindow::CWindowProc` right after `WM_DESTROY`,
and neither frame touches the object afterwards; flags are reset on every
return path; re-entrant session messages during the execute stage are refused
through `SalamanderBusy` without UI; the swallow is exactly one message; the
critical sections are paired and never held across a `SendMessage`; the
quoting is the exact inverse of `GetCmdLine`; both WebView2 keeper windows are
hidden captionless tool windows.

| # | Finding | What was done |
|---|---|---|
| 1 | **SHOULD-FIX.** The `WM_ENDSESSION` branch was entered only when we had agreed, so an installer's instruction *without* an agreement fell into the old code and its **forced-shutdown message box** — contradicting contract C3 and this log. Scenarios: two overlapping requests, a sign-out query slipping in between, a forced close. | **Measured** with the dummy and `rm_probe -Force`: under `RmForceShutdown` (Setup's `/FORCECLOSEAPPLICATIONS`) a program that declines the question still receives `WM_ENDSESSION` with **wParam 1** and lParam `0x1` (no critical flag), then `WM_CLOSE`, and is killed after 30 s. So the scenario is real. **Fixed**: the branch now classifies by the message, not by the agreement; without an agreement it traces and returns 0 — nothing shown, nothing closed. |
| 2 | **SHOULD-FIX (verification gap).** The program's own skipper of the image name on the command line handles a quoted name or a name without spaces; every restart measurement ran from a space-free folder, both real default locations contain spaces. An unquoted image path would make every restart end in *invalid command line*. | **Measured**: per-user installation into `…\tc inst with spaces`, started with `-t "Sp ace" -i 1`, closed and restarted through the Restart Manager. Windows **quotes the image path**: `"…\tc inst with spaces\tandemcommander.exe" -t "Sp ace" -i 1`; the restarted instance shows *Sp ace - src - Tandem Commander*, no error box. No code change needed. |
| 3 | **SHOULD-FIX.** The 35 s swallow window was stamped at the start of the execute stage; an abandonment can come later. | **Measured** (new dummy mode `slow-end`): a program that stays inside `WM_ENDSESSION` gets the `WM_CLOSE` **5.1 s after the instruction**, while still inside the handler; otherwise right after the handler returns. **Fixed**: the time is stamped again after the nested call returns. |
| 4 | NOTE. Leaving an archive at exit goes through `ChangePathToDisk` / `ChangeToRescuePathOrFixedDrive`; when the archive's directory has become unreachable (a dropped share) four sites show error UI. The log had claimed the route was guarded. | **Fixed**: four one-line guards in `fileswn2.cpp` (`IDS_INVALIDESCAPEPATH`, the *path shortened* box, `CDriveSelectErrDlg` → neither retry nor root, `CheckPath` display). |
| 5 | NOTE. Only the two *saving* boxes in `regwork.cpp` were guarded; a plug-in's `SaveConfiguration` can reach the loading helpers. | **Fixed**: `OpenKeyAux`, `GetValueAux`, `GetValue2Aux`, `GetSizeAux`. |
| 6 | NOTE. Decision D8 cannot see a plug-in prompt that has no visible window: FTP's `Release` asks when its operations list is not empty. Whether an FTP operation can exist without a window and without a file system in a panel is **not verified**. | Not changed. Recorded in `REMAINING-WORK.md` with the plug-in-visible *unattended* signal, which is the real remedy. |
| 7 | NOTE. The header comment and a test label said save-bits/wait windows never count; the core's `CWaitWindow` is `WS_OVERLAPPED`, gets a caption, and does count. Harmless (it can only decline, and exists only while busy). | Comment and label corrected. |
| 8 | NOTE. `EnumWindows`' result was ignored — a failure would have produced "no windows" = agree. | **Fixed**: a failed enumeration counts as an unknown window (decline). |
| 9 | NOTE. A decline because of a foreign window could not be diagnosed. | **Fixed**: the trace names the window handle and class. |
| 10 | NOTE. "No side effects" at the question stage is not literal: `RemoveFinishedDlgs()` closes handles of finished threads. | Contract C2 reworded. |
| 11 | NOTE. `-t ""` (forces *no prefix*) was not kept across the restart; a prefix cut by `lstrcpyn` in mid-character was dropped silently. | **Fixed**: `-t ""` is emitted; the tail is trimmed with `SalU8TrimIncompleteTail` before converting. Tests added. |
| 12 | NOTE. Contract R1 said "once per process"; there are three call sites, and an instance about to exit at start-up is briefly restartable. | Contract reworded (harmless: the registration only matters while the process exists). |
| 13 | NOTE. Nothing stops an execute stage that outlives the requester's 30 s. | Not changed (1.2–1.4 s measured); recorded as a known limitation. |
| 14 | NOTE. Unverified: the Restart Manager's idea of the main window when ours is hidden in the tray. | Measured below. |

### 2026-09-20 — after the review: measurements, fixes, second round

Measured because the review asked (details in `research.md` R2, P7–P9):

- **Forced close** (`rm_probe -Force` against the dummy in `refuse` mode):
  question → refused → **`WM_ENDSESSION` wParam 1, lParam `0x1`** → `WM_CLOSE`
  → killed after 30.0 s. Finding 1 is therefore real for Setup's
  `/FORCECLOSEAPPLICATIONS`.
- While fixing it a **follow-up hole** showed up that the review had not
  listed: that forced instruction is *also* followed by the `WM_CLOSE`, and the
  swallow was armed only after an agreement — so a declined-then-forced request
  would have started the ordinary interactive exit (with a copy running: the
  *Exiting* dialog). The swallow is now armed for every installer's instruction
  with wParam 1. Verified with the program itself: copy in progress,
  `rm_probe -Force` → the three windows that were on screen before are the
  only ones 8 s into the 30 s, then the Restart Manager kills the process, as
  its caller demanded. Nothing was shown at any point.
- **Path with spaces** (finding 2): restart from `…\tc inst with spaces` works;
  Windows quotes the image path.
- **`slow-end`** (finding 3): `WM_CLOSE` arrives 5.1 s after the instruction
  when the handler is still running.
- **Hidden main window** (finding 14): `ShowWindow(SW_HIDE)` on the main
  window → the process is listed as `RmOtherWindow`; closed in 1.3 s and
  restarted.
- A side observation: with a plain error box open (*Cannot copy a file to
  itself*) the request is declined in 0.0 s — the modal state covers it.

Builds after the fixes: Debug + Release, 0 errors; `saltests` **1527 / 0**.

Second round with the final Release build: V1 with `-t "" -i 3` (restarted
command line `-t "" -i 3`), V3 (351 / 0.0 s, still running 8 s after the copy
ended), hidden main window, forced close; final installer
(`tc-080-final.exe`): V12 over a running published 0.1.7 → exit 0, helper
removed; V11 three runs → exit 0, restarted each time.

Commits: `f4b1836` request handling · `8151f9c` restart registration ·
`a1a8982` installer step. They were produced from one tested working tree by
temporarily stripping the restart parts from four files
(`scratchpad/080/split_commit.py`), committing, and restoring — the final tree
is byte-for-byte what was built and tested (`git status` clean for `src/` and
`setup/` afterwards).

### 2026-09-20 — gates (task T037)

| Gate | Result |
|---|---|
| `build.cmd full` (Debug x64) | BUILD SUCCEEDED, 0 errors |
| `build.cmd full release` | BUILD SUCCEEDED, 0 errors; *Runtime: 4 file(s) shipped, closure OK* (`check_runtime_deps.py`) |
| `saltests.exe` | **1527 checks, 0 failed** (1427 before the feature) |
| `python tools/check_encoding.py` | strict **TOTAL: 0** |
| `git diff main -- src/plugins/shared` | empty; `LAST_VERSION_OF_SALAMANDER` 106 |
| version | `VERSINFO_BUILDNUMBER` 192, `MyAppVersion` 0.1.8 — unchanged |

### 2026-09-20 — the machine, put back (task T038, spec SC-008)

- All test instances closed through the Restart Manager; the scratch
  installation uninstalled (folder gone); no `tandemcommander`, `salmon` or
  `rmdummy` process left.
- `HKCU\Software\Tandem Commander`: key deleted, backup imported, exported
  again — **line for line identical to the backup (3068 lines), same SHA-256
  `4c501e9c…dc5c7`**; UI language back to `czech.slg`. The second copy in
  `temp\` deleted after the comparison.
- `setup\output`: seven installers, hashes as recorded at the start
  (0.1.7 = `6731e146…`). Nothing was ever compiled into that folder.
- Machine-wide 0.1.7: `HKLM` uninstall entry 0.1.7, executable dated
  2026-08-29, untouched. No `HKCU` uninstall entry, no Start Menu shortcut, no
  crash report written during the tests.
