# Feature Specification: A folder picked in Browse is handed back whole or refused - also a folder shortcut's target

**Feature Branch**: `286-folder-shortcut-browse`
**Created**: 2026-10-21
**Status**: Draft
**Input**: Backlog item folder-shortcut-browse-result-max-path (backlog/items/folder-shortcut-browse-result-max-path/desc.md) - implement exactly what it describes. From backlog item folder-shortcut-browse-result-max-path.

## Background

Several places of the program let the user pick a folder in Windows' *Browse For Folder* dialog:
*Change Drive* > Network, the browse of a Copy / Move / Unpack target, Configuration > Drives
("If path is inaccessible go to"), the user-menu and Find dialogs, and plug-ins (Automation, FTP)
through the plug-in interface. They all go through one routine of the core (`GetTargetDirectory`).
Its caller provides a buffer of `MAX_PATH` (260) bytes - in the plug-in interface by contract
("min. MAX_PATH"). The program keeps paths as UTF-8, where a letter outside ASCII takes two to
four bytes, so a folder Windows can show (fewer than 260 UTF-16 units) may need more than 259
bytes.

When the picked folder is a *folder shortcut* (a folder holding `desktop.ini` that names the
folder-shortcut class and `target.lnk` - what Windows makes for a *network location* under This
PC / Network), the routine follows it to its target.

Measured at 7537240b (Debug build, hidden-desktop probe `fsc286_probe.ps1`, route Configuration >
Drives > browse button):

1. **A picked folder whose UTF-8 path does not fit** is handed back in the system code page
   instead: a folder of 90 CJK letters (147 units, 327 bytes) came back as a 146-byte path ending
   in `????...` - another, non-existent folder - and was put into the field without a word (row
   `pick-long` FAIL). A folder that fits came back whole (row `pick-ctl` PASS).
2. **A folder shortcut whose target needs 260 bytes or more** is not followed and not refused:
   the routine silently hands back the shortcut's own folder (code; its file-name buffers are also
   `MAX_PATH`, so a shortcut folder near the limit is silently not recognised as one). Windows'
   Browse tree does not list a folder shortcut that lies inside an ordinary folder (rows
   `fsc-long`, `fsc-ctl`, `fsc-long-init`), so this branch is reached through network locations
   and is proven against real folder shortcuts by unit checks.

## Clarifications

### Session 2026-10-21

