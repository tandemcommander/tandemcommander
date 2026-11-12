# Tasks: Plug-in toolbars and chrome in the Dark theme

**Input**: spec.md, plan.md, research.md, quickstart.md
**Tests**: required (FR-006: a probe before / after; saltests for the shared helper).

## Phase 1: Setup

- [X] T001 Start `specs/427-dark-plugin-toolbars/fix-log.md` with the measurement of step 3 (`probe/result_measure_before.txt`, the checkbox experiment)

## Phase 2: Foundational

- [X] T002 Write the feature probe `specs/427-dark-plugin-toolbars/probe/dark427_probe.ps1` (Dark and Default; rows PV-TOOLBAR, FC-TOOLBAR, FC-GREY, PV-LABELS, RN-LABELS, DEFAULT-SAME; registry backup / restore) and run it on the unchanged build (`-Label before`); record in the fix-log
- [X] T003 Move the bitmap walk of `ThemeAdjustBitmapForDarkMode` (`src/themes.cpp`) into the header-only `src/common/themes_bitmap.h` (`ThemeDarkAdaptBitmap`); the core function calls it
- [X] T004 Add a saltests check of `ThemeDarkAdaptBitmap` (a small 32-bit bitmap: black, key magenta, white, dark blue, a transparent pixel) in `src/saltests/`

## Phase 3: User Story 1 - toolbar glyphs (P1)

- [X] T005 [US1] PictView: `CViewerWindow::InitializeGraphics` (`src/plugins/pictview/pictview.cpp`) adapts the colour bitmap in Dark before the grey and mask bitmaps
- [X] T006 [US1] File Comparator: the toolbar bitmap (`src/plugins/filecomp/mainwnd.cpp`) adapted in Dark with the mapped background as the key

## Phase 4: User Story 2 - File Comparator chrome (P1)

- [X] T007 [US2] Rebar background, text and colour scheme in Dark (`src/plugins/filecomp/mainwnd.cpp`); `ThemeApplyToDialog` on the main window after its children exist
- [X] T008 [US2] Theme brushes / colours instead of the system ones in `src/plugins/filecomp/controls.cpp` (splitter fill, band text area and text colour, the two `WM_CTLCOLORSTATIC` brushes)

## Phase 5: User Story 3 - checkbox labels (P2)

- [X] T009 [US3] Draft `reply.md` for GitHub #25 asking for the Windows build; an Inbox item (leftover:427) for the black checkbox labels with the measurement

## Phase 6: Polish

- [X] T010 Build, saltests, encoding guard; the probe `-Label after`; before / after in the fix-log
- [X] T012 Review 1: the live theme switch (PictView refill, File Comparator RefreshThemeChrome), the 3:1 lift (`ThemeDarkAdaptBitmapLift`, saltests), probe rows PV-COLOR / FC-COLOR / LIVE
- [X] T013 Review 2: the band colours (RBBIM_COLORS) for a window opened in Default, the refill only with new bitmaps, the repaint of every window of the viewer's thread, `math.h`; probe rows LIVE-D
- [ ] T011 FEATURE-HISTORY, CHANGELOG, closing report (step 8 of the run)

## Dependencies

T002 before any code change (the before run); T003 before T005-T006; T010 after T005-T008.
