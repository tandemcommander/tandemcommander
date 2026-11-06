# Closing report - 404-panel-tabs-rounded-look
Backlog item: panel-tabs-rounded-windows-11-look-with-icons-and-roomier - Panel tabs: taller rounded look with icons and Chrome-like mouse handling
Outcome: closed

## What changed

- The panel tab strip is drawn as variant F of the 2026-11-06 mockups. It is 29 px at 96 DPI and has:
  - a rounded active tab with outward feet in the panel's caption colours;
  - plain inactive titles on a strip 22 % (Dark 50 %) toward the shadow colour;
  - a hover pill and separators;
  - anti-aliased X and + glyphs with hover circles (rasterized with nanosvg, `AlphaBlend`); the text stays GDI.
- Every tab shows a location icon: drive or UNC root, folder, archive, or the plug-in's file-system icon. The icon comes from the panel while the tab is shown and from the location text otherwise; nothing touches the location itself.
- Live drag: the tab follows the cursor, neighbours slide aside (150 ms ease-out) and the tab glides into place on release.
  - Esc, losing the capture, `WM_CANCELMODE` or the right button cancel the drag (the tabs glide back).
  - There is no tear-off.
  - With Windows animation effects off the tabs jump.
  - A mouse move without the left button ends the gesture.
- Close on release: a press on the X never switches or drags. The tab closes only on a release over the same X, and only the tab that was pressed.
- The context menu has *New Tab as Other Panel* (after *New Tab*) and *Move to Other Panel* (after *Duplicate Tab*).
  - The commands are `CM_LEFT/RIGHT_MOVETABTOOTHER` 2885/2886 and `CM_LEFT/RIGHT_NEWTABASOTHER` 2887/2888.
  - The strings use the free slots 14192/14193.
  - Move opens the tab in the other panel first and only then removes it here; it is not kept for Reopen.
  - A refused leave, or a fallback of the other panel to another place, undoes the move.
- Pure rules are in `src/common/saltabs.*` under saltests (`TestTabStrip404`). `IsThemeHighContrast()` is new in `themes.*`.
- Manual: `help/src/hh/salamand/windows_tabstrip.htm`.

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\404-panel-tabs-rounded-look\probe\result_<label>.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\404-panel-tabs-rounded-look\probe\tabs404_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label>"`

- **Before** (the branch before any code change):
  - all 10 variant F look rows FAIL (strip 21 px, the images 29 px);
  - the old-look control: 16488 of 16506 pixels exact (18 in the plus box, which the old program clamps and the mockup port does not);
  - XPRESS and XOFF FAIL (closed on the press);
  - the four menu rows FAIL (the commands are unknown).
- **After:** PASS 29, FAIL 0, NOT DRIVEN 1 (a refused leave: no shipped plug-in refuses one).
  - All 10 images have 0 failing pixels (maximum edge difference 52).
  - The folder and drive icons match the evidence pixel for pixel.
  - MIDDRAG, DRAG, CANCELMODE, CAPLOST, NOTEAR, XPRESS, XRELEASE, XOFF pass.
  - MOVE, NOREOPEN, MOVE-SINGLE, NEWASOTHER, CTXMOVE and CTXNEWAS (the real context menu) pass.
  - FALLBACK MOVE-GONE passes.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` and `.\build.cmd full` -> BUILD SUCCEEDED.
- saltests: 282,433 -> 282,518 checks, 0 failed.
- `tabs404_probe` 29 / 0 / 1; `tabs312_probe` 33 / 0 (regression). The 078 driver was never committed.
- Translations: 2 strings x 8 languages, 328 DeepL characters, 16 pins (`_feature_404`); `slt --verify` byte-exact.

## Reviews (findings and what was done)

- **Review 1** (HEAD fb83b19b): no MUST.
  - S1, a moved tab was lost on a fallback: the move is now undone.
  - S2, a drag ran without the button: a move without `MK_LBUTTON` cancels the gesture.
  - S3, the probes did not prove the drag or the menu path: MIDDRAG, CTXMOVE, CTXNEWAS and FALLBACK rows added.
  - NOTEs fixed: decimal comma in the SVG numbers, idle repaint during a held drag, the pressed-X tab binding.
- **Review 2** (HEAD a0093a77): no MUST, no SHOULD.
  - Its negative control (the S1 check removed) fails FALLBACK.
  - NOTEs fixed: the middle click waits for a pending press; the icon kind is re-read after a switch; `SalTabLocationsSame` is under saltests.
  - Delta review of commit 84804791: no findings.

## Owed to a person (the lines added to the release checklist)

- 5 lines in `manual-checks-owed-before-the-next-release`:
  - the look on a real screen in Default and Dark, with real-mouse hover;
  - the live drag feel, Esc, and animation effects off;
  - close on release with a real mouse;
  - 125 % / 150 % and High Contrast;
  - Move to Other Panel with an SFTP tab, and the greyed rules.
- The CHANGELOG entry below (the changelog has no `## [Unreleased]` section and versions are the maintainer's).

### CHANGELOG entry (for the next release's section)

- **Panel tabs looked like Windows 95, the X closed a tab on the press, and a tab could not go to the other panel** (feature 404).
  - **Before:** tabs were raised 3D boxes with jagged glyphs and no icons. A press on the X closed the tab at once, a drag showed only a thin insert mark, and the only way to show a tab in the other panel was to open the location again there.
  - **Now:**
    - The strip has the rounded Windows 11 look with an icon per tab: drive, folder, archive or plug-in.
    - A dragged tab follows the mouse while the others slide aside, and Esc puts them back.
    - The X closes the tab only when the button is released over it.
    - The tab menu adds *Move to Other Panel* and *New Tab as Other Panel*.
  - **Limitation:**
    - The strip is 8 px taller (about half a list row less).
    - A tab restored at start-up that is inside an archive shows a folder icon until it is first shown.
    - The classic look is not kept as an option.

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- The review findings above (S1-S3 and the NOTEs) were all fixed inside the feature, with probe rows or saltests checks.
- The mockup's old-look port does not clamp the plus box: nothing to fix, it is recorded.

## New Inbox items (slug - title)

- None.
