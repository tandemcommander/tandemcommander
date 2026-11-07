# Closing report - 413-tab-drag-first-place
Backlog item: panel-tabs-drag-to-first-place-and-dark-strip-height - Panel tabs: a drag cannot put a tab in the first place; dark strip looks lower
Outcome: closed

## What changed

- **Drag to the first place** (`src/common/saltabs.cpp` `SalTabDragSlot`): moving left, tab j now
  gives way once the dragged tab's left is at or below j tab widths (it was "below"). The strip
  clamps the dragged tab to its run, so the left never went below 0 and the first place was
  unreachable for every tab but the first one. Now both ends are reachable, in both panels and in a
  strip that shows only a run of its tabs (the first place of the run). Only lefts equal to a
  multiple of the tab width change their slot; every other decision is the same.
- **Dark theme look** (`SalTabActiveFill`, `SalTabActiveText`, used by `CTabWindow::Paint`): the
  strip was not lower in pixels (29 px strip, 23 px directory line, the active tab on rows 3-28 in
  both themes, at the maintainer's 96 DPI). What differed: in the Dark theme the inactive panel's
  active tab (2D2D2D) was 9 from the strip (242424) and 0 from the directory line's band (2D2D2D) -
  it had no visible shape. The active tab's fill now keeps the caption colour unless it is within
  24 (largest channel) of the strip or the face; then it is lifted toward the caption text colour by
  the smallest hundredth (Dark inactive: 454545); when no step reaches 24, the best-separating one.
  The title on a lifted fill keeps the contrast it had on the caption colour (AAAAAA -> B2B2B2,
  4.52:1). The default theme and the Dark theme's active panel are pixel-identical to 404.
- `tabs404_probe` LOOK-DARK INACTIVE compares with `evidence/variantF_dark_inactive_413.png` (the
  mockup with the active tab's box taken from the 413 capture).
- Manual: `help/src/hh/salamand/windows_tabstrip.htm` - dragging to either end makes the tab the
  first or the last.

## Measurements (before / after, commands)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log <log> -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\413-tab-drag-first-place\probe\tabs413_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <before|after> -OutFile specs\413-tab-drag-first-place\probe\result_<label>.txt"`

| | before (75a45ea7) | after |
|---|---|---|
| D dragged past the left end (left) | A D B C | D A B C |
| S dragged past the left end (right) | P S Q R | S P Q R |
| T29 to the run's left end (30 tabs, first visible 22) | index 23 | index 22 |
| Dark inactive tab vs strip / band | 9 / 0 | 33 / 24 |
| Its title contrast | 5.93:1 (AAAAAA on 2D2D2D) | 4.52:1 (B2B2B2 on 454545) |
| Heights (strip / directory line / tab rows), both themes | 29 / 23 / 3-28 | unchanged |
| Probe rows | PASS 11, FAIL 7, NOT DRIVEN 1 | PASS 22, FAIL 0, NOT DRIVEN 1 |

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED (Debug x64).
- saltests: 282,686 checks, 0 failed (`TestTabStrip413`); negative controls: the old slot rule and
  an unlifted fill 14 failed, the title rule returning the caption text 4 failed, the review-1
  rules 5 failed.
- `tabs413_probe` 22 / 0 / 1; `tabs404_probe` 29 / 0 / 1; `tabs405_probe` 7 / 0 / 1 (its HELD drag
  now lands in place 0 - the trap 405 recorded as "not a defect").
- clang-format 17.0.3 `--dry-run`: the changed lines are formatted.
- No UI string, menu or dialog changed: no `.slt` refresh.

## Reviews (findings and what was done)

1. No MUST; SHOULD: the title on the lifted fill had 4.13:1 - fixed (`SalTabActiveText`); NOTEs
   recorded (the tab no longer shares its directory line's colour; defect 2 is not a size
   difference; the 404 baseline is this feature's output inside the tab box).
2. No MUST; SHOULD: the halfway fallback could separate worse than the caption colour - fixed (the
   best-separating step); NOTEs: the title rule tried one pole only - fixed; a stale saltests
   comment - fixed; no probe row for the title - TITLE rows added (a decimal-comma parsing trap
   found and fixed). Its `tabs404_probe` run was ended by the harness; the reviewer restored the
   registry from the probe's backup and verified it identical.
3. No MUST ("ready to close"); SHOULD: the design documents described the review-1 rules - fixed;
   NOTE: tab characters in the fix-log - fixed.

## Owed to a person (the lines added to the release checklist)

Two lines added to `manual-checks-owed-before-the-next-release`:
- a real mouse drag of a non-first tab to the left end of the strip, in both panels and with more
  tabs than fit (feature 413);
- the Default and the Dark theme side by side, also at a scaling other than 100 %: equal height,
  the Dark inactive panel's active tab visible and its title readable, also with a user colour
  scheme; whether the Dark theme still looks lower anywhere (feature 413).

**CHANGELOG entry** (`CHANGELOG.md` has no unreleased section; versions are the maintainer's) - to be
added to the next release's section:

```text
- **A panel tab could not be dragged to the first place** (feature 413).
  - **Before:** a tab dragged to the left end of the tab strip stopped there and landed in the
    second place, in both panels; in the Dark theme the active tab of the inactive panel had
    almost the colour of the strip and the same colour as the path line under it, so the strip
    looked lower.
  - **Now:** a tab dragged to either end of the strip becomes the first or the last tab (of the
    tabs shown when not all fit). In the Dark theme the inactive panel's active tab is a lighter
    grey with a readable title, so it shows as a tab like in the default theme.
  - **Limitation:** the tab and the Dark theme's toolbar area keep their sizes - nothing was lower
    in pixels; the lighter tab no longer has its path line's colour.
```

## Findings fixed on the way (severity 5 or less, stop-rules rule 11)

- The `tabs404_probe` dark inactive expectation (it would have failed after the fix) - re-based,
  confined to the active tab's box.
- The reviews' SHOULD / NOTE findings above (all inside the item's scope).

## New Inbox items (slug - title)

None.
