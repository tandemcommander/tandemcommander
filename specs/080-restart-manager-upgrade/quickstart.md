# Quickstart — validating feature 080

What to run and what must happen. Contracts: [close-request](contracts/close-request.md),
[restart-registration](contracts/restart-registration.md),
[installer-cleanup](contracts/installer-cleanup.md). Protocol facts and the
baseline: [research.md](research.md).

All probes are Windows PowerShell 5.1 scripts under `probe/`; run them with
`powershell -NoProfile -ExecutionPolicy Bypass -File <script> ...`. None needs
elevation. `<S>` is a scratch directory outside the repository.

## 0. Before anything is started — protect the machine (spec FR-018)

The program has one configuration per user, so every test instance shares the
real one.

```
reg export "HKCU\Software\Tandem Commander" <S>\tc-config-backup.reg /y      :: keep a second copy
certutil -hashfile setup\output\tandemcommander-0.1.7-x64-setup.exe SHA256    :: expect 6731e146...f64dd
```

- never compile an installer into `setup\output\` — use
  `ISCC /O<S>\installer /F<name> setup\tandemcommander.iss`;
- install only per-user into the scratch directory
  (`/CURRENTUSER /DIR=<S>\tc-inst /NOICONS`);
- make sure no instance of your own is running from the build tree;
- at the end: §9.

## 1. Build and unit tests

```
build.cmd full release          :: also Debug for the saltests run
<build>\saltests.exe            :: TestCloseApp must pass; total not below 1427
python tools\check_encoding.py  :: strict TOTAL: 0
git diff --stat main -- src/plugins/shared   :: empty
```

## 2. The request, without an installer

`EXE` = `<build>\Release_x64\tandemcommander.exe`.

| # | Scenario | Steps | Must |
|---|---|---|---|
| V1 | idle close + restart | start the program; `rm_probe.ps1 -ExePath EXE -Restart` | `restartable=True`; `RmShutdown : 0` in under 10 s; *Survivors: none*; `RmRestart : 0`; *Restarted: pid …* |
| V2 | modal dialog | `tc_drive -Action command -Id 686` (Configuration), then `rm_probe` | 351 within 5 s (expected: ~0 s); the dialog is still there and usable; nothing new on screen |
| V3 | file operation | panels on two folders holding the same file; cursor on it; `-Id 727` (Copy), OK → *Confirm File Overwrite* stays open; `rm_probe` | 351 within 5 s; **no** *Exiting Tandem Commander* dialog, main window enabled; cancel the copy → **the program keeps running** (wait 10 s) |
| V4 | plug-in viewer | F3 on a `.txt` (`-Id 742`) → Code Viewer window; `rm_probe` | 351 within 5 s; **no** plug-in question, **no** *saving configuration* window; viewer still open; program keeps running |
| V5 | internal viewer / idle Find | open the internal viewer (Alt+F3) and an idle Find window (`-Id 741`); `rm_probe` | `RmShutdown : 0`; all windows gone; process ended |
| V6 | Find searching | start a long search; `rm_probe` | 351 within 5 s; the search continues, no *stop searching?* question |
| V7 | confirm on exit | enable *Confirm on program exit*; idle; `rm_probe` | `RmShutdown : 0`, no confirmation |
| V8 | configuration equivalence | from the same state (known directories, three tabs in one panel): once exit by hand, export the key; once close through `rm_probe`, export the key; compare | identical apart from values that differ between any two runs (list them) |
| V9 | two instances | one idle, one in the V3 state; `rm_probe` | 351; **both** still running (the idle one did not close at the question) |
| V10 | identity | start with `-t Work -i 2`; `rm_probe -Restart` | the restarted window's title starts with `Work`, icon variant 2; panels as stored |

## 3. The real installer

| # | Scenario | Steps | Must |
|---|---|---|---|
| V11 | update over this version | install the branch's installer into `<S>\tc-inst`; `upgrade_probe.ps1 -Installer … -InstallDir <S>\tc-inst`, **5 runs** | exit code 0 five times; log: *Shutting down applications* … *Attempting to restart applications*; *After: NEW (restarted)* |
| V12 | update over the published 0.1.7 | uninstall; install `setup\output\tandemcommander-0.1.7-x64-setup.exe` the same way; `upgrade_probe` with the branch's installer | exit code 0 although `salmon.exe` was running; afterwards `utils\salmon.exe` **does not exist**; installer log has the removal line; program restarted |
| V13 | no restart on request | `upgrade_probe … -ExtraArgs /NORESTARTAPPLICATIONS` | exit code 0; nothing runs from the folder afterwards |
| V14 | declined update | the V3 state in the installed instance; `upgrade_probe -Start 0` | exit code 5 within seconds (not after a timeout); installation unchanged; program still running, nothing on screen; record whether Inno Setup restarts anything after a failure |
| V15 | stale file, program not running | 0.1.7 installed, not started; run the branch's installer | exit code 0; `utils\salmon.exe` gone |
| V16 | clean install | branch installer into an empty folder, then over itself | exit code 0 twice; removal step reports nothing to do |

## 4. What must not have changed (spec FR-013)

- Normal exit: with and without *Confirm on program exit*; with a file
  operation running (the *Exiting* dialog must appear as before); with a
  plug-in viewer open (the plug-in's question must appear as before).
- `wnd_probe.ps1 -Query -EndSession -Flags 0` against an idle instance (an
  ordinary sign-out query, no close-app flag): the program runs the pre-080
  path — it closes inside the query, as before.
- Code review of the diff: every changed line is either inside an
  `if (… close-app …)` / `if (UnattendedClose)` branch or is new code.

## 5. Owed to a person (cannot be run autonomously)

1. **Machine-wide update, elevated installer**: `build_setup.cmd`, run the
   installer elevated over a running, *non-elevated* program installed in
   `C:\Program Files`; must exit 0, and the restarted program must **not** be
   elevated (Task Manager → *Elevated* column).
2. **A real `winget upgrade`** once the package is in the catalogue and a
   version newer than the installed one is published.
3. **Interactive installer**: run Setup by hand over a running program; the
   *Preparing to Install* page offers to close it; both choices behave.
4. **Real sign-out, shutdown and forced shutdown** with the program idle and
   with a file operation running — unchanged from 0.1.7 (the *Exiting* dialog,
   the block reason on the shutdown screen, the configuration backup).
5. **A servicing restart** (*Update and restart*) with the program open:
   configuration intact afterwards.

## 6–8. (reserved)

## 9. Afterwards — put the machine back (spec SC-008)

```
<S>\tc-inst\unins000.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
reg delete "HKCU\Software\Tandem Commander" /f
reg import <S>\tc-config-backup.reg
reg export "HKCU\Software\Tandem Commander" <S>\tc-config-after.reg /y       :: compare with the backup
certutil -hashfile setup\output\tandemcommander-0.1.7-x64-setup.exe SHA256    :: unchanged
reg query "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{35C0B0DC-DB73-429C-AAA8-FBC41C937F66}_is1" /v DisplayVersion   :: still 0.1.7
reg query "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{35C0B0DC-DB73-429C-AAA8-FBC41C937F66}_is1"                       :: must not exist
```

No `tandemcommander`, `salmon` or `rmdummy` process may be left running.
