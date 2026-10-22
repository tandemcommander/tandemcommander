# Closing report - 311-find-containing-cut
Backlog item: find-cuts-a-long-containing-text-and-writes-the-cut-text - Find cuts a long Containing text and writes the cut text back
Outcome: closed

## What changed

- `src/finddlg1.cpp`
  - `CFindDialog::Validate`: the Containing text is refused with "The path specified is too long."
    when its UTF-8 form does not fit `GREP_TEXT_LEN` (after 291's Named check) - every search start,
    every mode.
  - Options > Add Current / Manage / Ignore: the same refusal before the dialog's fields are read.
  - `LoadControls`: a stored option without Containing keeps the field's whole text (`keepGrep`).
  - `UpdateInternalViewerData`: no copy of a Containing text that does not fit into the viewer's
    Find.
- `src/viewer.h` / `src/viewer.cpp`: `CFindSetDialog::Validate` - the same refusal for the viewer's
  Find text (`FIND_TEXT_LEN`).
- No new string, no stored size, registry layout or plug-in interface changed.

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\311-find-containing-cut\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\311-find-containing-cut\probe\grep311_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`

- Before (95145b44 code): 9 FAIL / 13 PASS (12 rows then) - Containing of 67 CJK letters found 2
  files (one without the text), the field written back cut; regex, hex, Add Current, Manage, Ignore,
  option, viewer Find and the viewer copy all cut. Controls PASS.
- After: 26 PASS / 0 FAIL (13 rows incl. review's `view-copy-keep`), registry restored identical.
- Negative control (Validate checks off): 5 rows FAIL; the reviewer's wider control (every guard
  off) failed the Options / option / copy rows.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `build.cmd`: BUILD SUCCEEDED.
- `saltests`: 27,237 checks, 0 failed.
- Probes: 311 26 / 0; 291's 34 / 0 (`probe/regress_291.txt`); 251's 42 / 0 (`probe/regress_251.txt`).

## Reviews (findings and what was done)

One refute-first review: no MUST. SHOULD 1 (the viewer's Find now refuses a long non-ASCII
selection pre-filled through an ANSI `WM_SETTEXT`) - accepted as a consequence (before, it was
searched as mojibake), the pre-fill to the Inbox. SHOULD 2 (hex mode's `DoHexValidation` turns
quoted letters outside the code page into `?`, older code) - to the Inbox. NOTEs: `view-copy-keep`
row added; 251's regression run added; the DB Viewer plug-in's Find reads its field with ANSI
`WM_GETTEXT` into 201 bytes - code page end to end, not a UTF-8 cut (only a double-byte system
code page could exceed it); not filed.

## Owed to a person (with the new person-step items)

- `typed-check-of-the-find-containing-and-viewer-find-refusals` - the refusals with a real keyboard
  / IME (the probe sets text by `WM_SETTEXT`).

## New Inbox items (slug - title)

- `viewer-find-pre-fills-a-non-ascii-selection-as-code-page` - Viewer Find pre-fills a non-ASCII
  selection as code-page text
- `hex-mode-in-find-turns-quoted-letters-outside-the-code-page` - Hex mode in Find turns quoted
  letters outside the code page into question marks
- `typed-check-of-the-find-containing-and-viewer-find-refusals` - Typed check of the Find Containing
  and viewer Find refusals (feature 311)
