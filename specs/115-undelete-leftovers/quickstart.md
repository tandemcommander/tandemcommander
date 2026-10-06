# Quickstart: feature 115 - GUI runs pending

Automated (hidden desktop). Preconditions: no `tandemcommander.exe` running (also not the installed
one - every probe shares `HKCU\Software\Tandem Commander` with it); Python 3 (the image generator,
standard library only; it imports 114's `make_images.py`). The probe writes its fixtures under
`%TEMP%\tc115_un` (three disk images - ordinary files, no volume is opened, no admin rights - and
plain folders for Restore Encrypted Files, one with a directory junction made by `mklink /J`, which
needs no admin) and removes them at the end (the junction with `rmdir`, the link only). It writes
no `.bak` file, so nothing reaches the EFS import: no EFS key or certificate is used or created; it
refuses the encrypted rows when the fixture folder is encrypted and reports the number of the
user's EFS certificates before and after (row `enc EFS`). No network mapping is used or touched
(A:, O:, S:, Z: stay as they are). The probe refuses to run on the user's desktop (`Default`):
start it only through the runner. The runner's own log (`-Log`) is UTF-16; the result files
(`-OutFile`) are ASCII. The probe backs up, restores and verifies `HKCU\Software\Tandem Commander`
itself; inside that window it gives the Undelete plug-in's *Restore Encrypted Files from Backup*
the key Ctrl+Shift+U (the command has no key and the probe cannot open plug-in menus).

The builds: `build\tandemcommander\Debug_x64_115` (the maintainer's copy of this build) and
`build\tandemcommander\Debug_x64_pre115` (HEAD b06ff2b9 before the change, = the 114 build).
`-Exe` is a parameter; nothing below depends on `Debug_x64`.

Run from the repository root in Windows PowerShell, each command wrapped by the registry check (the
export's SHA-256 must be the same before and after - `1AB614304771DBE0...` at the time of 110-114):

```powershell
Set-Location D:\Projects\tandemcommander
if (Get-Process tandemcommander -ErrorAction SilentlyContinue) { throw 'close every Tandem Commander first' }
function RegHash { reg export "HKCU\Software\Tandem Commander" "$env:TEMP\tc115_reg.reg" /y | Out-Null; (Get-FileHash "$env:TEMP\tc115_reg.reg").Hash.Substring(0, 16) }
$P = 'D:\Projects\tandemcommander\specs\115-undelete-leftovers\probe'
$E = 'build\tandemcommander\Debug_x64_115\tandemcommander.exe'
$B = 'build\tandemcommander\Debug_x64_pre115\tandemcommander.exe'
RegHash
```

1. The new probe on this build and on the build before 115 (a few minutes each):

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_115.log" -WaitSeconds 1800 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\115-undelete-leftovers\probe\undelleft_probe.ps1 -Exe $E -Expect fixed -OutFile $P\undelleft_result.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_pre115.log" -WaitSeconds 1800 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\115-undelete-leftovers\probe\undelleft_probe.ps1 -Exe $B -Expect before -OutFile $P\undelleft_result_pre115.txt"
RegHash
```

Single rows: `-Only fat`, `-Only exfat`, `-Only view`, `-Only enc-deep`, `-Only enc-long`,
`-Only enc-loop` (comma-separated for several).

2. Regression on this build - 114's probe (the same plug-in, the same images route):

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_regress114.log" -WaitSeconds 1800 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\114-undelete-names\probe\undelnames_probe.ps1 -Exe $E -Expect fixed -OutFile $P\regress_undelnames114_115.txt"
RegHash
```

## Expected

This build (`-Expect fixed`): every row PASS; two NOT DRIVEN rows (real EFS backups; NTFS / EFS
deleted files).

- `fat` (fatdup115.ima, {All Deleted Files} restored with F5): `dupe` - one `dupe.txt`; `tiny` -
  `same (1).txt` and `same (2).txt` with the two different contents; `caron` -
  `<C-caron> (k).txt` and `<c-caron> (k).txt` (k = 1 and 2, either way round, each with its own
  content); EXTRA none; PROMPTS - no overwrite prompt; END PASS.
- `exfat` (exfatnum115.ima): `caron` as above (numbered by the restore list), `ascii` -
  `a (k).txt` / `A (k).txt`; no overwrite prompt.
- `view` (expectation corrected by GUI run 1): one message "The resulting filename is too long" -
  the core's disk cache refuses a temporary name of MAX_PATH+ bytes before the plug-in copies
  anything; no fatal window, no file. The same on the build before.
- `enc-deep`: 16 files under the same relative paths (deepest ~650 bytes), no message, none
  encrypted. `enc-long`: `x.txt` and `sub\y.txt`. `enc-loop`: `loop\a.txt`, `loop\b\c.txt`, exactly
  one message with error (1921) ("The name of the file cannot be resolved by the system",
  answered Skip; the box's name field is drawn by the core and has no window text), no `back` folder in the target. `enc EFS`: certificates before = after.
- If the Ctrl+Shift+U key does not open the Restore dialog, the enc rows say NOT DRIVEN (the
  `Hot key :` line shows what was set) - then the person step below.

The build before (`-Expect before`) - a row PASSes when the defect shows:

- `fat`: `dupe` - `dupe (1).txt` + `dupe (2).txt` (the duplicate kept); `tiny` - ONE `same.txt`
  (the other removed as a "duplicate"); `caron` - one of the two names (overwrite prompt answered
  Skip); PROMPTS - at least one overwrite prompt.
- `exfat`: `caron` - one of the two (overwrite prompt); `ascii` - numbered (the control: both
  builds); PROMPTS - at least one.
- `view`: as on this build (the core refuses the name; the plug-in's cut was unreachable).
- `enc-deep`, `enc-loop`: a fatal window or the process ends (stack overflow in `GetDirSize`);
  their END rows FAIL (the control). `enc-long`: files missing (relative names), an error box.

## By hand (person, optional)

- If the probe's key route is NOT DRIVEN: in `Debug_x64_115`, put the left panel on a folder tree
  deeper than 300 bytes (e.g. made by the probe's `enc-deep` fixture code), select its top folder,
  Plugins > Undelete > Restore Encrypted Files from Backup, OK into an empty folder of the right
  panel: everything restored, no message; on `Debug_x64_pre115` the same crashes.
- Real EFS backups need an EFS certificate (a machine where the user already encrypts files):
  undelete an encrypted file to a FAT USB stick (backup form `name.bak`), then restore it with the
  command onto NTFS - the file comes back encrypted under `name`.