- Q: Follow a long target whole, or refuse it? → A: refuse with "The path specified is too long." - every caller, including plug-ins by the interface's contract, holds the result in `MAX_PATH` bytes; widening the plug-in interface is the maintainer's (autonomous run: item - "or refused with `IDS_TOOLONGPATH`"; rule - plug-in interface is maintainer-owned)
- Q: What does the caller get after a refusal? → A: "nothing picked" - the same as Cancel in the Browse dialog: the field or panel keeps what it had (autonomous run: conservative - the existing cancel outcome)
- Q: A picked folder (not a shortcut) whose UTF-8 path does not fit - same treatment? → A: yes, refused with the same message; it is the same Browse result of `MAX_PATH` bytes the item names, and the code-page form is another folder (autonomous run: item; rule - a path is never cut, `A` APIs best-fit)
- Q: A folder shortcut whose target cannot be read (no `target.lnk`, a broken or non-file-system target)? → A: as before - the picked folder itself is handed back (autonomous run: conservative - keeps behaviour for cases the item does not name)
- Q: An item Windows gives no file-system path for at all? → A: "nothing picked" instead of "picked" with an undefined path (autonomous run: conservative - refuse rather than guess)
- Q: Should the Browse dialog's OK button stay enabled when the selected folder's path is too long for the caller? → A: yes - enabled as today (the code-page fallback enables it now); OK then shows the refusal, so the user learns why (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A folder whose path is too long for the caller is refused, not replaced (Priority: P1)

A user opens a Browse For Folder dialog from the program and picks a folder whose name uses many
letters outside ASCII, so its UTF-8 path needs more than 259 bytes. The program says "The path
specified is too long." and leaves the field (or panel) as it was. It never puts another folder's
path there.

**Why this priority**: measured and reachable with the default configuration; today a wrong
folder is handed on silently.

**Independent Test**: probe row `pick-long` (Configuration > Drives > browse button, the folder
picked in the tree, OK).

**Acceptance Scenarios**:

1. **Given** a folder of 90 CJK letters (327 bytes UTF-8), **When** the user picks it and presses OK, **Then** one message "The path specified is too long." is shown and the field keeps its previous text.
2. **Given** a folder of 20 CJK letters (fits), **When** the user picks it, **Then** the field holds its path whole and nothing is asked.

---

### User Story 2 - A folder shortcut with a long target is refused, not silently unfollowed (Priority: P1)

A user picks a network location (a folder shortcut) whose target path needs 260 bytes or more in
UTF-8. The program says "The path specified is too long." instead of silently handing back the
shortcut's own folder. A folder shortcut whose target fits is followed to the target as before.

**Why this priority**: the item's gap.

**Independent Test**: unit checks against real folder shortcuts in the temporary folder (a target
that fits, one that does not, one at the exact limit, not a folder shortcut, a folder shortcut with
no `target.lnk`); the GUI confirmation is owed to a person (network location in the user's profile).

**Acceptance Scenarios**:

1. **Given** a folder shortcut whose target needs 260 bytes or more, **When** it is picked, **Then** one "too long" message is shown and nothing is picked.
2. **Given** a folder shortcut whose target fits, **When** it is picked, **Then** the target is handed back whole.
3. **Given** a folder shortcut whose own path is near the limit (the shortcut folder fits, but the folder plus `\target.lnk` would not fit 260 bytes), **When** it is picked, **Then** it is still recognised and followed (or refused by its target's length), never silently handed back as itself.

### Edge Cases

- Target exactly 259 bytes (fits with the terminator): followed; 260 bytes: refused.
- `desktop.ini` that does not name the folder-shortcut class: the folder is an ordinary folder.
- Folder shortcut whose `target.lnk` is missing, unreadable or has no file-system target: the folder itself, as before.
- The Browse dialog's OK button: stays enabled for a file-system folder that is too long, so the user gets the message rather than a silently disabled button.
- Called from a plug-in's thread: the message is shown with the plug-in's window as owner, as other Browse messages.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A folder picked in Browse For Folder whose UTF-8 path does not fit the caller's buffer MUST be refused with "The path specified is too long." and reported to the caller as "nothing picked".
- **FR-002**: The picked folder's path MUST never be taken from the system code page (no best-fit or `?` replacement); it is the full Unicode path or nothing.
- **FR-003**: A picked folder shortcut whose target path fits MUST be followed to its target, whole (as today).
- **FR-004**: A picked folder shortcut whose target path does not fit the caller's buffer MUST be refused with the same message and reported as "nothing picked" - never handed back as the shortcut's own folder and never cut.
- **FR-005**: Recognising a folder shortcut and reading its target MUST not depend on a `MAX_PATH` limit of the shortcut folder's own path plus the file names `desktop.ini` / `target.lnk`.
- **FR-006**: Every case the item does not name (fitting folders, Cancel, unreadable shortcuts, non-file-system items' OK state) MUST keep its current behaviour, except that an item with no file-system path is "nothing picked" and that the same helper's other user (finding the Documents / Desktop folder) also no longer takes a code-page path - a Documents path that does not fit falls to the Desktop as when Documents is unavailable.
- **FR-007**: The plug-in interface (`GetTargetDirectory`, buffer of at least `MAX_PATH`) MUST stay unchanged.
- **FR-008**: The decision "folder shortcut? its target whole or too long" MUST be checked by unit checks against real folder shortcuts.

### Key Entities

- **Browse result**: the folder the user picked, as a UTF-8 path that fits the caller's buffer - or nothing.
- **Folder shortcut**: a folder with `desktop.ini` naming class `{0AFACED1-E828-11D1-9187-B532F1E9575D}` and `target.lnk`; its target is a path.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe row `pick-long` changes from FAIL (code-page path accepted) to PASS (refused, field unchanged); `pick-ctl` stays PASS.
- **SC-002**: Unit checks: a folder shortcut with a target of more than 259 bytes is reported "too long"; one at 259 bytes is followed whole; a negative control (the old rule) is shown to drop the long target.
- **SC-003**: Zero paths taken from the code page in the Browse routine (encoding guard `TOTAL: 0`).
- **SC-004**: Build, unit checks and the probe's control rows pass with no new failures.

## Assumptions

- Assumption (autonomous run): the GUI route of a network location with a long target cannot be driven without writing into the user's profile (*Network Shortcuts*); it is owed to a person as a `person-step` item.
- Assumption (autonomous run): the existing message `IDS_TOOLONGPATH` is used; no new UI string.
- Assumption (autonomous run): a folder longer than 259 UTF-16 units stays unpickable as today (Windows' Browse dialog itself is `MAX_PATH`-bound).
- Assumption (autonomous run): `desktop.ini` must name the folder-shortcut class exactly; the old prefix comparison (which also matched e.g. `{}`) was an accident.
- Assumption (autonomous run): the probe's fixture lives in a visible disposable folder (`build\probe286`) because the Browse tree hides the hidden AppData folder holding `%TEMP%` when Explorer hides hidden files.
