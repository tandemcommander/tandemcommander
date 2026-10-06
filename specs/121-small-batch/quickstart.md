# Quickstart: feature 121 - GUI runs pending

## Without the GUI (done, repeatable)

```
build.cmd
build\tandemcommander\Debug_x64\saltests\saltests.exe
python tools\check_encoding.py --strict
```

Expected: `saltests: 17513 checks, 0 failed` (`TestSmallBatch121`: the message box breaks, the
title helper, the Look in text and the item name, the plug-ins' whole-character cuts and display
text, the Save dialogs' initial folder, the FTP typed-login rule, the NetHood rule including a real folder shortcut resolved end to
end in `%TEMP%`); `TOTAL: 0 finding(s)`.

## GUI runs (owed; hidden desktop only)

Preconditions: no `tandemcommander.exe` running (also not the installed one - the probe shares
`HKCU\Software\Tandem Commander` with it and refuses otherwise). The probe writes its fixtures under
`%TEMP%\tc121` (a junction made with `mklink /J` into its own folder - removed first, then the
tree) and removes them; inside the window in which it has exported the key it sets English, turns
the exit confirmation off, gives Disk Map Ctrl+Shift+D, Checksum Calculate Ctrl+Shift+U, Registry
Editor Find Ctrl+Shift+G and FTP Show Logs Ctrl+Shift+L (`Plugins\<n>\Menu\<m>\HotKey`, the 117/118
method), French for row N1 and the File Comparator's *Load on start* for row S1, and restores and
verifies the whole key at the end. Rows C1-C3 hold the clipboard open from the probe for a moment
(nothing is written to it). Rows R1 and L1 perform the installer's Restart Manager request with
`specs\080-restart-manager-upgrade\probe\rm_probe.ps1` (no installer; only processes started from
`-Exe`). Rows P1-P3 connect to `127.0.0.1:1` (nothing listens; no network traffic leaves the
machine). It refuses to run on the user's desktop (`Default`): start it only through the runner.

The builds: `build\tandemcommander\Debug_x64_121` (this build) and
`build\tandemcommander\Debug_x64_pre121` (HEAD a75b3d8e before the change, = the 120 build).

```powershell
Set-Location D:\Projects\tandemcommander
if (Get-Process tandemcommander -ErrorAction SilentlyContinue) { throw 'close every Tandem Commander first' }
function RegHash { reg export "HKCU\Software\Tandem Commander" "$env:TEMP\tc121_reg.reg" /y | Out-Null; (Get-FileHash "$env:TEMP\tc121_reg.reg").Hash.Substring(0, 16) }
$P = 'D:\Projects\tandemcommander\specs\121-small-batch\probe'
$E = 'build\tandemcommander\Debug_x64_121\tandemcommander.exe'
$B = 'build\tandemcommander\Debug_x64_pre121\tandemcommander.exe'
RegHash
```

1. This build and the build before (about 10 minutes each):

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_121.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\121-small-batch\probe\batch121_probe.ps1 -Exe $E -Expect fixed -RegBaseline 1AB614304771DBE0 -OutFile $P\batch121_result.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_pre121.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\121-small-batch\probe\batch121_probe.ps1 -Exe $B -Expect before -RegBaseline 1AB614304771DBE0 -OutFile $P\batch121_result_pre121.txt"
RegHash
```

Expected on this build: every row PASS (each with its END row); N1 INFO only on a system whose code
page holds the French text (it is NOT CP1250); C1-C3 NOT DRIVEN only if the probe could not hold the
clipboard AND the program copied; R1 / L1 NOT DRIVEN if the plug-in key had no `Menu` subkey (the
hot key could not be set - run the plug-in once). On the build before: F1, M1, C1-C3, N1, K1, D1,
P1, P2, R1, L1 PASS as "before" (the old behaviour shown), F2, F3, S1 INFO (reported; the S1 race is
timing-dependent - a "rejected to unload" box in any round is the defect).

Single rows: `-Only F1,M1` (prefixes: `-Only C`).

2. Regressions on this build (unchanged probes):

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_101.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\101-small-leftovers\probe\leftovers_probe.ps1 -Exe $E -OutFile $P\leftovers101_on121.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_102.log" -WaitSeconds 7200 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\102-filecomp-unicode-names\probe\filecomp_probe.ps1 -Exe $E -OutFile $P\filecomp102_on121.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_117.log" -WaitSeconds 1800 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\117-checksum-lists\probe\csumlist_probe.ps1 -Exe $E -Expect fixed -OutFile $P\csumlist117_on121.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_118.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\118-plugin-update-close\probe\update_close_probe.ps1 -Exe $E -Expect fixed -RegBaseline 1AB614304771DBE0 -OutFile $P\update_close118_on121.txt"
RegHash
```

Expected: as their own builds; 117's Save rows now find the Save dialog in the panel's folder
(item 12 - it opened another program's last folder). Note for 101: its Find-window rows search from a short parent
because the Look in field used to cut the panel path - they still pass; its "unc" rows copy to the
clipboard and may now show the clipboard's error box where the clipboard cannot be opened (101
recorded "OpenClipboard fails here") - read such a row's windows before calling it a regression.

## By hand (a person, optional)

- Any plug-in folder picker (e.g. Undelete's *Restore to*, CAB's target): pick a folder under
  *Network shortcuts* (a NetHood folder shortcut) - the plug-in gets the folder it points at; pick
  *This PC* or a control-panel item - OK is disabled.
- FTP: open a connection whose server sends a welcome message (the message window), then start an
  update (or `rm_probe.ps1 -ExePath <exe>`) - it closes; with the panel still connected the update
  declines (as before, 080 D7).
