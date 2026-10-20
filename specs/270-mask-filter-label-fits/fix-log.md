# Fix log - 270-mask-filter-label-fits

Backlog item `more-typed-fields-cut-to-their-buffer-masks-filter-volume` (leftover of 251).

## Measured at 11e20a84 (main, before the feature)

Build: `.\build.cmd` (Debug x64, up to date at HEAD). Probe written for this item
(`probe/mask270_probe.ps1`, 251's driver, 098's library), run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <...>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <...>\mask270_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"
```

(first run from a scratch folder with `-Lib` pointing at 098's library; copied here unchanged
except the BOM.) M = 86 CJK letters (258 bytes). Result `probe/result_before.txt` +
`probe/result_before_hp.txt` (the hot path rows re-run after the probe learned to focus the list
view before `LVM_EDITLABEL`): PASS 14 (incl. END rows), FAIL 7:

- `sel-mask`, `unsel-mask`: `M*Q` (260 bytes) closed silently; the next Select shows `M*` (259).
- `conv-mask`: `M*Q`, CRLF: **`M.txt` converted** (2 CRLF) - the typed mask does not match it.
- `flt`, `flt-unused`: `M*` stored (with either radio).
- `vol`: 140 r-caron (280 bytes): `SetVolumeLabel` called with the cut label - "Unable to change
  drive label. Error: (5) access denied" (not elevated; the label cannot change). The label line
  is reachable (the field has no limit); a cut label (>= 86 units) exceeds every Windows file
  system's label limit, so it was never applied - but the write ran with another text.
- `hp-label`: F2, 100 CJK letters, Enter: stored 86 letters; OK closed the page.
- Controls `sel-ctl`, `conv-ctl` (`M.txt` converted, as asked), `flt-ctl`, `hp-label-ctl`: PASS.
Registry restored identical (SHA-256 BA9B23CF...) in both runs.

Consumers enumerated: see plan.md *Design*.

## speckit-analyze

0 CRITICAL, 0 HIGH. MEDIUM F1 (SC-002 counted 5 control rows, the probe has 4) fixed in spec.md.
LOW, accepted: E1 the volume label that fits is not driven (it would write the label; the code
path for it is unchanged); E2 "too long and invalid syntax gives one message" follows from the order
(the length check returns first), checked by reading; E3 no Unselect control row (the same class
and code as `sel-ctl`). Re-run after the fix: no CRITICAL / HIGH.

## Implementation

- `CSelectDialog::Validate` (`src/dialogs2.cpp`), `CConvertFilesDlg::Validate`,
  `CFilterDialog::Validate`, `CDriveInfo::Validate` (`src/dialogs3.cpp`): first
  `DlgItemTextFitsU8(HWindow, <field>, &ti, MAX_PATH)`, return on a refusal - before the syntax
  check (one message), before the filter's `useFilter` branch (Transfer stores the field either
  way), before `SetVolumeLabel`. winlib runs `Transfer` only after a good `Validate`
  (`case IDOK: if (!ValidateData() || !TransferData(...))`), so nothing is read, selected,
  converted, stored or written.
- `CCfgPageHotPath` `LVN_ENDLABELEDIT` (`src/dialogs4.cpp`): the edit read whole
  (`SalGetWindowTextU8Alloc`), `CleanName`, `SetName`, freed; no memory -> TRACE_E, nothing
  stored; the code-page fallback (no edit control) unchanged. 251's page `Validate` refuses the
  slot (`GetNameLen >= MAX_PATH`) at OK / leaving the page and the field is reloaded whole.

## Checks

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: `BUILD SUCCEEDED`.
- `saltests.exe`: `saltests: 24816 checks, 0 failed` (no new rule; core changed).
- Probe after (`probe/result_after.txt`): PASS 22, FAIL 0, NOT DRIVEN 0 (11 rows + 11 END rows);
  `vol` driven (not elevated), label of C: unchanged (''); registry restored identical.
- Negative control: the Select check disabled (`FALSE &&`), rebuilt, `-Only sel-mask,unsel-mask,sel-ctl`
  -> `sel-mask`, `unsel-mask` FAIL (cut to 259 bytes again), `sel-ctl` PASS
  (`probe/result_negative_control.txt`); restored from a copy, rebuilt, the two rows PASS again.
- Regression: 251's probe `dlg251_probe.ps1` 42 / 0 (`probe/regress_251.txt`).
