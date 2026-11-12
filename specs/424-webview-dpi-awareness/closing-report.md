# Closing report - 424-webview-dpi-awareness
Backlog item: remove-indentation-for-text-viewers - Code Viewer and Markdown Viewer show the page shifted right and down
Outcome: closed

## What changed

- The cause (measured at a44dfdf4): the program is system DPI aware, and WebView2 started its
  browser process the same way (`--embedded-browser-webview-dpi-awareness=1`). A system-aware process
  fixes its scaling at its own start, and the browser starts at the first F3 of a session. After a
  display-scaling change in between, the program and the browser used different coordinate spaces,
  which produced the larger, shifted, cut-off page of GitHub #29.
- WebView2 takes the browser's DPI mode from the calling thread's context at environment creation
  (experiment `probe/wv2dpi`). `CTcWebHost::Create` and `CTcWebKeeper::Arm` now create their
  environments inside `CTcWebPerMonitorDpiScope`, so the browser runs per-monitor v2.
- The viewer threads of both plug-ins run per-monitor v2 (`TcWebEnterPerMonitorDpiThread`). The
  core's rectangle is mapped through its monitor (`TcWebSystemRectToPerMonitor`, pure rule
  `src/common/saldpirect.h`). `WM_DPICHANGED` takes the suggested rectangle.
- The Code Viewer's status font and height follow the window's DPI.
- The dark-theme owner-drawn menus of both viewers use a font per DPI and `GetSystemMetricsForDpi`,
  and re-measure on a DPI change (re-set of each item's bitmap).
- The core stays system aware. Architecture 11 has the rule, and the contract is
  `contracts/webhost-dpi.md`.

### CHANGELOG entry (no `## [Unreleased]` section in `CHANGELOG.md` - the maintainer adds it)

```text
- **The Code Viewer and the Markdown Viewer showed their page shifted right and down, larger and cut off** (feature 424, GitHub #29).
  - **Before:** when the display scaling changed while Tandem Commander was running (in Settings, by docking or undocking a laptop, or through a remote-desktop session), the page of both viewers (F3 on a text or Markdown file) started far from the window's top-left corner, its text was larger and its right and bottom parts were cut off; on a second monitor with another scaling the viewers were drawn blurred.
  - **Now:** both viewers and the engine that draws their page follow the scaling of the monitor they are on: the page fills the window whatever the scaling was when the program started, a viewer moved to another monitor takes that monitor's size and sharpness, and the status bar and the dark menus follow. The rest of Tandem Commander keeps its behaviour.
  - **Limitation:** while an older version of Tandem Commander is running and has shown one of these viewers, the viewers of this version report that the engine is not available (and the other way round); close the older version first.
```

## Measurements (before / after, commands)

- `probe/dpi29_probe.ps1` at HEAD (`probe/result_before.txt`): program and browser system aware
  (1), browser `=1`, the browser's windows cross-process children of the viewer.
- `probe/wv2dpi` (`summary.txt`): system `=1`, per-monitor thread `=2`, per-monitor only around the
  call `=2` (controller `S_OK`).
- `probe/dpi424_probe.ps1` (hidden desktop), before = main a44dfdf4 with the old viewer plug-ins
  (`%TEMP%\tc424negbuild`), after = the branch:
  - default theme: before PASS 3 / FAIL 4 (AWARE CV/MD 1/1/1, DPICHANGED CV/MD window kept its
    rectangle) -> after **PASS 7 / FAIL 0** (viewer 2, controller 2, browser `=2` and 2, main window
    and program 1; GEO identical; DPICHANGED exact).
  - Dark: before 3 / 4 -> after **7 / 0**; MENU 4 of 4 owner-drawn; GEO identical.
- `probe/menutest` (owner-drawn re-measure): mode 0 (the product's function) bar +3, popup +4;
  mode 5 (the first version) +0 / +0.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED`. No UI string, menu or dialog changed (no `.slt` refresh, no
  `full` build needed).
- `saltests.exe` -> `saltests: 287267 checks, 0 failed` (`TestDpiRect424` new).
- Probes: `dpi424_probe` 7 / 0 (default and Dark); `menutest` as above. Regression from copies
  under `%TEMP%\tc424reg`: `pw314_probe` 16 / 0, `cvtab262_probe` 16 / 0, `copy408_probe` 19 / 0 /
  1 NOT DRIVEN (all as recorded by their features).

## Reviews (findings and what was done)

- Review 1, no MUST:
  - S1, the old/new-version mix (controller `0x8007139F`, measured): documented as a limit.
  - S2, dark menus at the start scaling: fixed.
  - S3, the reply overclaimed: reworded.
  - NOTE, placement wording: reworded.
- Review 2, no MUST:
  - S1, `DarkMenuRemeasure` did nothing: fixed with the bitmap re-set, plus the `menutest` probe.
  - NOTE, the changelog text: it is here.
- Review 3, no MUST, no SHOULD:
  - The bitmap re-set was checked with the product's `darkmenu.cpp` in a test host: no side
    effects on any item field, mnemonics, bar rectangles or object counts.
  - NOTE 1, the comment overclaimed for items with a real bitmap: narrowed.

## Owed to a person (the lines added to the release checklist)

Three lines (feature 424) in `manual-checks-owed-before-the-next-release`:
- the viewers after a display-scaling change made while the program runs;
- two monitors of different scaling: open, move, the status bar, Find / Go to line, and the Dark
  menus;
- 125 % / 150 % from the start, *Save position*, and a position saved by 0.3.0 on a second monitor.

Also owed: the CHANGELOG entry above (no `## [Unreleased]` section), and answering and closing
GitHub issue #29 (draft in `specs/424-webview-dpi-awareness/reply.md`).

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- Dark-theme owner-drawn menus of both viewers: font and metrics per DPI, and a re-measure that
  works (review 1 S2, review 2 S1).
- The Code Viewer's status font now from the window's DPI (was the system's).

## New Inbox items (slug - title)

None.
