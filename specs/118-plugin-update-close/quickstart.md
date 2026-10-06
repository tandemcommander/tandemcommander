# Quickstart: feature 118 - GUI runs done 2026-10-06 (58 / 0 / 0; control 67 / 0 / 0)

Automated (hidden desktop). Preconditions: no `tandemcommander.exe` running (also not the
installed one - every probe shares `HKCU\Software\Tandem Commander` with it; the probe refuses
otherwise). The probe writes its fixtures under `%TEMP%\tc118` (a 4 GB **sparse** file - no disk
space - and two text files of 40,000 lines) and removes them; inside the window in which it has
exported `HKCU\Software\Tandem Commander` it gives the plug-ins' commands their keys for the
session (File Comparator Ctrl+Shift+C, Disk Map Ctrl+Shift+D, Batch Renamer Ctrl+Shift+R, Checksum
Calculate Ctrl+Shift+U and Verify Ctrl+Shift+V - `Plugins\<n>\Menu\<m>\HotKey`, the 117 method)
and restores and verifies the whole key at the end. Row M2 maps `%windir%\WinSxS` (read only). It
refuses to run on the user's desktop (`Default`): start it only through the runner. The runner's
log (`-Log`) is UTF-16; the result files (`-OutFile`) are ASCII.

Every row starts a fresh instance, opens the window with the plug-in's key, reaches the row's
state (else NOT DRIVEN), and performs the installer's Restart Manager request with
`specs\080-restart-manager-upgrade\probe\rm_probe.ps1` (no installer; only processes started from
`-Exe` are touched) while it records every window that appears.

The builds: `build\tandemcommander\Debug_x64_118` (the maintainer's copy of this build) and
`build\tandemcommander\Debug_x64_pre118` (HEAD 72a14a8e before the change, = the 117 build).
`-Exe` is a parameter; nothing below depends on `Debug_x64`.

Run from the repository root in Windows PowerShell, each command wrapped by the registry check
(the export's SHA-256 must be the same before and after - on 2026-10-06 `1AB614304771DBE0...`;
pass the current value as `-RegBaseline`):

```powershell
Set-Location D:\Projects\tandemcommander
if (Get-Process tandemcommander -ErrorAction SilentlyContinue) { throw 'close every Tandem Commander first' }
function RegHash { reg export "HKCU\Software\Tandem Commander" "$env:TEMP\tc118_reg.reg" /y | Out-Null; (Get-FileHash "$env:TEMP\tc118_reg.reg").Hash.Substring(0, 16) }
$P = 'D:\Projects\tandemcommander\specs\118-plugin-update-close\probe'
$E = 'build\tandemcommander\Debug_x64_118\tandemcommander.exe'
$B = 'build\tandemcommander\Debug_x64_pre118\tandemcommander.exe'
RegHash
```

1. The probe on this build and on the build before 118 (about 15 minutes each - 20 instances):

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_118.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\118-plugin-update-close\probe\update_close_probe.ps1 -Exe $E -Expect fixed -RegBaseline 1AB614304771DBE0 -OutFile $P\update_close_result.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_pre118.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\118-plugin-update-close\probe\update_close_probe.ps1 -Exe $B -Expect before -RegBaseline 1AB614304771DBE0 -OutFile $P\update_close_result_pre118.txt"
RegHash
```

Single rows: `-Only F1,C3` (comma-separated). If F2 reports NOT DRIVEN ("state not reached": the
comparison had finished before the request), raise `-FcLines` (e.g. `-FcLines 80000`); if V2 or C1
do, raise `-BigMB` (e.g. `-BigMB 16384`; sparse, no disk space).

## Expected

This build (`-Expect fixed`), per row a STATE row PASS and an RM row PASS:

| Row | State | Expected |
|---|---|---|
| F1 | comparison of two text files finished | agree: rm_probe exit 0, process ended with exit code 0, no window shown but the core's wait window `SalamanderSaveBits`, no crash report |
| F2 | still comparing (title "... press ESC to cancel") | agree, as F1 |
| F3 | "The files are identical. Do you wish to close File Comparator?" box | decline: rm_probe exit 1 within 1 s, process alive, every window kept, nothing shown |
| F4 | Compare Files dialog open (NOT DRIVEN if the configuration skips the dialog) | decline; WORK: the dialog is still open |
| M1 | Disk Map, scan of a 21-file folder finished (File > Abort disabled) | agree |
| M2 | Disk Map of `%windir%\WinSxS`, still scanning (File > Abort enabled) | agree (the scan is aborted) |
| M3 | Disk Map finished, its Log window shown | agree |
| M4 | Disk Map's About box open | decline |
| V1 | Checksum Verify finished ("All files OK") | agree |
| V2 | Verify of a 4 GB file still running | agree |
| C1 | Calculate of a 4 GB file still running | decline; WORK: the window is still open |
| C2 | Calculate finished, list not saved | decline; WORK: the window still holds its 2 rows |
| C3 | Calculate finished and EVERY type the Save dialog offers saved (`cs_c3.<ext>` each - the dialog keeps the plug-in's default name, the folder's) | agree; WORK: every saved list intact (2 checksum lines each) |
| C4 | every type saved, then a row removed with Del | decline; WORK: the window holds its edited list (1 row) |
| C5 | several types calculated, only the first saved (NOT DRIVEN if the configuration calculates one type) | decline; WORK: 2 rows kept |
| C6 | every type saved, then type 0 saved again over its own file while the probe holds a byte-range lock on it: the open truncates, the write fails (NOT DRIVEN when the failure does not happen that way - the STATE row says how it went) | decline; WORK: 2 rows kept |
| B1 | Batch Renamer dialog open | decline; WORK: the dialog is still open |
| X1 | comparator + map + verification, all finished, in one instance | agree |
| R1 | no plug-in window (080) | agree |
| N2 | the program's Configuration dialog (080/088) | decline |

Each declining row also ends with an END row PASS (the ordinary exit afterwards: exit 0, no stray
window, no new crash report). Summary: `Rows: PASS n, FAIL 0, NOT DRIVEN 0`, nothing left running,
fixture removed, registry restored and identical.

The build before (`-Expect before`, the control): every plug-in row declines (F1, F2, M1-M3, V1,
V2, C3, X1 included - their windows were not declared), R1 agrees, N2 declines; C3's WORK row
passes as well (the saved files are untouched by a declined request).

## Owed to a person (not automatable here)

- A real update (`winget upgrade` or the installer over an installed build) with a finished File
  Comparator / Disk Map / Verify window open: the program closes and starts again; with an unsaved
  Calculate list or a Batch Renamer dialog open, the installer reports that it could not close the
  program and the window keeps its content.
- Disk Map's file tooltip shown (mouse over the map) during the request: agree (declared; the probe
  has no real mouse).
