# Tasks: Dark theme: panel tabs look lower than in the default theme

**Input**: `specs/418-dark-rebar-borders/` (spec.md, plan.md, research.md)
**Tests**: requested by the item (measurement before / after) - a probe and a saltests check.

## Phase 1: Setup

- [ ] T001 Record the measurement before (both themes, rows of the rebar, the strip, the title) in specs/418-dark-rebar-borders/fix-log.md

## Phase 2: Foundational

- [ ] T002 Add a saltests check of the Dark etched pair (COLOR_BTNSHADOW darker, COLOR_BTNHIGHLIGHT lighter than COLOR_BTNFACE; both darker than the default theme's lines) in src/saltests/saltests.cpp

## Phase 3: User Story 1 - the same tab height and structure in both themes (P1)

**Goal**: the toolbar area and the panel tabs have the same rows in Dark as in the default theme.
**Independent test**: the probe measures the rebar height, the strip rows and the title position in both themes.

- [ ] T003 [US1] Keep WS_BORDER | RBS_BANDBORDERS in both themes and set the rebar colour scheme by theme in ThemeUpdateRebarStyle, src/themes.cpp
- [ ] T004 [P] [US1] Update the comments of the callers and the declaration in src/themes.h, src/mainwnd1.cpp, src/mainwnd3.cpp
- [ ] T005 [US1] Write the probe specs/418-dark-rebar-borders/probe/rebar418_probe.ps1 (rows DARK-REBAR-HEIGHT, DARK-STRIP-ROWS, DARK-TITLE-POS, DARK-LINES, DARK-NO-LIGHT-LINES, DARK-EDGES)

## Phase 4: User Story 2 - the default theme unchanged, theme switch (P2)

**Goal**: the default theme is pixel-identical to the build of main; switching the theme at run time gives the same picture as a fresh start.

- [ ] T006 [US2] Build main (HEAD0 f574e83e) into its own build folder for the Classic comparison (worktree in the scratchpad)
- [ ] T007 [US2] Probe rows CLASSIC-EQ (whole window, Default, this build vs main), SWITCH-TO-DARK and SWITCH-TO-LIGHT (run-time switch = fresh start), EXTRA-BARS (Plugins bar and a second drive bar shown, Dark rows framed like Default), NARROW (the window narrowed with two bands side by side: Dark rows = Default rows, lines follow) in specs/418-dark-rebar-borders/probe/rebar418_probe.ps1

## Phase 5: Polish

- [ ] T008 Build, saltests, check_encoding; run the probe; negative control on the main build (the Dark rows must FAIL there)
- [ ] T009 Independent refute-first review; fix MUST findings
- [ ] T010 Record after-measurement, review and results in specs/418-dark-rebar-borders/fix-log.md; FEATURE-HISTORY entry; closing-report.md

## Dependencies

T001 -> T002/T003 -> T004 -> T005 -> T006 -> T007 -> T008 -> T009 -> T010.
