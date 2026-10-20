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
- (review 1, NOTE 3) `CCfgPageHotPath` `LVN_BEGINLABELEDIT`: the row shows its label cut to
  `MAX_PATH` (`GetDisplayName`, 251), so a second F2 started from the cut text and an edit stored
  it (86 letters + `x` = 259 bytes, OK passed). The edit is now seeded with the whole display text
  (heap buffer of `max(GetNameLen, GetPathLen) + 1` - unescaping `$$` only shortens).

## Checks

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: `BUILD SUCCEEDED`.
- `saltests.exe`: `saltests: 24816 checks, 0 failed` (no new rule; core changed).
- Probe after (`probe/result_after.txt`, after review 1's change): PASS 24, FAIL 0, NOT DRIVEN 0
  (12 rows + 12 END rows; the first run before review 1 had 11 + 11 = 22 / 0); `vol` driven (not
  elevated), label of C: unchanged (''); registry restored identical.
- Negative control of `hp-label-again` (`probe/result_negative_control_again.txt`): the build
  without the `LVN_BEGINLABELEDIT` seeding - the second edit started with 86 units, 87 letters
  stored, OK passed: FAIL; with it: PASS. (A first variant pressed Enter without a change: comctl32
  treats that as a cancel and stores nothing, so the row appends 'x' - WM_SETTEXT standing for
  End, 'x'; real typing is not driven.)
- Negative control: the Select check disabled (`FALSE &&`), rebuilt, `-Only sel-mask,unsel-mask,sel-ctl`
  -> `sel-mask`, `unsel-mask` FAIL (cut to 259 bytes again), `sel-ctl` PASS
  (`probe/result_negative_control.txt`); restored from a copy, rebuilt, the two rows PASS again.
- Regression: 251's probe `dlg251_probe.ps1` 42 / 0 (`probe/regress_251.txt`).

## Review

Review 1 (refute-first agent, at a4181ae9): **no MUST**. Re-ran the probe 22 / 0 and a wider
negative control (main's three source files, rebuilt): all 7 target rows FAIL, the 4 controls PASS;
restored byte-exact.
- SHOULD 1 - `CDriveInfo` passes the UTF-8 label to `SetVolumeLabel` (= `SetVolumeLabelA`, the
  core has no `_UNICODE`); the checker misses it. Pre-existing, outside the item -> Inbox
  `volume-label-written-through-ansi-api`.
- SHOULD 2 - the same cut remains in fields the item does not list (Recycle Bin masks - permanent
  deletion of files the dropped masks named; Find "Named"; viewer masks; compare ignore masks; the
  viewer list's name edit) -> Inbox `masks-cut-recycle-bin-find-viewer-compare`.
- NOTE 1 - Convert's `Validate` checks syntax on the code-page text (pre-existing; a mask valid only
  in its code-page form passes OK and Convert then does nothing - no data at risk): kept, out of scope.
- NOTE 2 - the probe header promised selection checks the rows do not make; `hp-label-ctl` at 258,
  not 259 bytes: header corrected, control moved to 259 bytes.
- NOTE 3 - a second F2 started from the cut row text: **fixed** (`LVN_BEGINLABELEDIT`, row
  `hp-label-again`, commit 7ae8d2a4).
- NOTE 4 - "Don't use filter" with an over-long text refuses OK: the spec's choice (clarification 2).

Review 2 (fresh refute-first agent, at 7ae8d2a4, with review 1's findings): **no MUST**. Probe
24 / 0; probe variant on unnamed slots (303-letter ASCII path, 123 CJK letters, `C:\a$$b`): the
edit starts whole, Enter without a change stores nothing, `$$` is shown unescaped as on main; the
edit's own limit (259 units) does not cut a `WM_SETTEXT`; comctl32 selects the seeded text after the
notification (type-to-rename still replaces it).
- SHOULD 1, 2 - the fix-log lacked review 1 and showed the old count 22: this section and *Checks*
  updated.
- NOTE 1 - the `LVN_BEGINLABELEDIT` comment called every cut row "waiting for the refusal": a path
  of 260-1,039 bytes is valid and only displayed cut - comment corrected.
- NOTE 2 - a seed longer than 259 units cannot be typed into until shortened (as on main): kept.
- NOTE 3 - `hp-label-again` appends by `WM_SETTEXT`, not keystrokes: probe header says so.
- NOTE 4 - as review 1 NOTE 4: kept.
