# Quickstart: feature 119 - GUI runs pending

Automated (hidden desktop, Windows PowerShell 5.1). Preconditions: no `tandemcommander.exe`
running (also not the installed one - the probe shares `HKCU\Software\Tandem Commander` with it and
refuses to start otherwise); 7-Zip 22+ at `C:\Program Files\7-Zip\7z.exe` (reads every result -
Python's `zipfile` cannot read a split set). The probe writes its fixtures under `%TEMP%\tc119\pk`
and removes them, exports the registry key first, sets the ZIP options it needs (Extended Pack
Options shown, WinZip names, Backup ZIP; the add-to-archive question on, off for two rows) and
restores and verifies the whole key at the end. It holds one source per L row open itself
(FileShare ReadWrite+Delete, for writing) while the program packs.

The builds: `build\tandemcommander\Debug_x64_119` (this build, copied after the last Debug build)
and `build\tandemcommander\Debug_x64_pre119` (HEAD ea528c45 = the 118 build, byte-identical to
`Debug_x64_118`). `-Exe` is a parameter.

Run from the repository root, each command wrapped by the registry check (the export's SHA-256 must
be the same before and after - `9BD42518403B7EDF...`):

```powershell
Set-Location D:\Projects\tandemcommander
if (Get-Process tandemcommander -ErrorAction SilentlyContinue) { throw 'close every Tandem Commander first' }
function RegHash { reg export "HKCU\Software\Tandem Commander" "$env:TEMP\tc119_reg.reg" /y | Out-Null; (Get-FileHash "$env:TEMP\tc119_reg.reg").Hash.Substring(0, 16) }
$P = 'D:\Projects\tandemcommander\specs\119-packing-leftovers\probe'
$E = 'build\tandemcommander\Debug_x64_119\tandemcommander.exe'
$B = 'build\tandemcommander\Debug_x64_pre119\tandemcommander.exe'
RegHash
```

1. The probe on this build and on the build before 119 (about 25 minutes each - 55 instances, 110 RUN + END rows):

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_119.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\119-packing-leftovers\probe\packleft_probe.ps1 -Exe $E -Label 119 -OutFile $P\packleft_result.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_pre119.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\119-packing-leftovers\probe\packleft_probe.ps1 -Exe $B -Label pre119 -OutFile $P\packleft_result_pre119.txt"
RegHash
```

Single rows: `-Only L-,K-exist-add` (prefixes, comma-separated).

2. Regressions on this build (the packing and moving probes of 099, 110, 113):

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_regress099.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\099-move-into-archive-links\probe\linkmove_probe.ps1 -Exe $E -Label 119 -OutFile $P\regress_linkmove_119.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_regress110.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\110-zip-plugin-name-matching\probe\zipname_probe.ps1 -Exe $E -Label 119 -OutFile $P\regress_zipname_119.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_regress113.log" -WaitSeconds 3600 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\113-zip-read-error-skip\probe\zipskip_probe.ps1 -Exe $E -Label 119 -OutFile $P\regress_zipskip_119.txt"
RegHash
```

106's own `packself_probe.ps1` is superseded by this probe (all its rows are here with the 119
expectations); run on this build it would fail exactly one row by design - `A-zip-noask-refused`
expects the "Add or Overwrite?" question twice, and 119 no longer asks it for a selected archive.

## Expected

This build: every RUN and END row PASS ("loss 0" in every row), 5 NOT DRIVEN rows (X-sfx, X-rar,
X-removable, X-drag, X-rename) - plus the three P rows as NOT DRIVEN when the clipboard cannot be
opened from the hidden desktop (098, 101 and 107 found it cannot; then do by-hand step 2b). The
probe refuses to start on the Default / Winlogon desktop (exit 3, nothing touched); so does every
probe that dot-sources `098-long-path-overruns/probe/fix_probe_lib.ps1` (opt-out for a run the
maintainer agreed to watch: `TC_PROBE_ALLOW_VISIBLE_DESKTOP=1`).

