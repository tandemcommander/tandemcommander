# Fix log - 314-mdview-page-width

Backlog item `mdview-page-width-levels`: Markdown Viewer - choose the page width in View, up to
the full window. Autonomous run (`/tandem-backlog-implement`), 2026-10-23.

## Measured at da0a455a (before)

- `src/plugins/mdview/htmlgen.cpp` `MdBuildThemeCss`: `.markdown-body{max-width:46rem;margin:0 auto;padding:24px 28px 64px;}`
  and `.markdown-body.full{max-width:none;}`; `MdRenderHtml` and `MdBuildSourceHtml` both emit
  `<article class="markdown-body">`; `grep -rn full src/plugins/mdview/*.cpp` - nothing adds the
  class.
- `CViewerWindow::BuildMenu` (viewer.cpp): View = Color Scheme >, Zoom In / Out / Reset, Load
  Remote Images - no width command. `mdview.cpp` `CONFIG_*`: no width value.
- `tests\mdview_htmlgen_test\build_and_run.cmd` (PowerShell, `cmd /c`): **38 passed, 0 failed**,
  among them "reading measure" (`max-width:46rem`).
- Reading position on a scheme change, by reading: `SelectScheme` -> `Regenerate` ->
  `ShowDocument` -> `DocVersion++`, `Navigate(DocVersion)` with no fragment -> a new document
  `doc.html?v=N` -> opens at the top. Scripts are off (021) and `CTcWebHost` has no scroll API.
  View Source and Load Remote Images go the same way. So "keep the reading position (measure what
  a scheme change does today)" -> a scheme change does not keep it; see spec Clarifications.
- Manual: `help/src/hh/` has no Markdown Viewer page (`grep -rli markdown help/src` -> only
  `configuration_gener.htm`, one sentence).

## Analyze

Two passes: 0 CRITICAL, 0 HIGH. C1 (FR-003 not named in a task) fixed in T003; E1 (dark-menu
radio, two windows) left to the person check (quickstart §5).

## Implementation
- `htmlgen.h/.cpp`: `MdPageWidth` (0 Normal, 1 Wide, 2 Wider, 3 Full), `MdPageWidthFromStored`,
  `ArticleOpenTag` (Normal = the tag of before, byte for byte), CSS `.markdown-body.wide{64rem}`
  `.wider{90rem}` beside the existing `.full{none}`; `pageWidth` parameter of `MdRenderHtml`
  (before `lim`; no caller passed `lim`) and `MdBuildSourceHtml`.
- `viewer.*`: `PageWidth` per window (from `g_pageWidth`), `HWidthMenu`, View > Page Width after
  Color Scheme (commands 220-223), radio check in `RefreshSchemeChecks`, `SelectPageWidth`
  (no-op for the level in use; sets the window's and the stored level; `Regenerate()` like a
  scheme change).
- `mdview.*`: `g_pageWidth`, `PageWidth` REG_DWORD load (through `MdPageWidthFromStored`, a
  failed read keeps Normal) and save beside `ZoomPercent`.
- Strings 2027 (Page &Width), 2028 (&Normal), 2029 (&Wide), 2016 (Wi&der), 2017 (&Full Window):
  free slots of bundle 126, which holds the View menu (rule 084).
- `IMPLEMENTATION_NOTES.md`: the levels instead of the unwired "full-width toggle".
- CHANGELOG entry under 0.1.11 - unreleased.

## Checks

- Generator harness `cmd /c tests\mdview_htmlgen_test\build_and_run.cmd`: 38/0 before -> **53/0**
  (15 new `314` checks). Negative control: the Wide tag made the Normal tag -> **2 FAIL**
  (`314 WIDE class`, `314 levels differ`), source restored.
- Default page (T009): `build_and_run.cmd dump sample.md` with the HEAD generator (stashed) and
  with the feature: 5176 -> 5251 bytes; `fc` shows only the added
  `.markdown-body.wide{max-width:64rem;}.markdown-body.wider{max-width:90rem;}` (75 bytes); the
  article tag and every other rule identical.
- `.\build.cmd` (Debug x64): BUILD SUCCEEDED. `python tools/check_encoding.py --strict`:
  TOTAL: 0 finding(s). saltests: not run - nothing in the core or `src/common/` changed.
- `.\build.cmd full`: **BUILD FAILED** - `czech/german/french/dutch/hungarian/romanian/slovak/
  spanish mdview: import failed` (the 5 new strings; rule 084 two-stage `.slt` refresh not done
  by an autonomous run). Expected; the reason the run stops.

### Probe `probe/pw314_probe.ps1` (hidden desktop; registry backed up, restored, identical)

- before (HEAD plug-in sources stashed and built): `probe/result_before.txt` - PASS 5, FAIL 5:
  MENU FAIL (no Page Width popup), W-NORMAL PASS (extent 681 px, left 794 in a 2284 px client),
  SAVED FAIL (no value), RESTART / UNKNOWN / WRONGTYPE FAIL (no popup).
- after, first run: PASS 10, FAIL 3, NOT DRIVEN 1 - all three were probe errors: the popup title
  compared with its `&`; Full Window allowed width subtracted a scroll bar the page does not
  have; with PageWidth of type REG_SZ the core shows its existing "Error Loading Configuration /
  Unexpected value type." box (the registry layer's answer to any value of the wrong type) before
  the viewer, which the probe took for the viewer. Fixed in the probe.
- after: `probe/result_after.txt` - **PASS 14, FAIL 0, NOT DRIVEN 0**. PrintWindow
  (PW_RENDERFULLCONTENT) captures the WebView2 page on the hidden desktop. Text extents at 100 %
  in a 2284 px client: Normal 681 (allowed 680), Wide 968 (968), Wider 1385 (1384), Full Window
  2228 (2228, left 28 = the padding). Saved `PageWidth = 2 (DWORD)`; restart: Wider checked, the
  same 1385 px; stored 7 -> Normal checked (and saved back as 0); REG_SZ "2" -> Normal checked.

### Regression: feature 081 `mdview_probe.ps1` (wrapper `probe/regress081.ps1`, registry restored)

- feature build: smoke 1/5 (open, zoom, source, scheme FAIL: "90 ms, title ''"), hostile 8/9
  (01-script-tag "3 viewers") - `probe/result_regress081.txt`.
- HEAD build (plug-in sources stashed): **the same** - smoke 1/5 with the same messages, hostile
  8/9 with the same row - `probe/result_regress081_head.txt`. The probe's first view of each
  session counts a window with an empty title on the hidden desktop (the 105 record: the WebView2
  viewer rows behave differently there; 081 recorded its 24 checks on a visible desktop). No
  regression; the visible-desktop run is owed to a person.
- Captures kept: `probe/shot_before_normal.png`, `shot_after_normal.png`, `shot_after_Wide.png`,
  `shot_after_Wider.png`, `shot_after_FullWindow.png` - in Full Window the 24-column table of the
  fixture is shown whole, with no horizontal scroll bar.

## Owed (not done by this run)

- The two-stage `.slt` refresh for the mdview module (strings 2027, 2028, 2029, 2016, 2017;
  rule 084, `translate.merge --templates`), then `.\build.cmd full` -> BUILD SUCCEEDED.
- A person on a visible desktop: View > Page Width with the mouse and keyboard (mnemonics), the
  radio bullet in dark menus, two viewer windows open, the eight languages after the refresh, and
  feature 081's `mdview_probe.ps1 -Scenario all` (it fails its first view on the hidden desktop on
  HEAD as well).
