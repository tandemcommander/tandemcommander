# Feature Specification: Fluent toolbar icon set by default, switchable to Classic in Appearance

**Feature Branch**: `416-fluent-icon-set`
**Created**: 2026-11-07
**Status**: Draft
**Input**: User description: "Backlog item fluent-icon-set-with-switch-in-appearance (backlog/items/fluent-icon-set-with-switch-in-appearance/desc.md) - implement exactly what it describes." From backlog item fluent-icon-set-with-switch-in-appearance.

## Clarifications

### Session 2026-11-07

- Q: Which 10 icons does each preview strip show? → A: Back, Parent Directory, Create Directory, Find, Views, Refresh, Copy, Delete, Select, Pack - one or two per group of the default top toolbar, including a Selection button (raster in Classic) so the difference between the sets is visible (autonomous run: recommended)
- Q: When does a changed set apply - OK only, or also a separate Apply? → A: when the Configuration dialog commits its pages (OK) and after a settings import, through the same refresh; no separate Apply path is added (autonomous run: conservative)
- Q: What does a missing Fluent 2 file do? → A: the site keeps what Classic draws there (raster glyph, Windows icon, old `..` icon, old arrow), never an empty cell or a crash (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A consistent, legible icon set out of the box (Priority: P1)

A user starts Tandem Commander (a fresh installation or an upgrade from 0.2.0 that never chose a set). The top toolbar, the panel toolbars, the menus, the drive bar, the Change Drive menu, the configuration-list toolbars and the `..` symbol of the file list all show one consistent icon style ("Fluent 2"), legible in the light and in the Dark theme, in every button state and at every common display scale.

**Why this priority**: the maintainer chose Fluent 2 as the default; it is the main point of the item.

**Independent Test**: start the program with a configuration that has no icon-set value; capture the toolbar, drive bar, file list and a menu in both themes at 100 % and 150 %; every button that has an image shows its Fluent 2 icon (none empty, none a Windows shell icon, none a 16-colour raster glyph).

**Acceptance Scenarios**:

1. **Given** a configuration without an icon-set value, **When** the program starts, **Then** every toolbar button with an image (85, including the 14 Selection buttons, Shared Directories and the 9 system-folder buttons) shows its Fluent 2 icon.
2. **Given** the Dark theme, **When** the toolbar is drawn, **Then** the hand-made dark variants of Fluent 2 are used as drawn, without automatic recolouring.
3. **Given** Fluent 2, **When** the drive bar or the Change Drive menu lists fixed, system, removable, CD, network, unavailable network or RAM drives, Documents or Network, **Then** each shows its Fluent 2 icon; cloud services (OneDrive, Google Drive, Dropbox) and WSL keep their brand icons, plug-in file systems and archives keep their icons.
4. **Given** Fluent 2, **When** a panel lists a folder with `..`, **Then** the `..` symbol is the Fluent 2 one (an angular up arrow whose stem turns right, plus two square dots, in the navigation blue) at 16, 32 and 48 px.

---

### User Story 2 - Switching back to Classic in Configuration > Appearance (Priority: P1)

A user who prefers the old look opens Configuration > Appearance, sees a group with one choice per icon set, each with a preview strip of about 10 icons drawn as they will look, chooses Classic and presses OK. The whole window switches at once, without a restart, to exactly the look of 0.2.0. The choice survives a restart.

**Why this priority**: the switch and its preview are required by the item together with the default; without it the change takes away the old look.

**Independent Test**: choose Classic, press OK, capture the window; compare with 0.2.0 / Classic captures (pixel equal); restart and see Classic again; choose Fluent 2 and see it again.

**Acceptance Scenarios**:

1. **Given** the Appearance page, **When** it opens, **Then** it shows a group "Toolbar icons" with the choices "Fluent 2" and "Classic", the current set selected, and next to each choice a preview strip of 10 icons of the default top toolbar in the active theme.
2. **Given** Classic was chosen, **When** the user presses OK, **Then** the toolbars, menus, drive bar, panels' drive icons, tabs, `..` symbol and drop-down arrows switch to Classic at once, the same way a theme switch rebuilds them.
3. **Given** Classic chosen and saved, **When** the program restarts, **Then** Classic is used.
4. **Given** Classic, **When** the user compares any icon with 0.2.0, **Then** it is identical (SVG overlays, raster glyphs, Windows shell and imageres icons, the old `..` icon, the old drop-down arrow).

---

### User Story 3 - A broken hand-made dark icon never blanks a button (Priority: P2)

An icon author (or a damaged installation) leaves a dark override that cannot be parsed or has no shapes. The button falls back to the standard icon of the set instead of becoming empty, as the dark-override contract of feature 029 promises.

**Why this priority**: robustness defect the new set depends on (its 95 dark variants); less visible than stories 1-2.

**Independent Test**: put an empty and an unparseable dark override for one icon, switch to Dark, the button shows the standard icon (adapted for dark), the program does not crash.

**Acceptance Scenarios**:

1. **Given** a dark override with no shapes, **When** the Dark theme is active, **Then** the button shows the set's standard SVG with the automatic dark adaptation.
2. **Given** a standard SVG that cannot be parsed, **When** the image lists are built, **Then** the program does not crash and the cell keeps what was below it (the raster glyph in Classic).

---

### Edge Cases

- The registry value is missing, of the wrong type or holds an unknown number: Fluent 2.
- A Fluent 2 file is missing from the installation (damaged install): the button shows the Classic raster glyph below it (as today when an SVG is missing), never a crash; a missing Fluent drive or `..` icon falls back to the Classic icon of that site.
- The program folder path is long or outside the code page: the icon path is built in UTF-8 and opened wide (feature 171); a path that does not fit the buffer is refused (the icon is skipped, falls back), never cut.
- High DPI: the icons are rasterized at the icon size of the system DPI (16, 20, 24, 32 px at 100/125/150/200 %).
- The Appearance page is opened in Dark: the previews are drawn in the Dark theme.
- Settings import (feature 245) of an old configuration without the value: Fluent 2; an imported value is applied by the same refresh as the Configuration dialog's OK.
- The image-list mask keys (magenta and the toolbar background colour) must never appear as a colour inside a Fluent icon, or that part would turn transparent.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The program MUST offer two icon sets: **Fluent 2** (default) and **Classic** (today's look).
- **FR-002**: The chosen set MUST be stored as a number under the configuration root (`SALAMANDER_ROOT_REG`, value "Toolbar Icon Set", 0 = Fluent 2, 1 = Classic); a missing or unknown value MUST mean Fluent 2, also after an upgrade.
- **FR-003**: Classic MUST draw exactly what 0.2.0 draws at every icon site this feature touches.
- **FR-004**: Fluent 2 MUST give an icon to all 85 toolbar buttons that have an image, including the 14 Selection buttons, Shared Directories (on the Shared Directories button, not on Zoom Panel) and the 9 system-folder buttons (which then do not show Windows shell icons).
- **FR-005**: Fluent 2 MUST give icons to the drive bar and the Change Drive menu for fixed, system, removable, CD, network, unavailable network and RAM drives, and for Documents and Network; also to the panel's drive icon, the tab icons and the Drive Information dialog, which use the same drive icons. Cloud services, WSL, archives and plug-in file systems keep their icons.
- **FR-006**: Fluent 2 MUST replace the `..` symbol of the file list at 16, 32 and 48 px with its own `UpDir` icon of today's shape.
- **FR-007**: Fluent 2 MUST give icons to the configuration-list toolbar (Modify, New/Insert, Delete, Sort, Move Up, Move Down) and its drop-down arrow a Fluent chevron whose disabled colour is the theme's grey-text colour.
- **FR-008**: In the Dark theme, a set's hand-made dark variant MUST be used verbatim; a dark variant that cannot be parsed or has no shapes MUST fall back to the set's standard icon with the automatic dark adaptation; an icon that cannot be parsed at all MUST NOT crash the program or blank its cell.
- **FR-009**: Configuration > Appearance MUST show a group "Toolbar icons" with one choice per set; each choice MUST show a preview strip of 10 icons of the default top toolbar (Back, Parent Directory, Create Directory, Find, Views, Refresh, Copy, Delete, Select, Pack), drawn in the active theme by the same image-list building code the toolbars use.
- **FR-010**: OK in the Configuration dialog (and a settings import) MUST apply a changed set at once, without a restart, rebuilding every icon site as a theme switch does.
- **FR-011**: No Fluent 2 icon may disappear on the toolbar (light / dark; normal / hot / pressed / checked / disabled) or on the menu highlight, at 100 / 125 / 150 / 200 % DPI.
- **FR-012**: The Fluent 2 icons, their dark variants and the Microsoft Fluent UI System Icons licence (MIT) MUST be deployed with the program (build tree and installer); `doc/third_party.txt` MUST name the Fluent glyphs and their licence.
- **FR-013**: The generator of the Fluent 2 set and its mapping MUST live in the repository with a README that pins the source package (name, version, sha512) and says how to regenerate; the source package itself is not vendored.
- **FR-014**: New UI strings MUST be translated for every enabled language by the two-stage `.slt` refresh in this feature; the Appearance labels MUST not be clipped in the 8 shipped languages.
- **FR-015**: Pure rules (the set from the registry value; the path of a set's icon file, refused when it does not fit) MUST have `saltests` checks.

### Key Entities

- **Icon set**: Fluent 2 or Classic; has a folder of standard SVGs, a folder of dark variants, and per-site choices (shell icons vs own SVGs, `..` icon, drop-down arrow).
- **Toolbar Icon Set setting**: a number in the configuration; default Fluent 2.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With no stored set, 85 of 85 toolbar buttons with an image show a Fluent 2 icon (probe: non-background pixels in every cell, 0 empty cells) in light and dark at 100 % and 150 %.
- **SC-002**: With Classic chosen, the toolbar image list is pixel-identical to the one of the build before this feature (probe compares the captured strips: 0 differing pixels).
- **SC-003**: Switching the set on the Appearance page and pressing OK changes the toolbar within the same session (probe: the strip changes without restart), and the choice is read back after a restart.
- **SC-004**: An empty dark override yields a non-empty button (probe row), before: an empty button.
- **SC-005**: Every Fluent 2 icon's dominant colour reaches at least 3:1 contrast against the toolbar background in both themes (checked by the generator's palette and the probe's pixel samples).
- **SC-006**: The Appearance page labels fit their controls in all 8 shipped languages (probe measures text extent against control width: 0 clipped).

## Assumptions

- Assumption (autonomous run): the Classic table keeps the 0.2.0 row mix-up (`SharedDirectories` on the Zoom Panel row, the raster glyph on Shared Directories) so Classic stays pixel-identical (item: "Classic is today's look, pixel for pixel"); the mix-up is fixed in the Fluent 2 name table.
- Assumption (autonomous run): Classic stays in `src/res/toolbars/` deployed as `toolbars\` (the feature-029 override contract keeps its paths); Fluent 2 lives in `src/res/iconsets/fluent/` deployed as `iconsets\fluent\` and `iconsets\fluent\dark\` (least risk, item Approach 1).
- Assumption (autonomous run): Documents and Network on the drive bar / Change Drive menu get the Fluent 2 `OpenDocuments` / `OpenNetwork` icons (the study's mock-up shows them; item: Fluent 2 covers every icon the study covers).
- Assumption (autonomous run): the Change Drive buttons' slots (live drive icon) get the Fluent `ChangeDrive` icon as their default image in Fluent 2.
- Assumption (autonomous run): the drop-down arrow's GRAYTEXT disabled colour applies to Fluent 2 only; Classic keeps BTNSHADOW (pixel-identical).
- Assumption (autonomous run): the Fluent licence ships as `iconsets\fluent\LICENSE-fluent.txt` inside the deployed set folder (the installer takes the build tree recursively; no installer script change) and is named in `doc/third_party.txt`, which refers to `doc/license/license_mit.txt`.
- `PRIVACY.md` is not affected: no network communication, the new registry value is a display setting among "the settings" the statement already describes, nothing about credentials or the installer's writes changes (confirmed in the record).
- Plug-in icons, button-state drawing (bevels), menu highlight, F-key bar and disabled menu-icon style are out of scope (item *Notes*).
- The visual check of both sets on the maintainer's screen (both themes, the maintainer's DPI) is a line of the release checklist (item *Notes*, `who: both`).
