# Fix log - 299-unpack-dialog-text-fits

Backlog item `unpack-with-an-external-unpacker-cuts-a-long-target-path-and` (source review:291).

## Measured at 4787b56b (main, before the feature)

Sites at HEAD (found by name): `CUnpackDialog::Transfer` (`src/dialogs3.cpp`) reads
`ti.EditLine(IDE_PATH, Path, MAX_PATH)` and `ti.EditLine(IDE_MASK, Mask, MAX_PATH)`; the core's
`CTransferInfo::EditLine` (`src/common/winlib.cpp`) converts with `SalWToU8Truncate` - cut at a whole
character. `IDE_PATH` is a `CBS_DROPDOWN` combo box filled with `SalComboAddStringU8` only - no
`CB_LIMITTEXT`; `IDE_MASK` is an edit limited by `EditLine` to 259 UTF-16 units. `class CUnpackDialog`
(`src/dialogs.h`) has no `Validate`.

Reachability: Alt+F9 = `CM_UNPACK` (851, `src/mainwnd3.cpp`) on a disk panel ->
`CFilesWindow::Unpack` (`src/fileswn7.cpp`) -> `CUnpackDialog(..., path, pathAlt, mask, ...)` with
`char path[MAX_PATH]`, `char mask[MAX_PATH]`, for EVERY unpacker (the default ZIP plug-in too; the
item's "external unpacker" is not a precondition). The other caller of `Unpack` (`salamdr1.cpp`, a
plug-in's unpack command) goes through the same dialog. No external unpacker was configured.

Build: `.\build.cmd` (Debug x64, 5 s, up to date). Probe written for this item
(`probe/unpack299_probe.ps1`, 291's driver, 098's library), first in the session's scratch folder
with `-Lib` pointing at 098's library, then copied here (BOM, CRLF):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\unpack299_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1"
```

Result `probe/result_before.txt`: rows PASS 7, FAIL 3 (exit 3):
- `path-cjk`: path "<tgt>\" + CJK padded to 258 bytes + "\sub" (128 units / 262 bytes): dialog
  closed, nothing asked, a.k and a.kp unpacked into the 258-byte folder ("\sub" cut away). FAIL.
- `path-ascii`: 262 ASCII characters (the combo box took them): unpacked into the cut folder. FAIL.
- `mask-cjk`: mask 85 CJK + ";*.kp" (90 units / 260 bytes): `m\a.k` unpacked (cut to "...;*.k"). FAIL.
- `ctl` (mask 259 bytes): `c\a.k` only. PASS. `ctl-path` (path 255 bytes, mask `*.k`): `<P255>\a.k`
  only. PASS. 5 END rows PASS. Registry restored identical (SHA-256 34FA77DB...).

`BL verify` recorded (reproduced).

Consumers of the two buffers after the dialog (`CFilesWindow::Unpack`): `SalGetFullName(path)`,
`CheckAndCreateDirectory(path)`, `UnpackerConfig.ExecuteUnpacker(..., mask, path, ...)`, the
`DO_AGAIN` loop that re-opens the dialog with `path` / `mask`. All take what the dialog stored; none
re-reads the dialog. The dialog's only reader of the fields is `Transfer` (ttDataFromWindow), run
by winlib's OK handling after `ValidateData()` (`CDialog::DialogProc`, `IDOK`).

## speckit-analyze

Run 1: no CRITICAL, no HIGH. MEDIUM C1 - no probe row for both fields too long and for "Delete
archive after unpacking" (FR-003) - fixed: row `both` added to the probe, T007 extended. LOW C3 (no
task for "no new string") - T006 checks `git diff main -- src/lang`. LOW C2 (focus not probed) and
U1 (unpaired surrogate not probed) accepted: both are the shared helper's behaviour
(`DlgItemTextFitsU8` / `SalWindowTextFitsU8`), proven in 214 / 251 / 291. Run 2: no CRITICAL, no
HIGH; C2 / U1 remain LOW, accepted.

Row `both` on the build before the fix (`probe/result_before_both.txt`): FAIL - dialog closed,
nothing asked, only a.k unpacked into the cut 258-byte folder, and **a.zip deleted** (the box was
checked): a.kp, the file the typed mask named, was never unpacked and its archive is gone. So the
cut mask with "Delete archive after unpacking" loses data - more than the item's "no loss found".

## Implementation

`src/dialogs.h`: `CUnpackDialog::Validate` declared. `src/dialogs3.cpp`: `CUnpackDialog::Validate` -
`DlgItemTextFitsU8(HWindow, IDE_PATH, &ti, MAX_PATH)` (refused -> return), then the same for
`IDE_MASK`. `Transfer` unchanged. No new string (`git diff main -- src/lang` empty).

## Checks after the fix

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` (Debug x64) -> `BUILD SUCCEEDED`, exit 0.
- `saltests.exe` -> `saltests: 26443 checks, 0 failed`, exit 0.
- Probe `probe/result_after.txt` (same command as before, `-Label after`): rows PASS 12, FAIL 0 -
  path-cjk, path-ascii, mask-cjk, both: refused ("[#32770 'Error'] The path specified is too
  long."), the dialog stayed, the field whole (128 / 262 / 90 / 126 units), nothing under tgt, a.zip
  kept; ctl, ctl-path: unpacked as typed, nothing asked; 6 END rows PASS. Registry restored identical.
- Negative control: the same probe on the build before the fix (`result_before.txt`,
  `result_before_both.txt`) - 4 FAIL; only the two-line `Validate` differs between the builds.
- Regression: 204's `unpack_dir_probe.ps1 -Only f9-zip` (Alt+F9 of a ZIP, target typed) ->
  `probe/regress_204.txt` PASS 2 / FAIL 0, registry identical.