| Rows | This build | The build before 119 |
|---|---|---|
| A-* (selected archive, Pack dialog) | refused before any question (`Asked 0`); the box has "Name:" + "Cannot copy/move a file to itself." and the Pack dialog comes back; sources intact | FAIL: the question is asked, the refusal (Overwrite) is a plain box without "Name:" |
| A-zip-unrelated-over | asked once, overwritten, 2 files inside | PASS |
| B-* (Add into a selected archive; also Czech names, the question switched off) | refused as A, the archive unchanged and tests OK | FAIL: ZIP sharing violation (Skip) / 7-Zip packs the old archive inside, Move "Delete Error" |
| C-*, C-hardlink-* | refused by the ZIP plug-in before any overwrite question, no volume created | PASS (106) |
| D-later-* | refused at volume 4, no `a.*` volume left | FAIL: `a.z01`-`a.z03` stay |
| E-decline-vol2 | the question asked, `out\a.z02` intact, no `a.z01` left | FAIL: `a.z01` stays |
| E-decline-vol1 | nothing created | PASS |
| F-*, G-* | packed, 7z tests OK, both files inside (also Czech names) | PASS |
| H-* (F5 / F6 into the selected archive in the right panel; Czech names; the archive inside the selected folder D) | refused ("Copy Error" / "Move Error" with "Name:"), nothing packed or deleted | FAIL: not refused |
| P-zip-cutpaste, P-7z-copypaste, P-zip-cz-cutpaste (copy / cut + paste into the archive the panel changed into - the drag & drop route) | refused ("Move Error" / "Copy Error" with "Name:"), nothing packed or deleted; NOT DRIVEN without a clipboard | FAIL: not refused |
| L-lock-copy, -move, -keep, -cz-move | the error (z9.bin cannot be opened) answered Cancel; no `m.*` volume left; `out\m.z09`, `out\m.txt` intact; sources intact | FAIL: the volumes before the failing one stay |
| L-lock-yes-vol1 | "Overwrite m.z01?" Yes, then the error, Cancel: `m.z01` gone with the set | FAIL: `m.z01` (holding volume data) and later volumes stay |
| K-exist-add, -add-move, -noask, -cz | "Archive of the same file name already exists ... only like a new archive" for k.zip; nothing created; k.zip unchanged (holds only old.bin) | FAIL: `k.z0N` left, k.zip unchanged; with Move the sources are gone (only in the misnamed set) |
| K-exist-over | asked, Overwrite: the set's last volume is k.zip, 2 files inside | PASS |

If an L row shows no error box on either build (`ErrorQ 0`), the plug-in opened the held file
after all - check `Lock-Source`; if the pre-119 build leaves no volume in L rows, the failing file
was reached in volume 1 (raise `a1.bin` in `$lf`).

Regressions: 099 linkmove 24 / 0, 110 zipname 42 / 0 (+ its review rows), 113 zipskip as recorded
in its fix-log - unchanged by 119 (no row packs into a selected archive or multi-volume).

## By hand (Release build, a real mouse and keyboard)

1. Select `src.zip` and `b.txt`, Alt+F5, name `src.zip`, OK: no question; a "Pack" box shows the
   name of `src.zip` and "Cannot copy a file to itself."; the Pack dialog again. The name is
   readable (path ellipsis for a long path).
2. Open `src.zip` in the right panel, select it and `b.txt` on the left, F6: "Move Error" with its
   name; nothing packed, nothing deleted.
2b. Drag & drop and paste (the route the probe may not reach - code review SF4): select `src.zip`
   and `b.txt` on the left, drag them with the mouse onto the right panel showing `src.zip` and
   drop: "Copy Error" with its name, nothing packed. Then select both again, Ctrl+X, go into
   `src.zip` in either panel, Ctrl+V: "Move Error" with its name; both files still in their folder.
   The same with `D` (a folder holding `x.7z`) and `b.txt` dropped onto `D\x.7z`.
3. `out\k.zip` exists: pack a 20 KB file as `out\k.zip`, *Add*, multi-volume 4 KB: the ZIP
   plug-in's "already exists ... only like a new archive" for `k.zip`; no `k.z01`.
4. Not testable here (owed): removable media (a failure deletes only the volume still being
   written, and only while it is that file; Cancel in "insert the next disk" deletes nothing); a
   self-extracting multi-volume archive (no SFX package); the RAR packer (WinRAR); the last
   volume's rename failing at the end (a race).
