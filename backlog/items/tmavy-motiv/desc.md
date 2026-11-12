---
title: Dark theme: black checkbox labels and old toolbar icons in plug-in windows
type: bug
status: open
severity: 4
area: other-plugins
source: github#25
who: agent
created: 2026-11-12
updated: 2026-11-12
verified: -
effort: M
feature: -
related: []
depends-on: []
reason: -
---

# Dark theme: black checkbox labels and old toolbar icons in plug-in windows

## Problem

A user of the Dark theme who opens plug-in windows finds them only partly dark:

- **Black checkbox labels on the dark background** (hard to read): in PictView's *Settings*, page *Advanced* (all four checkboxes), and in Batch Rename's main window (*Include subdirectories*, *Manual mode*, *Case sensitive*, *Whole words*, *Do not include extension*, *First in each name only*, *Regular expression*, *Include path*). The core's own *Configuration* dialog in the same screenshot draws its checkbox labels light.
- **Old toolbar icons not made for a dark background** in PictView and File Comparator (PictView's toolbar in the screenshot: 16-colour glyphs, several almost invisible on black).
- **Parts of some settings windows stay light grey** (the reporter does not say which; not visible in the screenshots).

## Evidence

- GitHub issue #25: https://github.com/tandemcommander/tandemcommander/issues/25 (2026-11-09, Czech UI) - original text in `issue.md`; version not stated (0.2.0 was the published one then; `v0.3.0` is tagged 2026-11-08). Screenshots in `evidence/`: `issue25-pictview-toolbar-and-configuration.png`, `issue25-pictview-settings-advanced.png`, `issue25-batch-rename.png`.
- Not reproduced yet; by reading at `f64d92d5`:
  - Plug-in dialogs built on winliblt get the core theme at `WM_INITDIALOG` (`src/plugins/shared/winliblt.cpp:691` dialogs, `:965` property-sheet pages) and the `WM_CTLCOLOR*` fallback (`:736`, `:1015`), which lands in `ThemeApplyChildEnumProc` (`src/themes.cpp:1110`): checkboxes keep the `DarkMode_Explorer` theme there ("renders ... checkboxes with light label text"), only radio buttons and group boxes go to classic drawing. Why the labels come out black in PictView and Batch Rename but light in the core's Configuration is not known.
  - Plug-in icons: feature 417 gave the plug-ins Fluent 2 icons (with Dark variants) for the core's menus and toolbars only; the plug-ins' own toolbars (PictView, File Comparator) still use their old bitmaps.

## Expected

In the Dark theme, with the default Fluent 2 icon set:

- every checkbox label in PictView's settings (all pages) and in Batch Rename draws in the theme's light text colour, as in the core's *Configuration*; a hidden-desktop probe checks the painted label pixels against the background (contrast at least 4.5:1), not only the control's theme;
- PictView's and File Comparator's toolbars show icons readable on the dark background (Fluent 2 with Dark variants, or at least the Dark palette applied); the Default theme and the Classic icon set stay unchanged (416);
- no light-grey area remains in those windows' dialogs and settings pages (probe: no large area of the classic `COLOR_BTNFACE` grey).

## Notes

Severity 4: a function does not work (labels hardly readable, the setting still works and can be read by switching to the Default theme) - one reporter, every Dark-theme user of these plug-ins; GitHub labels: bug, ai backlog.

- Area `other-plugins`: the item spans PictView, Batch Rename and File Comparator; the shared cause is probably in the plug-in theme path (winliblt / `ThemeApplyToDialog`, feature 036), not in one plug-in.
- Measure first: reproduce the black labels on the build; check the reporter's Windows version if needed (the `DarkMode_Explorer` checkbox text colour differs between Windows builds), and compare the controls' style bits and theme with the core's Configuration checkboxes.
- The light-grey areas are unnamed; a reply to the reporter (`reply.md`) can ask which windows.
- Related work: 036 (plug-in dark theme API), 044 / 049 (dark headers), 416 / 417 (icon sets, plug-in icons).

## Log

- 2026-11-12 — created (source github#25)
- 2026-11-12 — fields set from the issue text and labels
- 2026-11-12 — moved to Next position 3
