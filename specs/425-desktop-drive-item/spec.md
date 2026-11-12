# Feature Specification: A real Desktop drive item; Shell Folders named for what they are

**Feature Branch**: `425-desktop-drive-item`
**Created**: 2026-11-12
**Status**: Draft
**Input**: User description: "Backlog item ikona-na-desktop-vede-kamsi-neznamo-kam - implement exactly what it describes (GitHub issue #31: the drive menu's Desktop entry leads to a virtual fld: view instead of the Desktop folder)." From backlog item ikona-na-desktop-vede-kamsi-neznamo-kam.

## Clarifications

### Session 2026-11-12

- Q: Which hot key does the Folders plug-in's entry get once `'` belongs to the core Desktop item? → A: `-` - free and typed without a dead key on every enabled layout (review 1: the first choice, the backtick, is a dead key on the cs/sk/de/fr/hu layouts); `;` `,` `.` `/` are taken (autonomous run: conservative)
- Q: Do the plug-in's name and description in the Plugins manager change too? → A: No - only the drive-menu entry, which is the text that collides with Desktop; the description already says it browses folders "such as Desktop, Control Panel, Recycle Bin" (autonomous run: conservative)
- Q: Is the Desktop item checked in Alt+F1 when the panel shows the Desktop folder? → A: No - it behaves as the Documents item: the menu checks the drive the path is on (autonomous run: conservative)
- Q: What does Enter on a real folder inside `fld:` do when the folder cannot be opened (access denied, offline share)? → A: The program's ordinary change of a disk path decides and reports, exactly as when the user types that path (autonomous run: item - "the same as typing it")
- Q: Does the settings import from Altap / Open Salamander carry the new switch? → A: No - a value they never had keeps its default (on) (autonomous run: rule 245 FR-016)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Desktop opens the Desktop folder (Priority: P1)

A user opens the drive menu (Alt+F1 / Alt+F2) or looks at the drive bar and picks **Desktop**. The panel
shows their Desktop folder (for example `C:\Users\<user>\Desktop`, or the redirected / OneDrive
desktop) as an ordinary disk folder: the path line shows the real path and every file operation of a
disk panel works.

**Why this priority**: this is exactly what the reporter of GitHub #31 expected and did not get; the
current "Desktop" entry is taken for a fault.

**Independent Test**: start the program, Alt+F1, choose Desktop; the panel path equals the user's
Desktop folder as Windows reports it. The drive bar's Desktop button does the same.

**Acceptance Scenarios**:

1. **Given** the default configuration, **When** the user opens Alt+F1, **Then** an item "Desktop" with
   the hot key `'` is listed right after "Documents".
2. **Given** the drive menu is open, **When** the user chooses Desktop, **Then** the panel shows the
   Desktop folder's disk path.
3. **Given** the drive bar is shown, **When** the user clicks its Desktop button (tooltip "Desktop"),
   **Then** the panel shows the Desktop folder's disk path.
4. **Given** the Desktop item's switch is off on the Change Drive configuration page, **When** the menu
   or the drive bar is built, **Then** no Desktop item or button appears and every other item stays as
   before.
5. **Given** Windows reports no Desktop folder, or the folder does not exist, **When** the user chooses
   Desktop, **Then** an error message is shown and the panel stays where it was (never an empty path,
   never another folder such as the parent).

---

### User Story 2 - The Folders plug-in's entry says what it opens (Priority: P2)

The Folders plug-in's entry in the drive menu reads **Shell Folders** (in Czech, for example,
"Složky Windows"), not "Desktop", and does not use the Desktop item's hot key.

**Why this priority**: two entries both called "Desktop" leading to different places would keep the
confusion of #31 alive.

**Independent Test**: Alt+F1 lists the plug-in's item as "Shell Folders"; no other item has the hot key `'`.

**Acceptance Scenarios**:

1. **Given** the Folders plug-in is enabled (default), **When** Alt+F1 opens, **Then** the plug-in's item
   reads "Shell Folders" with a hot key other than `'`.

---

### User Story 3 - A real folder inside fld: opens as a disk path (Priority: P2)

Inside the plug-in's view (`fld:`), Enter on an item that is a real folder on disk (Documents, the
user's folder, a drive, a folder on the desktop) switches the panel to that disk path, the same as
typing it. Virtual places (This PC, Control Panel, Recycle Bin, Network, Libraries, …) stay in `fld:`.

**Why this priority**: today the user is trapped in `fld:` without the file operations of a disk
panel and has to type the path to get out.

