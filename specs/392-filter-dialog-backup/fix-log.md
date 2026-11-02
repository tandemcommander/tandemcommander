# Fix log - 392-filter-dialog-backup

Backlog item `filter-dialog-cuts-a-long-panel-filter-to-259-bytes-after-a` - Filter dialog cuts a
long panel filter to 259 bytes after a refused edit.

## Measurement before (main fc9b8691)

Site: `src/dialogs3.cpp` `CFilterDialog::Validate` - `char buf[MAX_PATH]; lstrcpyn(buf,
Filter->GetMasksString(), MAX_PATH)` backup; `ti.EditLine(IDE_FILTER,
Filter->GetWritableMasksString(), MAX_PATH)` writes the typed text into the panel's own group;
`PrepareMasks` fails; `Filter->SetMasksString(buf)` restores the cut backup (and resets
`ExtendedMode` to FALSE, leaves `NeedPrepare` TRUE). Caller: `CFilesWindow::ChangeFilter`
(`src/fileswn9.cpp`, `CFilterDialog(HWindow, &Filter, ...)`), commands CM_CHANGEFILTER /
CM_LCHANGEFILTER / CM_RCHANGEFILTER; Cancel after the error does nothing more, so the cut filter
stays in the panel.

Reachability: `Filter` > 259 bytes comes from a tab's `Filter` registry value (read with
`SAL_TAB_FILTER_MAX` = 1001 in `mainwnd2.cpp`, set into `Filter` in
`CFilesWindow::SwitchToTab` (`paneltabs.cpp`) when the tab is activated). The panel's own
`Filter` value is read with `MAX_PATH`.

Probe `probe/flt392_probe.ps1` (098's library), run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\392-filter-dialog-backup\probe\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\flt_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib <098 lib>"
```

Result (`probe/result_before.txt`): `long-refused` FAIL - the first dialog showed 300 of 300 bytes,
`*.txt|` refused with "File mask is syntactically incorrect.", Cancel, the next dialog shows 259
bytes (tail `...x036;*.x037;`). `short-refused` PASS, `long-valid` PASS. Registry restored,
identical hash. Defect confirmed; `BL verify` recorded.

Notes answered: the dialog shows the whole long filter (WM_SETTEXT is not bound by
`CB_LIMITTEXT`); OK with the long text unchanged is refused by `DlgItemTextFitsU8` (feature 270)
before anything is touched - the cut needs a shorter invalid text, as the probe does.

## Analyze

`speckit-analyze` (one round): CRITICAL 0, HIGH 0. C1 MEDIUM (the edge case "refused, then
corrected in the same dialog" had no probe row) - fixed: row `long-refused-then-valid` added to
the probe. C2 LOW (the error position is not probed) and C3 LOW (history / "Don't use filter" not
probed) - accepted: the check runs in the same class with the panel's mode, so the verdict and
`errorPos` are the same by construction; `Transfer` is unchanged and feature 270's probe covers
history and "Don't use filter".
