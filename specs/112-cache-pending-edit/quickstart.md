# Quickstart: feature 112

Automated (hidden desktop). Preconditions: no `tandemcommander.exe` running (also not the installed
one - every probe shares `HKCU\Software\Tandem Commander` with it); Python 3 and 7-Zip
(`C:\Program Files\7-Zip\7z.exe`) for `specs/108-archive-edit-name-collision/probe/arcfix.py`. The
new probe creates and removes a `net use` drive (first free of W, Y, X, to `\\localhost\C$\...`) for
its `@net` rows; existing mappings (A:, O:, S:, Z:, ...) are never touched, and a mapping the probe
made that turns out unreachable is removed before the next letter is tried. `\\localhost\C$` was
used without elevation by the 103/107/109 probes; if it is not reachable here, the `@net` rows come
out NOT DRIVEN ("no evidence either way") - report them as not driven, never as evidence. The probe
refuses to run on the user's desktop (`Default`): start it only through the runner. The runner's own
log (`-Log`) is UTF-16; the result files (`-OutFile`) are ASCII.

Run from the repository root in PowerShell, each command wrapped by the registry check (the export's
SHA-256 must be the same before and after - `1AB614304771DBE0...` at the time of 109/111):

```powershell
Set-Location D:\Projects\tandemcommander
if (Get-Process tandemcommander -ErrorAction SilentlyContinue) { throw 'close every Tandem Commander first' }
function RegHash { reg export "HKCU\Software\Tandem Commander" "$env:TEMP\tc112_reg.reg" /y | Out-Null; (Get-FileHash "$env:TEMP\tc112_reg.reg").Hash.Substring(0, 16) }
$P = 'D:\Projects\tandemcommander\specs\112-cache-pending-edit\probe'
RegHash
```

1. The new probe on this build and on the build before 112:

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_112.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\112-cache-pending-edit\probe\diskcache_edit_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after-112 -OutFile $P\diskcache_edit_result.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_pre112.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\112-cache-pending-edit\probe\diskcache_edit_probe.ps1 -Exe build\tandemcommander\Debug_x64_pre112\tandemcommander.exe -Label pre-112 -OutFile $P\diskcache_edit_result_pre112.txt"
RegHash
```

2. Regressions on this build:

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_regress109.log" -WaitSeconds 2400 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\109-disk-cache-archive-key\probe\diskcache_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile $P\regress_diskcache109_112.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_regress108.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\108-archive-edit-name-collision\probe\namecoll_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile $P\regress_namecoll108_112.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_regress108ck.log" -WaitSeconds 1800 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\108-archive-edit-name-collision\probe\namecoll_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -CacheKeyRows -OutFile $P\regress_cachekey108_112.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_regress096.log" -WaitSeconds 2400 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\096-archive-edit-accented\probe\archedit_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -OutFile $P\regress_archedit096_112.txt"
RegHash
```

Expected:

| Probe | This build | `Debug_x64_pre112` |
|---|---|---|
| `diskcache_edit_probe` loss rows `own-F3`, `own-F4`, `own-F3_7z`, `ext-ctrlR`, `ext-x` and their `@net` variants | PASS | FAIL (F3 given x without the edit / tag 9; L's leave offers nothing; x without the edit) - or CLOSED on both builds when the left panel refreshed anyway (activation); then the `@net` variants carry the evidence |
| `own-reenter`, `shared` | PASS | PASS (`own-reenter`: 109's unique key; `shared`: both edits either way) |
| `stamp-race` | PASS | PASS or FAIL (a race: the `cmd` editor against the stamp read after the launch) |
| controls `own-F3-auto`, `ext-ctrlR-auto` | PASS (L reopened first) | PASS |
| 109 diskcache | 18 / 0 | (109: 18 / 0) |
| 108 namecoll / `-CacheKeyRows` | 30 / 0 (the two ZIP plug-in rows fixed by 110) / 2 / 0 | (110's records) |
| 096 archedit | 17 of 17 UPDATED | 17 of 17 |

A row that does not FAIL on `Debug_x64_pre112` is not evidence for the fix (CLOSED rows are not
evidence either way).

By hand (Release build, real keyboard, Notepad; Configuration > Drives: uncheck automatic refresh
for fixed drives, or use an archive on a network share with automatic refresh off):
1. Both panels on one `t.zip` with `x.txt` and `y.txt`. Left: F4 on `x.txt`, add a line, save,
   close Notepad. Right: F4 on `y.txt`, add a line, save, close; Backspace, *Update*.
2. Left: F3 on `x.txt` - the viewer shows the added line (before 112: the original text). Backspace:
   the Archive Update dialog lists `x.txt` (before 112: nothing was offered and the line was lost).
3. Again with Ctrl+R in the right panel after updating `t.zip` with another program instead of step 1's
   right-panel edit: the same result.
