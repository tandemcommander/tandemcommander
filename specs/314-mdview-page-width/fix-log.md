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
  free slots of string block 127 (ids 2016-2031), which holds the View menu (rule 084).
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
- after (first build): **PASS 14, FAIL 0, NOT DRIVEN 0**; after review 1: see *Review*. PrintWindow
  (PW_RENDERFULLCONTENT) captures the WebView2 page on the hidden desktop. Text extents at 100 %
  in a 2284 px client: Normal 681 (allowed 680), Wide 968 (968), Wider 1385 (1384), Full Window
  2228 (2228, left 28 = the padding). Saved `PageWidth = 2 (DWORD)`; restart: Wider checked, the
  same 1385 px; stored 7 -> Normal checked (and saved back as 0); REG_SZ "2" -> Normal checked.

### Regression: feature 081 `mdview_probe.ps1` (wrapper `probe/regress081.ps1`, registry restored)

- feature build: smoke 1/5 (open, zoom, source, scheme FAIL: "90 ms, title ''"), hostile 8/9
  (01-script-tag "3 viewers") - `probe/result_regress081.txt`.
- HEAD build (plug-in sources stashed): **the same** - smoke 1/5 with the same messages, hostile
  8/9 with the same row - `probe/result_regress081_head.txt`. The probe's first view of each
  session takes a window with an empty title for the viewer (about 80 ms after F3). Identical
  failures prove nothing either way (review 1, S3): `pw314_probe` reads the full title in its first
  view on the same desktop, so the likely cause is a race in the 081 probe's `Open-File`, not the
  desktop - Inbox `the-081-markdown-viewer-probe-takes-a-window-with-an-empty`. SC-004's 081 part
  stays open; the visible-desktop run is owed to a person. The viewer itself is exercised by
  `pw314_probe` (menu, every level rebuilt and measured, restart, View Source not driven).
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

## Review

Review 1 (independent agent, refute-first): **no MUST**. It re-ran the harness (53/0), the build,
the guard, and a negative control of its own (`RebuildHtml` forced to Normal -> W-WIDE / W-WIDER /
W-FULL FAIL at 681 px; restored, registry identical).

- S1 (fixed): `SelectPageWidth` returned before storing when the chosen level was already the
  window's own - with two windows (A -> Wide, then B -> Normal, already B's) the stored level
  stayed Wide against the spec's "documents opened afterwards use the last chosen level". Now the
  stored level is set first, only the rebuild is skipped. Probe row **TWOWIN** added: after
  `PASS` (stored 0); negative control (the committed viewer.cpp of 67d1e782 built and probed):
  **TWOWIN FAIL, stored 1** - PASS 15, FAIL 1; then rebuilt with the fix.
- S2 (done): the Inbox items the spec promised were not filed yet - now
  `markdown-viewer-a-scheme-width-or-view-source-change-shows` (reading position across every
  rebuild; needs the shared host; the cheap find-fragment step noted there) and
  `the-manual-has-no-page-for-the-markdown-viewer`. The reading-position deviation from the item's
  *Expected* is named in the stop record for the maintainer.
- S3 (done): the 081 regression wording corrected (above); Inbox item for the 081 probe.
- Notes: the REG_SZ case shows the core's existing "Unexpected value type." box (as for
  `ZoomPercent`) - spec edge case reworded to say so; the RESTART row now also checks the Wider
  width itself, not only against the earlier measurement; the "bundle 126" comment corrected to
  string block 127 (ids 2016-2031); a stray UTF-8 BOM my negative-control restore had added to
  `htmlgen.cpp` removed (the file is as on `main` at its first line again).

After the fixes: `.\build.cmd` BUILD SUCCEEDED; harness 53/0; guard TOTAL 0;
`probe/result_after.txt` **PASS 16, FAIL 0, NOT DRIVEN 0** (registry restored, identical
SHA-256 CF69145A...). No MUST -> no second review needed.

## Stopped (autonomous run, 2026-10-23)

Everything the item asks is implemented and verified on this branch except the translations: the
feature adds five UI strings, so the two-stage `.slt` refresh (rule 084) is required, and an
autonomous run does not do it (stop-rules §3 #2). Measured: `.\build.cmd full` fails for all eight
languages (`<language>/mdview: import failed`). The run stops before closing the item.

Deviations from the item's *Expected* the maintainer should accept or reject when finishing:
- Reading position: a width change shows the document from the top, as a scheme change does
  today (measured by reading: scripts off, no scroll API in the shared host; the item's note keeps
  the change out of `src/common/webhost/`). Recorded as
  `markdown-viewer-a-scheme-width-or-view-source-change-shows`.
- Manual: there is no Markdown Viewer page to extend - `the-manual-has-no-page-for-the-markdown-viewer`.
- 081 probe: fails on HEAD the same way - `the-081-markdown-viewer-probe-takes-a-window-with-an-empty`.

What the maintainer does to finish (in this order):
1. On this branch: the two-stage `.slt` refresh for the mdview module (strings 2027 "Page &Width",
   2028 "&Normal", 2029 "&Wide", 2016 "Wi&der", 2017 "&Full Window"), `--templates` as in rule
   084; pin texts in `translations/ui-overrides.json` if DeepL drifts; `.\build.cmd full` ->
   BUILD SUCCEEDED.
2. Close the item as SKILL.md step 8 does: `BL remove mdview-page-width-levels --feature 314`, the
   FEATURE-HISTORY entry below (index row "WebView2 viewers (Markdown, Code)": add 314), a closing
   report; the CHANGELOG entry is already under 0.1.11 - unreleased.
3. The person step `check-the-markdown-viewer-page-width-submenu-on-a-real`.
4. `git merge --ff-only 314-mdview-page-width` (or a merge) into main.

Draft FEATURE-HISTORY entry:

- 314-mdview-page-width: the Markdown Viewer kept every document in a 46rem column (about 736 px,
  80-90 characters a line) - a wider window only added margins, wide tables and code scrolled
  inside the column, zoom scaled both - now View > Page Width (after Color Scheme) offers Normal
  46rem (the default, the page of before byte for byte apart from two added CSS rules), Wide
  64rem, Wider 90rem, Full Window (no limit, the padding stays), radio-checked, applied at once
  (also in View Source) and stored as `PageWidth` 0-3 beside `ZoomPercent` (unknown -> Normal).
  The width is per window; a choice also sets the stored level, even when it is the window's
  own (review 1: two windows). Traps: a rebuild opens the page at the top (scripts off, no scroll
  API in the shared host - a scheme change does the same; Inbox item); PrintWindow
  (PW_RENDERFULLCONTENT) does capture the WebView2 page on the hidden desktop - the probe measures
  the text column (681 / 968 / 1385 / 2228 px in a 2284 px client); a wrong-typed value shows the
  core's "Unexpected value type." box; the 081 `mdview_probe.ps1` fails its first view on the
  hidden desktop on HEAD as well (Inbox). From backlog item `mdview-page-width-levels`. Probe
  `pw314_probe` 5/5 FAIL before -> 16/0; harness 38 -> 53/0 (negative controls fail); one
  refute-first review (no MUST; S1 fixed).
