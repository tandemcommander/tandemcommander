# Quickstart: feature 114 - GUI runs pending

Automated (hidden desktop). Preconditions: no `tandemcommander.exe` running (also not the installed
one - every probe shares `HKCU\Software\Tandem Commander` with it); Python 3 (the image generator,
standard library only). The probe writes its fixtures under `%TEMP%\tc114_un` (three disk images -
ordinary files; no volume is opened, no admin rights are needed) and removes them at the end. No
network mapping is used or touched (A:, O:, S:, Z: stay as they are). The probe refuses to run on
the user's desktop (`Default`): start it only through the runner. The runner's own log (`-Log`) is
UTF-16; the result files (`-OutFile`) are ASCII. The probe backs up, restores and verifies
`HKCU\Software\Tandem Commander` itself.

The builds: `build\tandemcommander\Debug_x64_114` (the maintainer's copy of this build) and
`build\tandemcommander\Debug_x64_pre114` (HEAD 508e9910 before the change). `-Exe` is a parameter;
nothing below depends on `Debug_x64`.

Run from the repository root in Windows PowerShell, each command wrapped by the registry check (the
export's SHA-256 must be the same before and after - `1AB614304771DBE0...` at the time of 110-113):

```powershell
Set-Location D:\Projects\tandemcommander
if (Get-Process tandemcommander -ErrorAction SilentlyContinue) { throw 'close every Tandem Commander first' }
function RegHash { reg export "HKCU\Software\Tandem Commander" "$env:TEMP\tc114_reg.reg" /y | Out-Null; (Get-FileHash "$env:TEMP\tc114_reg.reg").Hash.Substring(0, 16) }
$P = 'D:\Projects\tandemcommander\specs\114-undelete-names\probe'
$E = 'build\tandemcommander\Debug_x64_114\tandemcommander.exe'
$B = 'build\tandemcommander\Debug_x64_pre114\tandemcommander.exe'
RegHash
```

1. The new probe on this build and on the build before 114 (a few minutes each):

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_114.log" -WaitSeconds 1800 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\114-undelete-names\probe\undelnames_probe.ps1 -Exe $E -Expect fixed -OutFile $P\undelnames_result.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_pre114.log" -WaitSeconds 1800 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\114-undelete-names\probe\undelnames_probe.ps1 -Exe $B -Expect before -OutFile $P\undelnames_result_pre114.txt"
RegHash
```

Single rows: `-Only fat`, `-Only exfat`, `-Only dup`.

2. Regression on this build - 104's Undelete row (the connect dialog's image field):

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_regress104.log" -WaitSeconds 1800 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\104-plugin-unicode-names\probe\plugnames_probe.ps1 -Exe $E -Expect fixed -Only und-image -OutFile $P\regress_plugnames104_114.txt"
RegHash
```

## Expected

This build (`-Expect fixed`): every row PASS; four NOT DRIVEN rows (NTFS, mount points, the volume
list, Restore Encrypted Files).

- `fat`: 13 files restored under exactly their names with their content - `<C-caron>lanek.txt`,
  `<C-caron>91D~1.TXT` (deleted `<U+597D>.txt` with the hash-form short name `191D~1.TXT`: its
  long name cannot be linked back - asked for), `<C-caron>AA.TXT`, `<C-caron>OO.TXT` (root);
  `<U+5F00><U+59CB>x.txt` (short name `X76F3~1.TXT`),
  `a<U+597D>.txt`, `<Z-caron>lu<t-caron>ou<c-caron>k<y-acute> k<u-ring><n-caron>.txt` (deleted-dir); `<U+5A46>.txt`,
  `<OEM 0xE5>BC.TXT` (n-caron on CP852), `<C-caron>L<A-acute>NEK2.TXT`, `readme.txt`, `mixed.TXT`,
  `lone<U+D800>y.txt` (lost-dir). PROMPTS: exactly one Damaged Filename dialog, `$91D~1.TXT`
  (All then names `$AA.TXT` and `$OO.TXT`). EXTRA: none.
- `exfat`: 6 files under exactly their names, no prompt.
- `dup`: "Target path is too long" twice (Skip), nothing written, no fatal window.

The build before (`-Expect before`) - a row PASSes when the old defect shows exactly where
predicted (expected.json `defect_before`):

- `fat`: wrong / missing - `<C-caron>lanek.txt` (long name lost: the ANSI byte 0xC8 is not the OEM
  0xAC), `<U+5F00><U+59CB>x.txt` (long name lost: '?' instead of 'X'),
  the Zlutoucky name (0x8E vs 0xA6), `<U+5A46>.txt` (listed `$` + mojibake, asked for),
  `<n-caron>BC.TXT` (0x05 escape listed as `$`, asked for), `<C-caron>L<A-acute>NEK2.TXT` (OEM bytes
  as UTF-8), `mixed.TXT` (restored `mixed.txt`), `lone<U+D800>y.txt` (U+FFFD); right -
  `a<U+597D>.txt`, `readme.txt`, `<C-caron>91D~1.TXT`, `<C-caron>AA.TXT`, `<C-caron>OO.TXT`.
  PROMPTS: more than one (every
  name that began with 0xE5, and "All" never remembered `<C-caron>`).
- `exfat`: wrong - `<U+597D>.txt`, `<U+5F00><U+59CB>.txt` (asked for, garbled),
  `lone<U+D800>x.txt`; right - the other three. PROMPTS: at least one.
- `dup`: a fatal window ("Stack around the variable 'temp' was corrupted" - the Debug build's
  run-time check); its END row FAILs (the control).
- END rows of `fat` / `exfat` may FAIL on the build before if the garbled names make the core
  assert; recorded, not a 114 defect.

## By hand (person, administrator, a spare volume)

Mount points cannot be created without admin rights; the W volume layer is verified by code
reading and saltests. To see it end to end (Release build, an elevated prompt for `mountvol` only):

1. `mkdir C:\mnt\voil<U+00E0>` (Explorer), then in an elevated prompt
   `mountvol C:\mnt\voil<U+00E0> \\?\Volume{...}\` with the GUID of a spare volume (a USB stick).
2. Start Tandem Commander **as administrator** (raw volume access needs it), Ctrl+Shift+U: the
   volume list shows `C:\mnt\voil<U+00E0>` exactly (the build before: `voila` or mojibake), with the
   volume's label.
3. Choose it, OK: the panel shows `del:C:\mnt\voil<U+00E0>\` and the USB stick's deleted files (the
   build before: the deleted files of `C:` under that path, or an error).
4. With the left panel inside `C:\mnt\voil<U+00E0>\sub`, connect again and choose the same volume:
   the panel path is kept and the USB volume opened.
5. `mountvol C:\mnt\voil<U+00E0> /D`.
