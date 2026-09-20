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
| tasks | pending | |
| implement | pending | |

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
