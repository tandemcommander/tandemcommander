# Fix log - 413-tab-drag-first-place

Backlog item `panel-tabs-drag-to-first-place-and-dark-strip-height`. HEAD at the start: `75a45ea7`.

## Measurement before (step 3)

Probe `probe/tabs413_probe.ps1` (written for this feature in the style of `tabs404_probe`), hidden
desktop, Debug x64 build of HEAD, registry backed up and restored identical (SHA-256 0F9AD87C...).
Result: `probe/result_before.txt` - PASS 11, FAIL 7, NOT DRIVEN 1.

- **Drag**: left A B C D, D dragged far past the left end -> **A D B C** (second place); right
  P Q R S, S past the left end -> **P S Q R**; 30 tabs (8 visible from index 22), T29 dragged to the
  run's left end -> **index 23**. The NEAR / RIGHTEND rows of that run fail only because the earlier
  drags left another order (their own moves were right: C one place, P to the end). The before run
  used the first version of the expectations (the active index after LEFT / RIGHT and a row named
  INACTIVE, see *Probe corrections*); the orders it shows fail under the final expectations too.
- **Theme**: the session DPI is 96 (`AppliedDPI` 96, `GetDpiForSystem` 96, one 2560 x 1440 monitor
  - the maintainer's monitor at 100 %). Strip 29 px, directory line 23 px and the active tab on rows
  3-28 in **both** themes and both panels - nothing is lower in pixels. Colours (largest channel
  difference):

  | Theme / panel | active tab | strip | directory line band | tab vs strip | tab vs band |
  |---|---|---|---|---|---|
  | default / active | 99B4D1 | DEDEDE | F0F0F0 | 69 | 87 |
  | default / inactive | BFCDDB | DEDEDE | F0F0F0 | 31 | 49 |
  | dark / active | 264F78 | 242424 | 2D2D2D | 84 | 75 |
  | dark / inactive | 2D2D2D | 242424 | 2D2D2D | **9** | **0** |

  The dark inactive panel's active tab has the colour of the toolbar above the strip (2D2D2D) and of
  the directory line's band below it: a column through it reads `2D2D2Dx4 242424x3 2D2D2Dx9 101010`
  - the tab has no shape, the strip shows a gap; in the default theme the column reads
  `... FFFFFF DEDEDEx3 BFCDDB(26 rows) F0F0F0x2 A0A0A0`. The dark rebar is 69 px against 77 px
  (its bands draw no borders) - outside the tab strip, kept (clarification 3).
- Captures: `probe/captures_before/theme_{default,dark}_main.png`.

## Callers (fix protocol)

- `SalTabDragSlot`: one caller, `CTabWindow::UpdateDrag` (`src/tabwnd.cpp`), which clamps the left to
  `TabsLeft .. TabsLeft + (VisibleCount - 1) * TabWidth` and passes the run (`VisibleCount`,
  `DragIndex - FirstVisible`).
- `TabPaint.CapBk`: `PaintTabBack` (the active tab's shape with its feet) and `PaintTabFront` (the
  close glyph's background of the active tab). Set only in `CTabWindow::Paint`. No other user.
- FEATURE-HISTORY 404 / 405 read; 405 recorded the left-end trap as "not a defect".

## Decisions

1. Moving left, tab j gives way once the left is **at or below** j widths (a ceiling division);
   moving right unchanged (at or above). Both ends reachable under the caller's clamp; only lefts
   equal to a multiple of the width (moving left) change slot. Every 404 check keeps its value.
2. `SalTabActiveFill`: the caption colour unless it is within 24 of the strip or the face; then the
   smallest k / 100 (k <= 50) mix toward the caption text colour that reaches 24 from both; never
   under High Contrast. Dark inactive: 2D2D2D -> 454545 (k = 19). Default theme and dark active
   panel unchanged. Alternatives rejected in `research.md` (darker strip, outline, caption colour
   change, rebar).

## Changes

- `src/common/saltabs.cpp/.h`: `SalTabDragSlot` moving-left branch; `SALTAB_ACTIVE_MIN_CONTRAST`,
  `SalTabColorDistance`, `SalTabActiveFill`.
- `src/tabwnd.cpp`: `CTabWindow::Paint` takes the active tab's fill from `SalTabActiveFill`.
- `src/saltests/saltests.cpp`: `TestTabStrip413` (clamped lefts for every `from`, the multiples,
  the probe's values, a scrolled run, the fill rule in 7 cases).
- `specs/404-panel-tabs-rounded-look/probe/tabs404_probe.ps1`: LOOK-DARK INACTIVE compares with
  `evidence/variantF_dark_inactive_413.png` = the mockup with the box x 250..385, y 3..28 taken from
  the 413 capture. Checked first: against 404's own capture (`captures_after/`), all 3,035 changed
  pixels lie in that box (the active tab, index 2, spans x 256..379 plus its feet); against the
  mockup the capture differed in 2,174 failing pixels (max 24, the lift) and, outside the box, only
  in the antialiased edges 404 already tolerated.
- `help/src/hh/salamand/windows_tabstrip.htm`: the drag paragraph names the two ends.

## Probe corrections

- The first after run (`result_after.txt` before the correction): every order right, 3 FAIL rows on
  the active index - a press activates the pressed tab (404 DRAG shows the same: the dragged tab is
  the active one). LEFT and RIGHT now expect the dragged tab active (index 0); the row INACTIVE
  ("B, not active") was misnamed and is now AGAIN (B dragged to the left end, B active).

## Negative control

- saltests with the old moving-left line (`slot = cell + 1`) and `SalTabActiveFill` returning
  `capBk`: **14 failed** (11 drag checks - every clamped left 0 except `from` 0, the multiples, the
  scrolled run - and the 3 lift checks); restored -> 0 failed.
- The probe's before run is the GUI negative control (7 FAIL).

## After

| Check | Result |
|---|---|
| `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| `.\build.cmd` | BUILD SUCCEEDED |
| saltests | **282,670 checks, 0 failed** |
| `tabs413_probe` (`result_after.txt`) | **PASS 18, FAIL 0, NOT DRIVEN 1** - D -> D A B C, S -> S P Q R, B -> B D A C, T29 -> index 22; LOOK-DARK-INACTIVE 454545: 33 / 24; heights 29 / 23 / rows 3-28 unchanged |
| `tabs404_probe` (`result_tabs404.txt`) | PASS 29, FAIL 0, NOT DRIVEN 1 (dark inactive vs the 413 baseline: 0 failing; all other looks vs the mockups unchanged) |
| `tabs405_probe` (`result_tabs405.txt`) | PASS 7, FAIL 0, NOT DRIVEN 1; HELD now lands the dragged tab in place 0 (`B A A A B`, was `A B A A B` - the trap 405 recorded) |

No UI string, menu or dialog changed: no `.slt` refresh (stop-rules §2.13 not triggered).

## Owed to a person (release checklist)

- A real mouse drag of a non-first tab to the left end of the strip, in both panels: it becomes the
  first tab (feature 413).
- The dark and the default theme side by side (also at a scaling other than 100 %): the tab strip
  looks equally high, the inactive panel's active tab is visible in the dark theme (feature 413).

## Findings fixed on the way

- The `tabs404_probe` dark inactive expectation (would have failed after this fix) - see *Changes*.

## Review

(below)
