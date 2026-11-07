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

## Design (research.md)

- Experiment on the live build: keep `WS_BORDER | RBS_BANDBORDERS` in Dark and set the rebar's `COLORSCHEME`
  (`RB_SETCOLORSCHEME`) to the Dark palette's `COLOR_BTNHIGHLIGHT` (464646) / `COLOR_BTNSHADOW` (1A1A1A): the rebar
  draws its etched frame and band borders with them - Dark rebar 77 px, lines exactly where Default has
  A0A0A0 / FFFFFF. Default passes `CLR_DEFAULT` (the system colours: the rebar as on main).
- `ThemeUpdateRebarStyle` (`src/themes.cpp`): the styles in both themes; the scheme by theme, set only when it
  differs from `RB_GETCOLORSCHEME`; a style change keeps `SWP_FRAMECHANGED` + invalidate, a scheme change alone
  `RedrawWindow(RDW_INVALIDATE | RDW_ERASE | RDW_FRAME)` (the frame is non-client). Callers unchanged (start-up
  after the rebar is created, `OnColorsChanged` on every theme / colour change). Comments in `themes.h`,
  `mainwnd1.cpp`, `mainwnd3.cpp`.
- Grips stay light-only (028; clarification 3) - they are still hidden in Dark.

## Analyze (inline)

- Coverage: FR-001 (DARK/EXTRA/NARROW ROWS, STYLE), FR-002 (LINES, NOLIGHT, saltests), FR-003 (ROWS: strip and
  directory line), FR-004 (CLASSIC EQ), FR-005 (SWITCH), FR-006 (EXTRA, NARROW). No CRITICAL / HIGH.
- Fixed in the artifacts: SC-003 / US2 said "no pixel" of the light colours - toolbar icons legitimately contain
  them; now "no line". The edge case "bands wrap when the window narrows" was a wrong premise (measured: a rebar
  moves a band to a new row only by its break flag or a drag; bands of one row shrink) - spec and NARROW row
  corrected. SC-002 states the measured quantity (equal absolute row of a tab's first content).

## Verification

- `build.cmd`: BUILD SUCCEEDED. `saltests`: 286948 checks, 0 failed (+5: `TestDarkRebarEtchedPair418` - Dark
  shadow < face < highlight, both far darker than the light lines, contrast >= 1.5).
- `check_encoding.py --strict`: TOTAL: 0.
- Build of main for the comparison: worktree of `f574e83e`, `salamand.vcxproj` + `lang.vcxproj` with their own
  `OPENSAL_BUILD_DIR`, put into a copy of this build's tree (only the core and the English module differ).
- Probe `probe/rebar418_probe.ps1` (hidden desktop; every start from the same exported configuration):
  - run 1: PROBE ERROR - `$d` overwrote `$D` (PowerShell names are case-insensitive); LINES counted the light
    theme's grips and toolbar separators. Run 2: LINES 22 px at x 45 (the light drive bar's pressed button edge,
    spans the band, alone - not an etched pair); EXTRA / NARROW compared different bar sets (the program saves
    its configuration on exit). Run 3: the vertical lines now count only as etched pairs reaching a line at both
    ends, every start resets the configuration; NARROW did not wrap (premise corrected, above).
  - **Final (`result_after.txt`): PASS 20, FAIL 0, NOT DRIVEN 0**, registry restored and identical:
    DARK rebar 77 / 77, strip 77-106 both, directory line 106-129 both, title row 86 both; 13838 line pixels all
    the Dark pair; no light run in the Dark rebar (the detector finds 35 on the Default one). CLASSIC: the whole
    Default client area 1714 x 1101 = main, 0 px. SWITCH: Default -> Dark and back at run time = a fresh start,
    0 px in rows 0-128. EXTRA (Plugins bar + second drive bar, 5 bands, two side by side): rows 101 / 101,
    17306 line pixels all Dark. NARROW (504 px wide, same bars): rows equal, 5206 line pixels all Dark.
  - **Negative control on the build of main (`result_negative_main.txt`)**: DARK / EXTRA ROWS, STYLE, LINES,
    TITLE **FAIL** (rebar 77 / 69 and 101 / 91, title row 86 / 78) - the defect; NOLIGHT and SWITCH pass there
    (main draws no Dark lines at all and switches consistently - they guard against regressions of this fix).
- Not covered by the probe: display scales 125-200 % (the hidden desktop runs at 96 DPI; the rebar's border sizes
  are the system's in both themes) - a release-checklist line.
