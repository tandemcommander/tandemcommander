# Feature Specification: Fluent 2 icons for the plug-ins; Appearance group renamed to Icon style

**Feature Branch**: `417-fluent-plugin-icons`
**Created**: 2026-11-07
**Status**: Draft
**Input**: User description: "Backlog item fluent-2-icons-for-the-plug-ins-appearance-group-renamed-to (backlog/items/fluent-2-icons-for-the-plug-ins-appearance-group-renamed-to/desc.md) - implement exactly what it describes." From backlog item fluent-2-icons-for-the-plug-ins-appearance-group-renamed-to.

## Clarifications

### Session 2026-11-07

- Q: Where a menu shows no icon today for a shipped plug-in without an icon (e.g. DBViewer in View With), does Fluent 2 show its set icon there? → A: yes - in Fluent 2 a shipped plug-in with a usable set icon counts as a plug-in with an icon in every list; Classic keeps today's rule (autonomous run: item)
- Q: Do the preview strips of the Appearance page change? → A: no - they stay the 10 toolbar buttons of 416; only the group label changes (autonomous run: conservative)
- Q: How is a plug-in recognised as a shipped one - also by a signature or version? → A: only by its location and name (`<id>\<id>.spl` in the program's plug-ins folder, a known id); a different plug-in installed under a shipped plug-in's name gets that plug-in's icon - a cosmetic effect only (autonomous run: conservative)
- Q: Which gray rule makes the gray copy of a set icon? → A: today's gray rule of plug-in icons (the brightness of each pixel, alpha kept) (autonomous run: item)
- Q: Is the Plugins bar rebuilt on every colour or theme change, also in Classic? → A: yes - its image lists are rebuilt from the active set on every colour change; in Classic the result is pixel-identical (autonomous run: recommended)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Plug-in icons in the same style as the rest of the window (Priority: P1)

A user runs Tandem Commander with the default icon set, Fluent 2 (feature 416). Everywhere the program shows a plug-in's own icon - the Plugins bar, the Plugins menu and its plug-in submenus, the lists of plug-ins in menus (configure, about, View With), the Plugins manager, the Change Drive menu, the drive bars, the tab of a plug-in file system and the icon at the start of that file system's directory line - the icon is drawn in the Fluent 2 style, sharp at every display scale, with a hand-made Dark variant in the Dark theme. Each shipped plug-in has an icon of its own; no two shipped plug-ins look alike.

**Why this priority**: it is the main point of the item - next to the Fluent 2 toolbar the plug-in icons look like another program.

**Independent Test**: start the program with Fluent 2 and the Plugins bar shown, capture the Plugins bar, the drive bar, the Plugins manager and a plug-in file system's directory line and tab in Light and Dark; every plug-in icon there is its Fluent 2 icon, none is empty.

**Acceptance Scenarios**:

1. **Given** Fluent 2 and the Plugins bar shown, **When** the window is drawn, **Then** every button of the Plugins bar shows the Fluent 2 icon of its plug-in (7-Zip, Checksum, DiskMap, File Comparator, FTP, PictView, RegEdit, Renamer, SFTP, Undelete, ZIP in the shipped configuration).
2. **Given** Fluent 2, **When** the drive bar or the Change Drive menu lists the plug-in file systems (FTP Client, SFTP Client, Desktop = Folders, Windows Registry, Undelete, Portable Devices), **Then** each shows its plug-in's Fluent 2 icon; the drives keep their Fluent 2 drive icons of 416.
3. **Given** Fluent 2, **When** the Plugins manager lists the plug-ins, **Then** every shipped plug-in shows its Fluent 2 icon - including DBViewer, PEViewer, TAR and UnCAB, which have no icon of their own today, and SFTP, which shows the generic plug today.
4. **Given** Fluent 2 and a panel on a plug-in file system (e.g. Windows Registry or Undelete), **When** the directory line and the tab are drawn, **Then** both show that plug-in's Fluent 2 icon; **given** the Folders file system, **Then** the directory line keeps the shell icon of the current folder (it shows where the panel is).
5. **Given** the Dark theme, **When** any of these icons is drawn, **Then** the hand-made Dark variant is used as drawn.
6. **Given** a display scale of 125-200 %, **When** these icons are drawn, **Then** they are rendered at the size of the list that shows them (not a stretched 16-pixel picture).

---

### User Story 2 - Classic stays exactly as it is (Priority: P1)

A user who chose Classic in Configuration > Appearance sees every plug-in icon exactly as before this feature, pixel for pixel. Switching between the sets applies at once, without a restart, and the icons the program remembers for plug-ins that are not loaded are never replaced.

**Why this priority**: the switch is the promise of 416; a change that leaks into Classic or survives a switch back breaks it.

**Independent Test**: with Classic, capture the same parts as story 1 on this build and on the build of `main`; they are identical. Switch Classic -> Fluent 2 -> Classic in the Appearance page with OK; each step shows the set's plug-in icons without a restart.

**Acceptance Scenarios**:

1. **Given** Classic, **When** the Plugins bar, drive bar, Plugins manager, directory line and tabs are drawn, **Then** they are pixel-identical to the build of `main`.
2. **Given** Fluent 2 active, **When** the user chooses Classic and presses OK (or the other way round), **Then** the Plugins bar, the drive bars, the tabs and the directory lines show the chosen set's plug-in icons at once; menus opened afterwards show them too.
3. **Given** a theme switch (Light <-> Dark) or an imported configuration that changes the set, **When** the program rebuilds its icons, **Then** the plug-in icons follow, the Plugins bar included.
4. **Given** any sequence of switches, **When** the program saves its configuration, **Then** the plug-ins' icons stored in the configuration are the plug-ins' own icons, never a set icon.

---

### User Story 3 - A general name for the setting (Priority: P2)

The Appearance group now governs all icons, not only the toolbar's, so it reads "Icon style" in English and the matching text in every enabled language.

**Why this priority**: the maintainer's wording; visible but small.

**Independent Test**: open Configuration > Appearance in English and in each enabled language; the group label is the new text, it fits, and its access key works.

**Acceptance Scenarios**:

1. **Given** English, **When** the Appearance page opens, **Then** the group is labelled "Icon style" and Alt+I moves to it (the access key stays on "I").
2. **Given** any enabled language, **When** the page opens, **Then** the label is the translation of "Icon style", in the formal register, not cut off.

---

### User Story 4 - Third-party plug-ins and damaged installations (Priority: P3)

A user has a plug-in from another author, or an installation where a set file is missing or broken. The third-party plug-in keeps its own icon; one without an icon shows the Fluent 2 default plug-in icon instead of the old plug. A missing or unusable set file never leaves an empty slot: the plug-in's icon of today is shown.

**Why this priority**: robustness and fairness to other authors; rare.

**Independent Test**: in a copy of the build, remove or empty one plug-in's set file and add a plug-in folder that is not a shipped one; that plug-in shows today's icon, the other its own, no slot is empty.

**Acceptance Scenarios**:

1. **Given** a plug-in that is not one of the plug-ins shipped with the program, **When** Fluent 2 is active, **Then** its own icon is shown; **if** it has none, the Fluent 2 default plug-in icon (and the Fluent 2 default file-system icon where a file system without an icon is shown).
2. **Given** a shipped plug-in whose set file is missing, empty or not parseable, **When** Fluent 2 is active, **Then** today's icon of that plug-in is shown (its own, or the default one).

---

### Edge Cases

- A plug-in loaded from outside the program's plug-ins folder, or whose file name differs from its folder name, is not a shipped plug-in (no set icon).
- A plug-in name is compared by the file system's rule (case-insensitive ordinal), so `FTP\Ftp.spl` is the FTP plug-in.
- A plug-in whose icon list failed to load (SFTP today) still gets its set icon in Fluent 2; in Classic it keeps what it shows today.
- The gray copy of a plug-in icon (a disabled menu item, the gray drive-bar picture) is made from the set icon by today's gray rule.
- The Folders file system's directory-line icon is never replaced (it carries the current folder's identity); its Plugins / Change Drive icon is.
- The plug-ins' own windows, toolbars, dialog icons and the icons of the items they list are not part of this feature.
- A long or non-ASCII installation path: the set file path is built without cutting; a path that does not fit gives today's icon.
- The tab strip caches plug-in icons: after a set or theme switch the cache is rebuilt, never a stale set's icon.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: With Fluent 2 active, every site where the program draws a plug-in's identity icon MUST draw the plug-in's Fluent 2 icon when the plug-in is a shipped one and its set file is usable: the Plugins bar, the Plugins menu and its plug-in submenus, the plug-in lists in menus (configure, about, View With), the Plugins manager, the Change Drive menu and the drive bars, the tab of a plug-in file system, the drive-list row of an open plug-in file system, the file-system list of the Disconnect dialog, and the directory line of a plug-in file system.
- **FR-002**: A plug-in is a shipped one when it is loaded from the program's plug-ins folder as `<id>\<id>.spl` (case-insensitive) and `<id>` is one of the 31 known plug-in ids (7zip, automation, checksum, checkver, codeview, dbviewer, demomenu, demoplug, demoview, diskmap, filecomp, folders, ftp, mdview, mmviewer, nethood, peviewer, pictview, portables, regedt, renamer, sftp, tar, uncab, unchm, undelete, uniso, unmime, unole, unrar, zip); anything else gets no set icon.
- **FR-003**: The directory line (and the drive-list row and Disconnect-dialog row of an open file system) MUST keep the icon the Folders plug-in returns for its current folder; for the other shipped file-system plug-ins (FTP, SFTP, RegEdit, Undelete, Portables, Nethood, DemoPlug) the set icon replaces the one the plug-in returns.
- **FR-004**: A shipped plug-in that has no icon of its own today MUST show its Fluent 2 icon wherever the program shows a plug-in icon or the default plug-in icon in Fluent 2; a menu that shows no icon for a plug-in without an icon today shows its set icon in Fluent 2.
- **FR-005**: With Fluent 2 active, where the program shows its default plug-in icon or default file-system icon for a plug-in that has no icon and no set icon, it MUST show the Fluent 2 default plug-in icon / default file-system icon.
- **FR-006**: Set icons MUST be rendered at the pixel size of the list or control that shows them; in the Dark theme the hand-made Dark variant is used verbatim when usable (the 416 rules: otherwise the standard file adapted, otherwise today's icon).
- **FR-007**: A missing, empty or unparseable set file MUST give the icon that site shows today; a slot is never empty.
- **FR-008**: With Classic active, every plug-in icon MUST be pixel-identical to the build of `main`.
- **FR-009**: A change of the set (Appearance OK, a settings import) and a theme switch MUST rebuild the plug-in icons of the Plugins bar, the drive bars, the tabs and the directory lines at once, without a restart; menus and dialogs opened later use the active set.
- **FR-010**: The plug-in icons stored in the configuration MUST stay the plug-ins' own icons; no set icon is ever written there, and the plug-in interface does not change.
- **FR-011**: The gray copy of a set icon MUST be made by the same gray rule as today's gray copies of plug-in icons (each pixel's brightness, alpha kept).
- **FR-015**: Every colour change (a theme switch, a set switch, a system colour change) MUST rebuild the Plugins bar's image lists from the active set.
- **FR-012**: The Appearance group label MUST read "Icon style" with the access key on "I"; the stored value keeps its name ("Toolbar Icon Set") and meaning; every enabled language gets the new label in the formal register, fitting its control; the choices and their preview strips stay as in 416.
- **FR-013**: The set MUST ship one file per known plug-in id plus the two default icons, each with a hand-made Dark variant, made by a committed generator from the pinned Fluent source of 416; the set checker MUST verify every name the program can ask for exists in both variants and passes the 416 file rules (no transparent-key colours, parseable by the program's SVG reader).
- **FR-014**: Every set file MUST pass the 416 legibility criterion on the bar, on the menu highlight and in the Change Drive menu highlight, in Light and Dark, at 16, 20, 24 and 32 px.

### Key Entities

- **Plug-in id**: the name of a shipped plug-in (its folder and file name); maps a loaded plug-in to its set file.
- **Plug-in set icon**: `iconsets\fluent\plugins\<id>.svg` and `iconsets\fluent\plugins\dark\<id>.svg`; two default icons for plug-ins without an icon (plug-in, file system).
- **Identity-icon file system**: a shipped file-system plug-in whose directory-line icon is its own identity (all except Folders).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With Fluent 2, the Plugins bar differs from Classic in every plug-in button (measured: today only the drop-down arrows differ, 242 px), and every plug-in button shows its set icon (more than 8 colours per icon cell, none blank).
- **SC-002**: With Classic, the Plugins bar, the drive bar, the directory line of a plug-in file system and the Plugins manager list are pixel-identical to the build of `main` (0 px), in Light and Dark.
- **SC-003**: All 20 plug-ins enabled in the shipped configuration have a Fluent 2 icon of their own; no two of them are identical.
- **SC-004**: After a switch of the set with OK, the Plugins bar and the drive bar equal a fresh start in the chosen set (0 px), without a restart.
- **SC-005**: Every one of the 33 + 33 set files is rasterized at 16 / 20 / 24 / 32 px with non-zero coverage and meets the 416 legibility criterion on all backgrounds.
- **SC-006**: The new group label fits its control in English and the 8 enabled languages.

## Assumptions

- Assumption (autonomous run): the generator and the approved design come from the maintainer's study (2026-11-07); the files are its output with the RegEdit drawing the maintainer approved in three rounds.
- Assumption (autonomous run): "the plug-ins shipped with the program" are recognised by their DLL name (`<id>\<id>.spl` in the plug-ins folder) and a fixed list of 31 ids; files are also shipped for the plug-ins that are `off` in `plugins.cfg` (shipping a plug-in stays the maintainer's).
- Assumption (autonomous run): the plug-ins' own windows, toolbars and listed-item icons are out of scope (the item: "the plug-ins' own windows and toolbars" do not change).
- Assumption (autonomous run): SFTP showing the generic plug in Classic (it never hands its bitmap to the program) is kept in Classic, because Classic must stay pixel-identical; Fluent 2 shows its set icon.
- Assumption (autonomous run): `PRIVACY.md` is not affected: no network, no new stored data; the installer ships the new folder through its existing recursive entry, as 416's set.
- Menus, hot and pressed states and 125-200 % cannot be driven on the hidden desktop (as in 416); they are covered by rasterization tests and a line of the release checklist.
