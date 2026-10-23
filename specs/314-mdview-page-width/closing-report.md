# Closing report - 314-mdview-page-width
Backlog item: mdview-page-width-levels - Markdown Viewer: choose the page width in View, up to the full window
Outcome: closed

## What changed

View > Page Width (after Color Scheme) in the Markdown Viewer: *Normal* (46rem, the default and
the page of before), *Wide* (64rem), *Wider* (90rem), *Full Window* (no limit, the padding stays).
Radio-checked, applied at once to the open document and to View Source, stored as `PageWidth` (0-3)
next to `ZoomPercent` in the plug-in's configuration (a missing or unknown value reads as Normal).
Five new UI strings, translated into the eight enabled languages.

## Measurements (before / after, commands)

- Before (da0a455a): the article column measured 681 px in every window width; `pw314_probe` 5/5
  FAIL.
- After: 681 / 968 / 1385 / 2228 px in a 2284 px client for the four levels; `pw314_probe` PASS 16,
  FAIL 0, NOT DRIVEN 0 (`specs/314-mdview-page-width/probe/result_after.txt`).
- Details: `fix-log.md`, sections *Measured*, *Checks*, *Finished*.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `.\build.cmd full` -> BUILD SUCCEEDED (all eight mdview language modules import).
- Harness `tests\mdview_htmlgen_test\build_and_run.cmd`: 38/0 before -> 53 passed, 0 failed.
- `saltests: 27558 checks, 0 failed`; `check_encoding.py --strict`: TOTAL 0.
- Translations: 5 gaps per language, 288 DeepL characters, validation failures 0, duplicate
  accelerators 0, 11 pins; `translate.slt --verify` 298 files byte-exact.
- The probe was run on the branch before merging `main`; the merge changed no mdview, webhost or
  shared plug-in code.

## Reviews (findings and what was done)

Review 1 (refute-first): no MUST; S1 (stored level with two windows) fixed with probe row TWOWIN and
a negative control; S2 / S3 recorded as Inbox items. See `fix-log.md` *Review*.

## Owed to a person (with the new person-step items)

- `check-the-markdown-viewer-page-width-submenu-on-a-real` - the submenu with mouse and keyboard,
  dark menus, two windows, the eight languages, and feature 081's probe on a visible desktop.

## New Inbox items (slug - title)

Recorded by the run (already in the backlog):
- `markdown-viewer-a-scheme-width-or-view-source-change-shows` - the reading position is lost on a
  rebuild of the page.
- `the-manual-has-no-page-for-the-markdown-viewer` - the manual has no Markdown Viewer page.
- `the-081-markdown-viewer-probe-takes-a-window-with-an-empty` - the 081 probe fails its first view
  on the hidden desktop.
