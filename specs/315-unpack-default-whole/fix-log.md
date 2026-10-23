# Fix log - 315-unpack-default-whole

Backlog item `unpack-dialog-offers-a-long-target-panel-path-cut-and` (source review:299).

## Measured before (main at 32718c27)

Build: `build.cmd` (Debug x64, incremental) - BUILD SUCCEEDED. Probe `probe/unpack315_probe.ps1`
(new; driver of 299's probe with 098's library; the combo items read with CB_GETLBTEXT; the settings
"Use Another Panel" (UA) / "Use Subdir Name By Archive" (SD) of `Packers & Unpackers\Custom
Unpackers` written per row, the registry backed up and restored - identical hash):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\unpack315_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1"
```

Result `probe/result_before.txt` + `probe/result_before_src.txt`: 6 FAIL, 3 controls PASS.

| Row | Setting | Seen |
|---|---|---|
| other-ascii | UA=1, L 297 bytes | item 0 = 259-byte prefix of L; OK -> a.k / a.kp in a new cut folder, nothing asked. FAIL |
| other-cjk | UA=1, L 355 bytes CJK | item 0 cut inside a letter, shown through the code page (476 bytes of garbage); OK -> "too long" (299). FAIL |
| alt-ascii | UA=0, item 1 | 259-byte prefix; unpacked into a new cut folder. FAIL |
| alt-cjk | UA=0, item 1 | 259-byte prefix; unpacked into the cut folder. FAIL |
| subdir | UA=1 SD=1, L 245, name 20 letters | item 0 = L (subfolder dropped); unpacked straight into L. FAIL |
| src-long | archive in a 297-byte folder, UA=0, the empty item | `lstrcpyn(path, GetPath(), MAX_PATH)`: unpacked into a new cut folder. FAIL |
| ctl / ctl-alt / ctl-subdir | L 200 / 250 CJK / 200 + `\a` | offered whole, unpacked there. PASS |

Probe traps met while writing it: `@($a + 'x', $b + 'y')` - the comma binds tighter than `+` in
PowerShell (the controls failed on the probe itself until parenthesized); a Bash heredoc collapsed
the doubled backslashes of a Python fix-up (CLAUDE.md 123) - edited with the editor instead.

## Sites and consumers (fix protocol)

`CFilesWindow::Unpack` (`src/fileswn7.cpp`): the other panel's path into `path` / `pathAlt`, the
subfolder append, the plug-in mask, the empty-target fallback after OK. Callers: `CM_UNPACK`
(`src/mainwnd3.cpp`) and the plug-in request (`src/salamdr1.cpp`, mask from
`PostOpenUnpackDlgForThisPlugin`, `src/zip.cpp`; no plug-in of the tree passes a mask - only
`demoplug`, commented, NULL). Readers of the buffers: `CUnpackDialog` (Transfer; 299's Validate),
`SalGetFullName` (refuses a too-long relative result itself), `CheckAndCreateDirectory`,
`ExecuteUnpacker`, `PostChangeOnPathNotification`. None needs a non-empty default.

## Analyze

No CRITICAL / HIGH. U1 (LOW, fixed): `nameLen == 0` keeps the buffer, TRUE. C1 (LOW, accepted):
FR-006 "no new string" is proved by the build (no `.rc2` change). I1 (LOW, accepted): the
`UserWorkedOnThisPath` mark stays as before.

## Implementation

- `src/common/salunpackdefault.h` (new): `SalUnpackDefaultCopy` (whole or empty) and
  `SalUnpackDefaultAddSubdir` (path + `\` + name whole; else the path left out and the name alone -
  a subfolder next to the archive, what an entry without a path gets - or empty when even the name
  does not fit).
- `CFilesWindow::Unpack` (`src/fileswn7.cpp`): the other panel's path into `path` / `pathAlt` whole
  or left out; the subfolder by the rule; a plug-in mask whole or `*.*` (`TRACE_E`); the empty target
  after OK: the archive panel's path whole or `IDS_TOOLONGPATH` (the existing message box and
  `goto DO_AGAIN`). The subfolder length is capped at `strlen(fileName)` (never past the altered
  name).
- First version emptied an entry whose path + subfolder did not fit: the after probe passed, but
  row `subdir` showed a.k unpacked straight next to the archive - the setting ignored. Changed to
  the name alone (clarification 2 says the setting is kept); the probe row now also checks where OK
  unpacked (`<src>\<name>\a.k`).

## Checks

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `.\build.cmd` | `BUILD SUCCEEDED` |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 27429 checks, 0 failed` (the 280-style rows of `TestUnpackDefault315`) |
| negative control | the header made to cut (`lstrcpynA`) and keep the bare path, saltests rebuilt | `27428 checks, 8 failed` (the 260 / 297 / CJK 260 / 355 / mask / subfolder rows); header restored, rebuilt, 0 failed. Run on the first version (before the name-alone change); the bare path the control keeps fails the changed subfolder rows the same way |
| probe after | `probe/unpack315_probe.ps1 -Label after` (hidden desktop) | `probe/result_after.txt`: 9 rows PASS (18 PASS lines with END), 0 FAIL; registry restored, identical hash |
| probe before (negative control of the probe) | the same probe on the build of main 32718c27 | 6 FAIL (other-ascii, other-cjk, alt-ascii, alt-cjk, subdir, src-long), controls PASS |
| regression | 299's `unpack299_probe.ps1` | `probe/regress_299.txt`: 12 / 0 |

The plug-in mask site is not driven by a probe (no plug-in of the tree passes a mask): saltests rows
and reading only.
