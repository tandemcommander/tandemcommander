# Quickstart: feature 117 - GUI runs pending

Automated (hidden desktop). Preconditions: no `tandemcommander.exe` running (also not the installed
one - every probe shares `HKCU\Software\Tandem Commander` with it); Python 3 on PATH (standard
library only). The probe writes its fixtures under `%TEMP%\tc117_cs` and removes them; inside the
window in which it has exported `HKCU\Software\Tandem Commander` it gives the Checksum plug-in's
Calculate the key Ctrl+Shift+U and Verify Ctrl+Shift+V (`Plugins\<n>\Menu\<m>\HotKey`, as 115 did
for Undelete) and restores and verifies the whole key at the end. No network mapping is used or
touched (A:, O:, S:, Z: stay as they are). It refuses to run on the user's desktop (`Default`):
start it only through the runner. The runner's log (`-Log`) is UTF-16; the result files
(`-OutFile`) are ASCII. The `rt` rows also run `sha256sum.exe` of Git for Windows and `7z.exe`
of 7-Zip when installed (NOT DRIVEN otherwise).

The builds: `build\tandemcommander\Debug_x64_117` (the maintainer's copy of this build) and
`build\tandemcommander\Debug_x64_pre117` (HEAD 47ad7fd6 before the change, = the 116 build).
`-Exe` is a parameter; nothing below depends on `Debug_x64`.

Run from the repository root in Windows PowerShell, each command wrapped by the registry check
(the export's SHA-256 must be the same before and after - `9BD42518403B7EDF...` on 2026-10-05):

```powershell
Set-Location D:\Projects\tandemcommander
if (Get-Process tandemcommander -ErrorAction SilentlyContinue) { throw 'close every Tandem Commander first' }
function RegHash { reg export "HKCU\Software\Tandem Commander" "$env:TEMP\tc117_reg.reg" /y | Out-Null; (Get-FileHash "$env:TEMP\tc117_reg.reg").Hash.Substring(0, 16) }
$P = 'D:\Projects\tandemcommander\specs\117-checksum-lists\probe'
$E = 'build\tandemcommander\Debug_x64_117\tandemcommander.exe'
$B = 'build\tandemcommander\Debug_x64_pre117\tandemcommander.exe'
RegHash
```

1. The probe on this build and on the build before 117 (a few minutes each; one instance for the
   16 lists, one for the round trip):

```powershell
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_117.log" -WaitSeconds 1800 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\117-checksum-lists\probe\csumlist_probe.ps1 -Exe $E -Expect fixed -OutFile $P\csumlist_result.txt"
RegHash
powershell -File tools\run_on_hidden_desktop.ps1 -Log "$P\run_pre117.log" -WaitSeconds 1800 -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\117-checksum-lists\probe\csumlist_probe.ps1 -Exe $B -Expect before -OutFile $P\csumlist_result_pre117.txt"
RegHash
```

Single parts: `-Only <list file name>` (e.g. `-Only cp1250_setcontent.sha256`), `-Only lists`
(all 16), `-Only rt` (comma-separated for several). Another python: `-Python <path>`.

2. Without the GUI (any time): the offline model of the read path on the product's helper over
   the same fixtures - `cmd /c specs\117-checksum-lists\probe\build_model.cmd` (needs Visual
   Studio; expected "model rows: 58, mismatches: 0").

## Expected

This build (`-Expect fixed`): 82 rows - every row PASS, except a `rt GNU` / `rt 7ZIP` row NOT
DRIVEN where that tool is missing. Every list's `LIST` row PASS with "boxes 0"; each instance's
END row PASS (exit 0, no stray window, no new crash report).

- `utf8.sha256` (the control): 8 x OK, voila-grave and voila each OK (never the other).
- `utf8bom.sha256`, `ps_utf16le.sha256`, `utf16be.md5`, `utf16le_nobom.sha1`, `concat.sha256`,
  `gnu_escape.sha256`: every row OK.
- `cp1250_setcontent.sha256`: c-caron OK, `a b` OK, `voila.txt` CORRUPT (the writer's best fit -
  the list names the decoy; never matched back to voila-grave), `???.txt` MISSING (not `abc.txt`),
  `sub\r-caron` OK.
- `opensal.sfv`: 3 x OK. `oem852.md5`: the OEM name MISSING (shown `z-acute e c-cedilla tina`),
  `a b` OK.
- `dotslash.sha256`: 5 x OK (`./`, `./sub/`, `sub/../`, `sub//`, `../data/`).
- `broken_utf8bom.sha256`: OK, MISSING (`voil<U+FFFD>.txt`), OK.
- `wild.sha256`: `voil?.txt` MISSING, `sub` MISSING, CJK OK.
- `absolute.sha256`: the absolute name on the list's own drive OK; another drive,
  `//127.0.0.1/...` and `\\?\UNC\...` MISSING (never looked up - no connection; the probe cannot
  observe a connection, saltests and the model prove the refusal), the stream `...:secret`
  MISSING, CJK OK.
- `nul_tail1.sha256`, `nul_tail11.sha256` (trailing NUL padding): 2 x OK each.
- `rt SAVE-sha256`: no mark, CR 0, no comment header, 7 checksum lines; `rt SAVE-sfv`: CRLF and
  the `;` header; `rt VERIFY-*`: 7 x OK; `rt GNU`: `sha256sum -c` exit 0, 7 OK lines; `rt 7ZIP`:
  Everything is Ok.

The build before (`-Expect before`): 60 rows, every row PASS (each one shows the old behaviour):
`utf8.sha256` 8 x OK (the control); the marked UTF-8, UTF-16, GNU-escaped, concatenated and broken
lists refused ("not a checksum file" box); `cp1250_setcontent` c-caron and r-caron MISSING,
`???.txt` SKIPPED after an error box (the wildcard found another file); `opensal.sfv` the accented
names MISSING; `dotslash` 5 x MISSING; `absolute` the own-drive name MISSING (joined to the folder), the
rest MISSING, CJK OK; `nul_tail*` 2 x OK each; `wild` `voil?.txt` and `sub` SKIPPED after error boxes;
`rt SAVE-sha256` CRLF + header, `rt GNU` and `rt 7ZIP` fail, `rt VERIFY-*` 7 x OK.

A FAIL row on this build is a defect (or a probe defect - check its facts: the name shown, the
icon, the status text, the boxes). Record the results in `fix-log.md` (T013) and the NEXT-WORK
entry.
