# Closing report - 270-mask-filter-label-fits
Backlog item: more-typed-fields-cut-to-their-buffer-masks-filter-volume - More typed fields cut to their buffer: masks, filter, volume label, hot path label edit
Outcome: closed

## What changed

Text typed into a field that fits the field (UTF-16 units) but not the 260-byte buffer the program
reads it into (UTF-8 bytes) is refused with "The path specified is too long." instead of being cut
at a whole character and used:
- Select / Unselect (`CSelectDialog::Validate`, `src/dialogs2.cpp`) and Convert
  (`CConvertFilesDlg::Validate`, `src/dialogs3.cpp`): the mask, before the syntax check.
- Change Filter (`CFilterDialog::Validate`): the filter, with either radio button (Transfer stores
  the field in both cases).
- Drive Information (`CDriveInfo::Validate`): the volume label, before `SetVolumeLabel`.
- Hot paths (`CCfgPageHotPath`, `src/dialogs4.cpp`): the in-place label edit (F2) stores the whole
  name; 251's page check refuses it at OK / leaving the page; the edit starts from the whole display
  text (the row shows it cut) - review 1.
Shared helpers of 251 reused (`DlgItemTextFitsU8`, `SalGetWindowTextU8Alloc`). No UI string added or
removed; no plug-in interface change; no registry layout change.

## Measurements (before / after, commands)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\270-mask-filter-label-fits\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\270-mask-filter-label-fits\probe\mask270_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <before | after>"
```

- Before (Debug x64 of 11e20a84; `result_before.txt`, `result_before_hp.txt`): 7 FAIL - Select /
  Unselect stored `M*` for `M*Q`; Convert converted `M.txt` (LF -> CRLF), not matched by the typed
  mask; the filter stored cut with either radio; the volume label written cut (access denied, not
  elevated); F2 stored 86 of 100 letters. Controls PASS.
- After (`result_after.txt`): PASS 24, FAIL 0, NOT DRIVEN 0 (12 rows + END rows); C: label unchanged;
  registry restored identical.
- Negative controls: Select check disabled -> `sel-mask`, `unsel-mask` FAIL
  (`result_negative_control.txt`); without the `LVN_BEGINLABELEDIT` seeding -> `hp-label-again`
  FAIL (`result_negative_control_again.txt`). Review 1: main's three files -> all 7 target rows FAIL.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: `TOTAL: 0 finding(s)`.
- `.\build.cmd`: `BUILD SUCCEEDED`.
- `saltests`: `24816 checks, 0 failed` (no new rule).
- Probe 24 / 0; 251's probe `dlg251_probe.ps1` 42 / 0 (`probe/regress_251.txt`).

## Reviews (findings and what was done)

- Review 1: no MUST. SHOULD 1 (UTF-8 label to `SetVolumeLabelA`, checker gap) and SHOULD 2 (other
  mask fields still cut) -> Inbox items; NOTE 2 (probe header, control boundary) fixed; NOTE 3 (a
  second F2 started from the cut row text) fixed; NOTE 1, 4 kept with reasons (fix-log).
- Review 2 (fresh, with review 1's findings): no MUST. SHOULD 1, 2 (fix-log stale) fixed; NOTE 1
  (comment wording) and NOTE 3 (probe header) fixed; NOTE 2, 4 kept.

## Owed to a person (with the new person-step items)

Nothing. Every probe row was driven on the hidden desktop (typed text set by `WM_SETTEXT`, as in
251's probe). The volume-label refusal was driven unelevated; a label that fits is unchanged code.

## New Inbox items (slug - title)

- masks-cut-recycle-bin-find-viewer-compare - Typed masks still cut to their buffer: Recycle Bin, Find, viewer, compare
- volume-label-written-through-ansi-api - Drive Information writes the volume label through an ANSI API
