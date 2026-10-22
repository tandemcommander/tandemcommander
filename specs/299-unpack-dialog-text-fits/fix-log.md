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
