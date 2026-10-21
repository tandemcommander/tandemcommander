# Closing report - 291-masks-cut-rest
Backlog item: masks-cut-recycle-bin-find-viewer-compare - Typed masks still cut to their buffer: Recycle Bin, Find, viewer, compare
Outcome: closed

## What changed

- Configuration > System: Recycle Bin masks whose UTF-8 form does not fit 260 bytes are refused
  ("The path specified is too long."), whatever the Recycle Bin choice (`CCfgPageSystem::Validate`).
- Find: the Named mask is refused before any search (`CFindDialog::Validate`) and before Options >
  Add Current / Manage / Ignore read the field; a stored option without Named keeps the field's
  whole text (`LoadControls`).
- Configuration > Viewer: text / hex mode masks refused (`CCfgPageViewer::Validate`).
- Compare Directories: both ignore masks refused, whatever the check boxes
  (`CCompareDirsDialog::Validate`).
- Configuration > Views: the in-place name edit reads the whole text and refuses a name over 29
  bytes, storing nothing (`CCfgPageView` `LVN_ENDLABELEDIT`).
- No new UI string, no buffer or registry change. Files: `src/dialogs4.cpp`, `src/dialogs6.cpp`,
  `src/finddlg1.cpp`.

## Measurements (before / after, commands)

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\291-masks-cut-rest\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\291-masks-cut-rest\probe\mask291_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"
```

- Before (c01e1801, `probe/result_before.txt`): PASS 22, FAIL 12 - rb-mask, rb-unused (stored
  `R;*.k`), find-named (found 2), find-add, find-ignore, find-option (field cut to 87 units),
  view-text, view-hex, cmp-files, cmp-dirs-unused (stored cut), vname (9 of 11 letters),
  vname-ascii (29 of 30).
- After (`probe/result_after.txt`): PASS 34, FAIL 0, NOT DRIVEN 0; registry restored identical.
- Negative control (`probe/result_negative_control.txt`): Add Current check and the option keep
  disabled -> find-add, find-option FAIL, find-ignore, find-ctl PASS; restored -> 4 / 0.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED; clang-format of the changed lines: no change.
- `saltests.exe`: 25,281 checks, 0 failed.
- Probes: 291's 34 / 0; 270's 24 / 0 (`probe/regress_270.txt`); 251's 42 / 0
  (`probe/regress_251.txt`).

## Reviews (findings and what was done)

One refute-first review: no MUST, no SHOULD; it re-ran everything (34 / 0), its own negative
control (13 / 5, then 34 / 0) and extra rows (Manage, options, named view rows, OK while editing).
NOTEs 1-3 (other fields with the same cut) -> three Inbox items; NOTEs 4-6 are the spec's
recorded choices; NOTE 7 done at closing; NOTE 8 did not affect this run (fix-log *Review*).

## Owed to a person (with the new person-step items)

Nothing. Every probe row was driven on the hidden desktop (typed text set by `WM_SETTEXT`, Enter
posted, as in 251's / 270's probes). The deletion past the Recycle Bin was not driven (it would
write the user's Recycle Bin); it follows from the stored masks.

## New Inbox items (slug - title)

- unpack-with-an-external-unpacker-cuts-a-long-target-path-and - Unpack with an external unpacker cuts a long target path and mask
- find-cuts-a-long-containing-text-and-writes-the-cut-text - Find cuts a long Containing text and writes the cut text back
- user-menu-compare-names-and-the-change-icon-file-are-cut-to - User Menu compare names and the Change Icon file are cut to 259 bytes