**Independent Test**: in `fld:`, Enter on Documents → the panel is on the Documents disk path; Enter
on Control Panel → the panel stays in `fld:`; This PC stays in `fld:`, then Enter on drive C: → `C:\`.

**Acceptance Scenarios**:

1. **Given** the panel is at the root of `fld:`, **When** the user presses Enter on Documents, **Then**
   the panel shows the Documents disk path.
2. **Given** the panel is in `fld:`, **When** the user presses Enter on Control Panel (or This PC),
   **Then** the panel stays in `fld:` and lists that place.
3. **Given** a zip archive on the desktop (a shell folder whose path is a file), **When** the user
   presses Enter on it in `fld:`, **Then** the panel stays in `fld:` as today.
4. **Given** an item whose file-system path cannot be got, **When** the user presses Enter on it,
   **Then** the panel stays in `fld:`, as today.

### Edge Cases

- The Desktop folder is redirected (OneDrive, a network share): the item opens the redirected path.
- The Desktop path needs more bytes than the program's path buffer: it is refused with the "path too
  long" message, never cut.
- The Desktop path holds characters outside the code page (e.g. CJK): it is opened whole and exactly.
- A shell folder link (`.lnk` to a folder) inside `fld:`: its path is the link file, not a directory -
  it stays in `fld:` as today.
- The plug-in's stored drive-menu text of an existing configuration: it is replaced when the plug-in is
  next connected (every plug-in is connected again after an update of the program).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The drive menu and the drive bars MUST offer a core "Desktop" item right after
  "Documents", with the hot key `'`, its own icon from the active icon set (Fluent 2 and Classic), and
  the tooltip "Desktop" on the drive bar.
- **FR-002**: Choosing the Desktop item MUST open the user's Desktop folder (the known folder Desktop,
  redirection included) as a disk path, through the program's ordinary change of a disk path.
- **FR-003**: When Windows reports no Desktop path, or the folder does not exist or is not a
  directory, the Desktop item MUST show an error message and leave the panel unchanged; a path that
  does not fit MUST be refused with the "path too long" message, never cut.
- **FR-004**: The Change Drive configuration page MUST have a switch for the Desktop item beside the
  Documents switch, on by default; a configuration without the value MUST show the item; the value
  MUST be saved.
- **FR-005**: With the switch off, no Desktop item or button appears and every other item of the menu
  and the bars stays as it is with the switch on.
- **FR-006**: The Folders plug-in's drive-menu entry MUST read "Shell Folders" (translated), with a hot
  key that no core item uses (`'` belongs to Desktop).
- **FR-006a**: The plug-in's name and description in the Plugins manager stay as they are.
- **FR-007**: Inside `fld:`, Enter on an item that is a shell folder with a file-system path that is an
  existing directory MUST switch the panel to that disk path; every other item (virtual places, zip
  archives and links whose path is a file, items without a path) MUST behave as today.
- **FR-008**: Every new or changed UI string MUST be translated in all enabled languages (formal register).
- **FR-009**: A hidden-desktop probe MUST check each of the three points (the Desktop item's resulting
  path equals the known folder Desktop; the plug-in's text; Enter on Documents in `fld:` gives the disk
  path while Control Panel stays in `fld:`).

### Key Entities

- **Desktop drive item**: a drive-menu / drive-bar entry of its own type; shown when the configuration
  switch "Change Drive Show Desktop" is on (default on).
- **Shell Folders entry**: the Folders plug-in's drive-menu entry (text and hot key from its language file).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Choosing Desktop from the drive menu or the drive bar opens the Desktop folder in one step,
  in 100% of the probe runs (the panel path equals the Desktop folder Windows reports).
- **SC-002**: No two drive-menu entries share the text "Desktop" or the hot key `'`.
- **SC-003**: In `fld:`, Enter on Documents, the user's folder or drive C: leaves the panel on the
  matching disk path; Control Panel, This PC and a zip archive stay in `fld:` (probe rows).
- **SC-004**: A missing or path-less Desktop folder gives a message and leaves the panel where it was
  in 100% of the probe runs.

## Assumptions

- Assumption (autonomous run): the Fluent 2 icon of the existing "Open Desktop" toolbar command
  (`OpenDesktop`, light and dark) is the Desktop item's icon; Classic uses the Windows Desktop folder icon.
- Assumption (autonomous run): the Folders plug-in gets the hot key `-` (free: `;` Documents, `,`
  Network, `.` As Other Panel, `/` FTP and SFTP are taken).
- Assumption (autonomous run): the new configuration value is not carried by the Altap / Open
  Salamander settings import (rule 245 FR-016, as feature 374 did for WSL).
- Assumption (autonomous run): the switch to a disk path inside `fld:` uses the program's change of a
  disk path, which keeps its own messages for an inaccessible folder.
- Out of scope (maintainer decision 2026-11-12): a readable path inside `fld:` (for example
  `fld:\This PC\…`).
