# Quickstart: feature 113

Run on 2026-10-06 - results in `fix-log.md` ("GUI results"): this build 37 / 0 / 0, the build
before 11 / 26 / 0 (the predicted rows), regressions as before.

Automated (hidden desktop). Preconditions: no `tandemcommander.exe` running (also not the installed
one - every probe shares `HKCU\Software\Tandem Commander` with it); Python 3 with `cryptography`
(AES members, as for 094); 7-Zip (`C:\Program Files\7-Zip\7z.exe`) for the 7z rows. The probe holds
source files open / range-locked itself (its own process, released at the end of each row) and
creates its fixtures under `%TEMP%\tc113` (`-Scratch` moves them); a 128 MB random file is written
for the two progress rows. No network mapping is used or touched (A:, O:, S:, Z: stay as they are).
The probe refuses to run on the user's desktop (`Default`): start it only through the runner. The
runner's own log (`-Log`) is UTF-16; the result files (`-OutFile`) are ASCII. It backs up, restores
and verifies `HKCU\Software\Tandem Commander` itself.

The builds: `build\tandemcommander\Debug_x64_113` (the maintainer's preserved copy of this build)
and `build\tandemcommander\Debug_x64_pre113` (HEAD 18dad50c before the change). `-Exe` is a
parameter; nothing below depends on `Debug_x64`.

Run from the repository root in Windows PowerShell, each command wrapped by the registry check (the
export's SHA-256 must be the same before and after - `1AB614304771DBE0...` at the time of 110-112):

```powershell
Set-Location D:\Projects\tandemcommander
if (Get-Process tandemcommander -ErrorAction SilentlyContinue) { throw 'close every Tandem Commander first' }
function RegHash { reg export "HKCU\Software\Tandem Commander" "$env:TEMP\tc113_reg.reg" /y | Out-Null; (Get-FileHash "$env:TEMP\tc113_reg.reg").Hash.Substring(0, 16) }
$P = 'D:\Projects\tandemcommander\specs\113-zip-read-error-skip\probe'
$E = 'build\tandemcommander\Debug_x64_113\tandemcommander.exe'
$B = 'build\tandemcommander\Debug_x64_pre113\tandemcommander.exe'
RegHash
```

1. The new probe on this build and on the build before 113 (about 15 minutes each):

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_113.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\113-zip-read-error-skip\probe\zipskip_probe.ps1 -Exe $E -Label after-113 -OutFile $P\zipskip_result.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_pre113.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\113-zip-read-error-skip\probe\zipskip_probe.ps1 -Exe $B -Label pre-113 -OutFile $P\zipskip_result_pre113.txt"
RegHash
```

Single rows: `-Only t_open,i_` (name prefixes).

2. Regressions on this build:

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_regress110.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\110-zip-plugin-name-matching\probe\zipname_probe.ps1 -Exe $E -Label after-113 -OutFile $P\regress_zipname110_113.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_regress106.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\106-zip-overwrite-source\probe\packself_probe.ps1 -Exe $E -Label after-113 -OutFile $P\regress_packself106_113.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_regress094.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\094-plugin-password-encoding\probe\zip_gui_probe.ps1 -Exe $E -Label after-113 -OutFile $P\regress_zip094_113.txt"
RegHash
```

## Expected

This build (`zipskip_result.txt`): every row PASS. `t_progress` / `i_progress` are NOT DRIVEN if the
packing of the 128 MB file ends before the probe's cancel (no evidence either way - report as not
driven). The 7z rows are NOT DRIVEN without 7-Zip.

The build before (`zipskip_result_pre113.txt`), predicted from the code (`research.md` 2, 5) - the
run decides:

| rows | predicted on the build before |
|---|---|
| `t_open_skip`, `t_open_skipall`, `t_read_skip`, `t_read_skipall`, `t_two`, `t_three`, `t_move`, `t_zip64`, `t_zc`, `t_aes`, `t_desc`, `t_unix` | FAIL - the replaced member(s) gone |
| `t_open_cancel`, `t_read_cancel`, `t_open_retry`, `t_normal`, `t_new_skip`, `t_progress` | PASS (temporary copy: an error or cancel discards it) |
| `e_aes_new_skip`, `e_aes_repl` | FAIL - the partly read file stored as complete (`x.txt=CORRUPT`) |
| `e_aes_new_cancel` | FAIL - Cancel did not end the operation (`x.txt=CORRUPT`, `other.txt` added) |
| `e_aes_move` | FAIL - and `x.txt` deleted from disk |
| `e_zc_new_skip` | PASS (ZIP 2.0 has no MAC) |
| `i_normal`, `i_two`, `i_zip64` | PASS (ordinary in-place replacement) |
| `i_open_skip`, `i_read_skip`, `i_open_cancel`, `i_read_cancel`, `i_mixed`, `i_move`, `i_progress`, `i_aes_new_skip` | FAIL - in-place: the member gone also on Cancel / a cancelled progress |
| `s_repl` | FAIL - Skip offered, `x.txt` gone |
| `s_repl_retry` | PASS |
| `s_move_new` | FAIL - `n.txt` deleted from disk although it was not packed |

Regressions: 110 zipname 42 / 0, 106 packself PASS 70 / FAIL 0 / NOT DRIVEN 4, 094 ZIP AS EXPECTED 56
/ DIFFERENT 1 (X1, the self-extractor row that cannot be driven in a Debug tree) - the records of
110.

## By hand (Release build, a real mouse and keyboard)

1. Make a ZIP holding `x.txt` and `y.txt`. Open `x.txt` in a program that keeps it open for writing
   (or lock it: `$f=[IO.File]::Open('<full path>\x.txt','Open','ReadWrite','ReadWrite')` in a
   PowerShell window; `$f.Dispose()` releases it). F5 `x.txt` and another file into the archive, *Yes* to the overwrite question, *Skip*
   to the error: the archive still holds `x.txt` with its old content, the other file is added.
2. The same with ZIP options -> "Use temporary copy of archive for its modifications" OFF: the same
   result; and with *Cancel* to the error: the archive is unchanged.
3. A 7z archive holding `x.txt`, `x.txt` locked: the error offers *Retry* and *Cancel* only.
