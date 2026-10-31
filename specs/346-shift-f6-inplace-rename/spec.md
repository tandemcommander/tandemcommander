# Feature Specification: Shift+F6 renames the focused item in place

**Feature Branch**: `346-shift-f6-inplace-rename`  
**Created**: 2026-10-31  
**Status**: Draft  
**Input**: User description: "Backlog item shift-f6-renames-the-focused-item-in-place-without-the - implement exactly what it describes." From backlog item shift-f6-renames-the-focused-item-in-place-without-the.

## Clarifications

### Session 2026-10-31

- Q: When a user already bound a plug-in command to Shift+F6, which runs on Shift+F6 in a panel? → A: the user's plug-in command keeps running (it is kept at load and takes precedence); Plugins Manager and the settings import refuse Shift+F6 as a new binding, like every other program key (autonomous run: conservative; precedent 312 `IsSalHotKeyKeptAtLoad`)
- Q: What is the menu command called and where is it? → A: Files menu, right after *Quick Rename... F2*, text *Rename in Place* with the shortcut Shift+F6, same enable rule as the in-place rename, same skill levels as *Quick Rename* (autonomous run: recommended)
- Q: Does Shift+F6 work while the command line has the focus? → A: no, unchanged; the item names panels only and the menu command covers the other case (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Rename the focused item in place from the keyboard (Priority: P1)

A keyboard user (often coming from Total Commander) focuses a file or folder in a disk panel and
presses Shift+F6. An edit field opens right over the item's name in the panel, with the same text
selected as when the in-place rename is started with a slow click. The user types the new name and
presses Enter: the item is renamed and stays focused. Esc closes the field and nothing changes.

**Why this priority**: It is the whole point of the item; today no key opens the in-place editor
and keyboard users always get the modal Rename dialog.

**Independent Test**: In a disk panel, focus a file, press Shift+F6, type a name, press Enter;
the file is renamed on disk and focused. Repeat with Esc: nothing renamed.

**Acceptance Scenarios**:

1. **Given** a disk panel with the file `a.txt` focused, **When** the user presses Shift+F6,
   **Then** an edit field opens over the name with `a.txt` and the part `a` (the name without the
   extension) selected (all of it when *Quick Rename selects all* is configured).
2. **Given** the field is open with a changed name, **When** the user presses Enter, **Then** the
   item is renamed, the field closes and the renamed item is focused.
3. **Given** the field is open with a changed name, **When** the user presses Esc, **Then** the
   field closes and nothing is renamed.
4. **Given** a folder is focused, **When** the user presses Shift+F6, **Then** the field opens with
   the whole folder name selected.
5. **Given** an item whose name has non-ASCII characters is focused, **When** the user presses
   Shift+F6 and confirms another non-ASCII name, **Then** the field shows the exact name and the
   item gets exactly the typed name.

---

### User Story 2 - Nothing happens where in-place rename is not possible (Priority: P2)

On `..`, in an archive, or in a plug-in file system without in-place rename support, Shift+F6 does
nothing (no field, no dialog, no message).

**Why this priority**: The key must not do something unexpected where rename is not available.

**Independent Test**: Focus `..` and press Shift+F6; open an archive and press Shift+F6 on an item;
no edit field appears.

**Acceptance Scenarios**:

1. **Given** `..` is focused, **When** Shift+F6, **Then** nothing happens.
2. **Given** the panel shows the inside of an archive, **When** Shift+F6, **Then** nothing happens.

---

### User Story 3 - Existing keys and commands keep working; the shortcut is discoverable (Priority: P2)

F2 still opens the Rename dialog; Shift+Ctrl+F6 still restores the selection; F6, Ctrl+F6 and
Alt+F6 keep their commands. The Files menu offers the new command with its shortcut, and the
keyboard help lists Shift+F6.

**Why this priority**: The change must not take anything away from current users.

**Independent Test**: F2 opens the dialog; the Files menu shows *Rename in Place* with Shift+F6;
the keyboard help page lists Shift+F6.

**Acceptance Scenarios**:

1. **Given** a focused file, **When** F2, **Then** the Rename dialog opens as before.
2. **Given** a focused file, **When** the user chooses Files > *Rename in Place*, **Then** the
   in-place field opens as with Shift+F6.
3. **Given** a plug-in menu command the user had bound to Shift+F6 before this feature, **When**
   the user presses Shift+F6, **Then** that command still runs (the user's binding is kept).

---

### Edge Cases

- The focused item is scrolled partly out of view: it is brought into view before the field opens.
- The field is already open: Shift+F6 does not open a second one.
- A plug-in file system supporting in-place rename may show its own rename dialog first (its
  existing first-stage behaviour); this is the same as a click-started in-place rename.
- Quick search typing is active: Shift+F6 behaves as the click-started rename in that state.
- Focus in the command line: Shift+F6 does nothing there (unchanged); the menu command works.
- The *Click to Quick Rename* option is off: Shift+F6 still works (that option governs clicks).
- A name typed into the field that is too long is refused, as the click-started rename does today.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Shift+F6 in a panel (no Ctrl, no Alt) MUST open the existing in-place rename field
  over the focused item's name when the item is a file or folder other than `..` and the panel is
  a disk panel or a plug-in file system that supports in-place rename.
- **FR-002**: The field MUST select the same text as a click-started in-place rename (the name
  without its extension for a file, the whole name for a folder, everything when configured so).
- **FR-003**: Enter MUST rename the item and keep it focused; Esc MUST cancel without renaming;
  all existing checks of the in-place rename (too-long name refused, same-file decisions, plug-in
  file system stages) apply unchanged.
- **FR-004**: Where in-place rename is not available (`..`, archive, file system without support,
  empty panel) Shift+F6 MUST do nothing.
- **FR-005**: F2 (Rename dialog), F6, Ctrl+F6, Alt+F6 and Shift+Ctrl+F6 MUST keep their current
  commands.
- **FR-006**: The Files menu MUST offer the command *Rename in Place* showing the shortcut
  Shift+F6, right after *Quick Rename...*, enabled exactly when the in-place rename is available
  for the focused item.
- **FR-007**: The keyboard shortcuts help page and the rename help page MUST list Shift+F6.
- **FR-008**: A plug-in hot key a user already bound to Shift+F6 MUST keep working (it takes
  precedence); new plug-in bindings of Shift+F6 MUST be refused as other program keys are.
- **FR-009**: The new menu text MUST be translated for every enabled language.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In a disk panel, a keyboard user renames a focused item in place with Shift+F6, the
  new name and Enter — no dialog and no mouse — in 100% of probe runs for a file, a folder and a
  non-ASCII name.
- **SC-002**: On `..` and inside an archive, Shift+F6 opens nothing in 100% of probe runs.
- **SC-003**: F2 opens the Rename dialog as before; the Files menu and the keyboard help both name
  Shift+F6.

## Assumptions

- Assumption (autonomous run): Shift+F6 is handled by the panel itself, after plug-in hot keys,
  rather than as a main-window accelerator, so a user's existing plug-in binding of Shift+F6 keeps
  running (conservative: keeps existing behaviour for every case the item does not name).
- Assumption (autonomous run): Shift+F6 while the command line has focus does nothing (as today);
  the item names panels only.
- Assumption (autonomous run): The new menu command has no `&` access key — every candidate letter
  is taken in the Files menu (precedent: *Edit With*).
- Assumption (autonomous run): The plug-in file system path is the same code as the click-started
  rename; it cannot be driven on the hidden desktop without a server and is owed to a person.
