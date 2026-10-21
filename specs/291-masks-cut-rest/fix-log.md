# Fix log - 291-masks-cut-rest

Backlog item `masks-cut-recycle-bin-find-viewer-compare` (source review:270).

## Measured at c01e1801 (main, before the feature)

Build: `.\build.cmd` (Debug x64, BUILD SUCCEEDED). Probe written for this item
(`probe/mask291_probe.ps1`, 270's driver, 098's library), first in a scratch folder with `-Lib`
pointing at 098's library, then copied here unchanged (BOM, CRLF):

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <...>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <...>\mask291_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib <...>\fix_probe_lib.ps1"
```

A first run failed in the probe itself (the `-Before` parameter of `Mask-Row` was shadowed by
`Run-Row`'s `$before` - PowerShell names are case-insensitive - so the System page was not
preselected); renamed `-PreStart`, error rows now close their dialogs. Result
`probe/result_before.txt`: PASS 22, FAIL 12 (M = 86 CJK letters, 258 bytes; R = 85, 255 bytes):

- `rb-mask`, `rb-unused`: Recycle Bin masks `R;*.kp` (260 bytes) stored as `R;*.k` (259), with the
  masks radio and with "Move all deleted files" (the field is always enabled and always stored).
- `find-named`: Named `M*Q` cut to `M*`, found 2 (`M.txt` too). Field limit 259 units
  (`HistoryComboBox`, `NAMED_TEXT_LEN - 1`), buffer 260 bytes.
- `find-add`, `find-ignore`: Add Current / Ignore - `TransferData` without `Validate`;
  `HistoryComboBox` read the field cut and wrote the cut text back (87 units / 259 bytes), so the
  next Find would use it; Ignore opened its dialog.
- `find-option`: a seeded stored option without Named (`Configuration\Find Options\1`, ItemName
  only): `LoadControls` kept the field text through a cut read - 87 units, Find found 2.
- `view-text`, `view-hex`: stored `M*`.
- `cmp-files`, `cmp-dirs-unused`: stored `M*` (the dirs field with its box unchecked too).
- `vname`: 11 CJK letters (33 bytes) stored as 9; `vname-ascii`: 30 letters stored as 29.
- Controls `rb-ctl`, `find-ctl`, `view-ctl`, `cmp-ctl`, `vname-ctl`: PASS; 17 END rows PASS.
Registry restored identical (SHA-256 34FA77DB...).

Consumers enumerated: see plan.md *Design*. Stored masks are never above 259 bytes (registry load
reads `MAX_PATH`; `cfgimport.cpp` `CfgImpOptionCompanion` refuses `>= MAX_PATH`), view names never
above 29 (`CViewTemplates::Set`, the import's check).

## speckit-analyze

0 CRITICAL, 0 HIGH. MEDIUM C1 (CHANGELOG entry not a task): the closing step of the run writes it.
LOW C2 (clang-format not a task): added to T009. LOW U1 (the deletion past the Recycle Bin is not
driven - it would write the user's Recycle Bin): accepted; the delete matches the stored masks
(`worker.cpp` `AgreeRecycleMasks` on a copy of `Configuration.RecycleMasks`), checked by reading.

## Implementation

- `CCfgPageSystem::Validate` (`src/dialogs4.cpp`): first `DlgItemTextFitsU8(HWindow,
  IDE_RECYCLEMASKS, &ti, MAX_PATH)`, return on a refusal - before the `useRecycle == 2` branch
  (Transfer stores the field whatever the radio).
- `CCfgPageViewer::Validate`: the same for `IDC_VIEW_INTEXT` / `IDC_VIEW_INHEX`, each inside its
  `ti.IsGood()` block before `EditLine` and the syntax check (the tab size check stays first).
- `CCfgPageView` `LVN_ENDLABELEDIT`: the edit read whole (`SalGetWindowTextU8Alloc`; NULL ->
  TRACE_E, nothing stored), `CleanName`; `strlen >= VIEW_NAME_MAX` -> "The path specified is too
  long.", nothing stored (the row keeps its name: the handler sets the row text itself, the list's
  own change is not accepted); freed after `SalListViewSetItemTextU8`. Code-page fallback unchanged.
- `CCompareDirsDialog::Validate` (`src/dialogs6.cpp`): both mask fields first, whatever the boxes.
- `CFindDialog::Validate` (`src/finddlg1.cpp`, now includes `dialogs.h`): the Named check first
  (`NAMED_TEXT_LEN`), before the backups and the syntax check.
- `CM_FIND_ADD_CURRENT`, `CM_FIND_MANAGE`, `CM_FIND_IGNORE`: `DlgItemTextFitsU8(..., NULL, ...)`
  before `TransferData(ttDataFromWindow)` (and before the in-use flags); a refusal returns as the
  case already did.
- `CFindDialog::LoadControls`: an option without Named and a field text that does not fit ->
  the whole text is taken (`SalGetWindowTextU8Alloc`, WTF-8) **before** `Data` is replaced and put
  back (`SalSetWindowTextU8`) after `TransferData(ttDataToWindow)`; no memory -> TRACE_E, nothing
  loaded. (`SalGetWindowTextWAlloc` is file-static in winlib - the exported UTF-8 pair is used.)

## Checks

- clang-format (VS 2022 LLVM, `--style=file`, on the changed line ranges): no change.
- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: `BUILD SUCCEEDED`.
- `saltests.exe`: `saltests: 25281 checks, 0 failed` (no new rule; core changed).
- Probe after (`probe/result_after.txt`): PASS 34, FAIL 0, NOT DRIVEN 0 (17 rows + 17 END rows);
  every refusal row shows "The path specified is too long." with the field whole; Find found 0;
  the Views row stays empty; controls unchanged; registry restored identical (34FA77DB...).
- Negative control (`probe/result_negative_control.txt`): the Add Current check and the
  `LoadControls` keep disabled (`FALSE &&`), rebuilt, rows find-add, find-option FAIL (field cut to
  87 units; the option row found 2), find-ignore and find-ctl PASS; restored from a copy, rebuilt,
  find-add and find-option PASS (`probe/result_negative_control_restored.txt`, 4 / 0). The view
  name refusal was not disabled: without it the whole heap text would be copied into the 30-byte
  name (an overrun, not the old behaviour) - its control is the before run (vname, vname-ascii
  FAIL at c01e1801).
- Regression: 270's probe 24 / 0 (`probe/regress_270.txt`), 251's 42 / 0 (`probe/regress_251.txt`).
