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
| saltests | **282,670 checks, 0 failed** (282,681 after review 1) |
| `tabs413_probe` (`result_after.txt`) | **PASS 18, FAIL 0, NOT DRIVEN 1** - D -> D A B C, S -> S P Q R, B -> B D A C, T29 -> index 22; LOOK-DARK-INACTIVE 454545: 33 / 24; heights 29 / 23 / rows 3-28 unchanged |
| `tabs404_probe` (`result_tabs404.txt`) | PASS 29, FAIL 0, NOT DRIVEN 1 (dark inactive vs the 413 baseline: 0 failing; all other looks vs the mockups unchanged) |
| `tabs405_probe` (`result_tabs405.txt`) | PASS 7, FAIL 0, NOT DRIVEN 1; HELD now lands the dragged tab in place 0 (`B A A A B`, was `A B A A B` - the trap 405 recorded) |

No UI string, menu or dialog changed: no `.slt` refresh (stop-rules §2.13 not triggered).

## Owed to a person (release checklist)

- A real mouse drag of a non-first tab to the left end of the strip, in both panels: it becomes the
  first tab (feature 413).
- The dark and the default theme side by side (also at a scaling other than 100 %): the tab strip
  looks equally high, the inactive panel's active tab is visible in the dark theme (a lighter grey
  than its directory line, its title readable) (feature 413).

## Findings fixed on the way

- The `tabs404_probe` dark inactive expectation (would have failed after this fix) - see *Changes*.

## Review

### Review 1 (refute-first agent, 2026-11-07)

No MUST. Re-ran build, saltests (282,670 / 0), `tabs413_probe -Label review` (18 / 0 / 1), an
exhaustive old-vs-new comparison of `SalTabDragSlot` (1-9 tabs, 7 widths, every `from`, every
clamped left: both ends always reached, only moving-left exact multiples change, monotonic) and the
negative control (11 drag checks fail on the old rule).

- **SHOULD 1 (fixed)**: on the lifted fill 454545 the inactive caption text AAAAAA has 4.13:1
  (5.93:1 on 2D2D2D; the dark palette's pair is tested >= 4.5 in saltests). Fix: new pure rule
  `SalTabActiveText(capFg, capBk, fill)` - the caption text unless the fill was lifted and the text
  lost contrast; then mixed toward white (or black) by the smallest k / 100 that gives the contrast
  it had on the caption colour, at most 4.5:1 asked. Dark inactive: AAAAAA -> B2B2B2 (4.53:1; B1B1B1
  would be 4.49). `CTabWindow::Paint` sets `TabPaint.CapFg` from it (the title and the close glyph of
  the active tab). saltests +11 checks (282,681 / 0); negative control (the rule returning `capFg`):
  4 failed. The 404 baseline regenerated (against 404's own capture all 3,065 changed pixels lie in
  x 250..385, y 3..28).
- NOTE 1 (recorded): the dark inactive tab no longer has its directory line's colour (454545 over
  a 2D2D2D path field); everywhere else the tab and the path share the caption colour. Named in the
  release-checklist line.
- NOTE 2 (recorded): defect 2 is not a size difference; the fix addresses the measured cause (the
  invisible inactive-panel tab); the dark active panel is unchanged, and the dark strip still meets
  the toolbar with a step of 9 (2D2D2D / 242424) where the default theme has the rebar's etched
  line. The person check side by side decides whether more is wanted.
- NOTE 3 (recorded): inside the tab box the 404 dark inactive baseline is this feature's own output -
  it proves stability, not correctness; correctness is `tabs413_probe` LOOK and saltests.
- NOTE 4 (recorded): the GUI before run used the first expectation set; the unit negative control
  was reproduced by the reviewer.
- NOTE 5 (done at closing): FEATURE-HISTORY 413 corrects 405's "not a defect"; CHANGELOG entry.

T005: no comment in `src/tabwnd.cpp` / `saltabs.*` referred to the old slot 1 (Grep "slot 1",
"lands in slot": nothing).

After review 1: build SUCCEEDED, saltests **282,681 / 0**, encoding guard 0, `tabs413_probe`
**18 / 0 / 1**, `tabs404_probe` **29 / 0 / 1**, `tabs405_probe` **7 / 0 / 1**.

### Review 2 (refute-first agent, 2026-11-07)

No MUST. Re-ran saltests (282,681 / 0), `tabs413_probe` (18 / 0 / 1), checked B2B2B2 (4.52:1) in
the capture, the callers, the edge cases of review 1's rule against a Python copy; its
`tabs404_probe` run was ended by the harness after MOUSE CANCELMODE (every row reached passed); the
reviewer restored the registry from `%TEMP%	c404_backup.reg`, verified it identical (0F9AD87C...)
and removed the fixture - checked afterwards here: no backup, no `%TEMP%	c404`, no process left.

- **SHOULD 1 (fixed)**: when no step reached 24, `SalTabActiveFill` returned the halfway mix, which
  could be closer to the strip and the face than the caption colour (D0D0D0 with a white title in
  the default theme -> E8E8E8: 14 / 32 became 10 / 8; dark 444444 with a black title -> 222222).
  Now it returns the step (k = 0 included) with the largest smaller separation, the smallest k on a
  tie. saltests: the reviewer's two repros, the old halfway case (now 40,40,40) and a case whose
  best step lies in the middle (60 toward 0, strip 30 / face 70 -> 50,50,50).
- **NOTE 1 (fixed)**: `SalTabActiveText` tried only the pole away from the fill; when that pole
  could not give the contrast (25 of 200,000 random colour sets) the other one is now tried (a
  pole always reaches 4.5 or less: a mid grey has 4.58:1 to the better pole); saltests: title 20 on
  fill 90 (black gives 3.04, white 6.9) -> a light title with >= 4.5.
- NOTE 2 (recorded): the close glyph on the lifted fill is 979797 (3.28:1, was 4.04:1) - above 3:1
  for graphics.
- **NOTE 3 (fixed)**: the stale comment of a 404 check (`saltests.cpp`, "gives way below 100").
- **NOTE 4 (fixed)**: `tabs413_probe` rows TITLE-<theme>-<panel>: the title's most contrasting pixel
  against the fill, at least 4.5:1. Trap: the C# side formatted the ratio with the session's
  decimal comma and PowerShell parsed "4,52" as 452 - the first run passed for that wrong reason;
  now formatted and parsed invariant (9.80 / 12.97 / 8.50 / 4.52).
- NOTE 5 (recorded, as review 1 NOTE 2): the dark active panel and the dark rebar are unchanged;
  the person check decides.
- NOTE 6 (recorded): the interrupted 404 run, see above.

Negative control of these fixes: the review-1 version of `saltabs.cpp` (`git show HEAD:...`) fails
**5** of the new checks; restored -> 0 failed.

After review 2: build SUCCEEDED, saltests **282,686 / 0**, encoding guard 0, `tabs413_probe`
**22 / 0 / 1**, `tabs404_probe` **29 / 0 / 1**, `tabs405_probe` **7 / 0 / 1**.
