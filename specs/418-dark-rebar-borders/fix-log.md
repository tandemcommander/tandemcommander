# Fix log - 418 Dark theme: panel tabs look lower than in the default theme

Backlog item `dark-theme-panel-tabs-look-lower-than-in-the-default-theme`. HEAD0 `f574e83e` (417 merged).

## Measurement before (step 3, on main)

- The maintainer's screenshots (`temp/tab_heights/`, gitignored; 1716 x 1132, 96 DPI): column x 1000 -
  Default: etched pairs (A0A0A0 / FFFFFF) at rows 31-32, 56-57, 82-83, 106-107 (the rebar's border and band
  borders), tab strip 108-136 (29 px), gap 137-138, directory-line border 139; Dark: rebar 31-99 without lines,
  strip 100-128 (29 px), gap 129-130, border 131. Active tab fill 111-136 / 103-128 (26 rows each); title text
  119-127 / 111-119, icon 117-129 / 109-121: 11 px below the strip's top, 9 above its bottom in both. **The tab
  strip and the tabs are the same size**; from the visible frame above the strip to the title: Default 13 px (the
  etched line at 106), Dark 11 px.
- Live build of main, hidden desktop, `probe/measure_tabs.ps1` (`result_measure_before.txt`, captures in
  `probe/captures_measure/`): Default - rebar window 0-76 (77 px; etched pairs at 0-1, 25-26, 51-52, 75-76 around
  bands 23 / 24 / 22), strip 77-105 (DEDEDE), gap 106-107, border 108 (A0A0A0); Dark - rebar 0-68 (69 px, no
  lines), strip 69-97 (242424), gap 98-99, border 100 (101010). Registry restored, identical.
- Cause: `ThemeUpdateRebarStyle` (`src/themes.cpp`) removes `WS_BORDER | RBS_BANDBORDERS` from `HTopRebar` in
  Dark (commit a65ac017, feature 028: "light lines between band rows ... strip classic rebar
  WS_BORDER/RBS_BANDBORDERS (light-only 3D chrome) while dark") - the control draws them with the system's light
  colours. So Dark loses the frame above the strip and the whole window below the rebar moves up 8 px.
- 413 had recorded the rebar difference as a limit (clarification 3); the maintainer's request of 2026-11-07
  (the tabs must look the same in both themes) is what this feature answers.
- The probes were held twice because the maintainer's installed program ran (it shares the registry key); they
  ran after it was closed.
