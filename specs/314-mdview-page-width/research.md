# Research - 314 Markdown Viewer page width

## R1 How the page is rebuilt and what happens to the reading position

- Decision: a width choice calls the same `Regenerate()` as `SelectScheme`.
- Rationale: `Regenerate` -> `RebuildHtml` -> `ShowDocument` bumps `DocVersion` and navigates to
  `doc.html?v=<N>`; the page has scripts off and `CTcWebHost` has no scroll API, so the rebuilt
  page opens at the top - for a scheme change, View Source and Load Remote Images alike
  (measured by reading at da0a455a). FR-009 makes the width change behave the same.
- Alternatives considered: (a) a host-side script or DevTools call to read and restore the scroll
  offset - a change in `src/common/webhost/` and to the binding contract, ruled out by the item's
  note; (b) a CSS `:target` / `:has()` trick that switches the width by a same-document fragment
  - conflicts with find (which uses the fragment), and the reflow moves the text anyway;
  (c) Chromium reload scroll restoration - needs a `Reload` in the shared host. All rejected;
  keeping the position across every rebuild becomes an Inbox item.

## R2 The levels and the CSS

- Decision: Normal 46rem (no extra class - the article tag of today), Wide 64rem (`wide`), Wider
  90rem (`wider`), Full Window no limit (`full`, the class the stylesheet already names). The
  padding `24px 28px 64px` stays for every level.
- Rationale: the item's example levels; the rem unit keeps zoom scaling as today; `table`,
  `pre` and `img` are already `max-width:100%` / `overflow-x:auto` of the column, so they follow.
- Alternatives: pixel widths (would stop scaling with zoom - rejected); a percentage level
  (not asked).

## R3 Stored value

- Decision: `PageWidth`, REG_DWORD, 0-3 (Normal, Wide, Wider, Full Window); missing -> stays
  default 0; any other number -> 0; a value of another type is not read by
  `CSalamanderRegistryAbstract::GetValue` with REG_DWORD -> default 0.
- Rationale: `ZoomPercent` is the model (item); the clamp follows `LoadConfiguration`'s FR-063
  corruption tolerance.

## R4 Per-window state

- Decision: `CViewerWindow::PageWidth` is copied from `g_pageWidth` in the constructor; a choice
  sets both and rebuilds only this window. Choosing the level already in use is not rebuilt (no
  needless jump to the top) but is still stored as the last choice (review 1: another window may
  have stored a different level meanwhile).
- Rationale: the Clarifications; other windows are not moved.

## R5 Strings

- Decision: ids 2027 (Page Width), 2028 (Normal), 2029 (Wide), 2016 (Wider), 2017 (Full Window) -
  all in string block 127 (ids 2016-2031; block = id / 16 + 1), which already holds the View menu texts.
- Rationale: rule 084 - free slots of an existing bundle; no new bundle.
- Consequence: `build.cmd full` fails for the enabled languages until the two-stage `.slt` refresh
  runs (rule 084); an autonomous run does not do that (stop-rules §3 #2) - precedent 312.

## R6 What a probe can read on the hidden desktop

- Decision: the probe drives the viewer by posted messages and reads the menu (items, radio
  checks) from outside the process, as `cvtab262_probe.ps1` does for the Code Viewer, and the
  stored value from the registry. It tries a `PrintWindow(PW_RENDERFULLCONTENT)` capture of the
  viewer to measure the text column; if the capture shows nothing but the background (WebView2
  composition on the hidden desktop, feature 105), the width rows are recorded NOT DRIVEN and
  owed to a person.
