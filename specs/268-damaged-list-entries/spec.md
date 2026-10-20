# Feature Specification: A damaged viewer, editor or User Menu entry no longer erases the entries after it

**Feature Branch**: `268-damaged-list-entries`  
**Created**: 2026-10-20  
**Status**: Draft  
**Input**: User description: "Backlog item a-damaged-viewer-editor-or-user-menu-entry-erases-the - implement exactly what it describes." From backlog item a-damaged-viewer-editor-or-user-menu-entry-erases-the.

## Clarifications

### Session 2026-10-20

- Q: Should the existing "Error Loading Configuration" message for a value of the wrong type be silenced now that the entry is skipped? → A: No - it stays as it is, once per damaged value read; only the loss of the later entries goes (autonomous run: conservative)
- Q: Should a skipped damaged entry be written back when the configuration is saved on exit? → A: No - it is skipped, as the item's Expected says and as feature 250 does for highlighting; the save code is not changed (autonomous run: item)
- Q: Should the loader repair a User Menu submenu left unbalanced by a skipped begin or end entry? → A: No - the consumers already tolerate an unbalanced list; all items are kept and the user can fix the structure in the dialog (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged entry costs only itself (Priority: P1)

A user whose configuration holds a damaged entry in the list of viewers, alternative viewers, editors
or the User Menu (Options > Configuration > Viewers / Editors / User Menu) - made by a hand edit of
the registry or an imported `.reg` file: a required value is missing or has the wrong type - starts
Tandem Commander and later closes it. Today the program reads the list only up to the damaged entry,
so the entries after it are not offered, and the configuration saved on exit drops them for good -
without a word. After the change the damaged entry is left out, every entry after it is loaded and
works, and the save on exit keeps all of them.

**Why this priority**: it is the whole item; the later entries are the user's configuration and are
lost silently.

**Independent Test**: write one of the four lists with a damaged entry into the configuration, start
the program on the hidden desktop, close it and read back the list it saved.

**Acceptance Scenarios**:

1. **Given** a viewers list of three entries whose middle entry has no viewer type, **When** the
   program starts and is closed, **Then** no message box is shown and the saved viewers list holds the
   first and the third entry in their order.
2. **Given** a viewers list whose middle entry has masks containing `|` (which the configuration dialog
   refuses), **When** the program starts and is closed, **Then** the first and the third entry are
   saved.
3. **Given** a viewers list whose first entry has no masks, **When** the program starts and is closed,
   **Then** the second and the third entry are saved (today the list is saved empty).
4. **Given** an alternative viewers list with a damaged middle entry, **When** the program starts and
   is closed, **Then** the first and the third entry are saved.
5. **Given** an editors list whose middle entry has no masks, or masks of the wrong type, **When** the
   program starts and is closed, **Then** the first and the third entry are saved; the wrong type shows
   the existing "Error Loading Configuration" message once.
6. **Given** a User Menu whose middle entry has no item name, or a required value of the wrong type,
   **When** the program starts and is closed, **Then** the first and the third item are saved; the
   wrong type shows the existing message once.
7. **Given** intact lists, **When** the program starts and is closed, **Then** nothing changes: no
   message, the same entries saved in the same order.

### Edge Cases

- Several damaged entries in a row: each is skipped; the list continues with the next number.
- A damaged first entry: the list continues with entry 2 (today the whole list is lost).
- The numbering has a gap (entries 1, 2, 4): the list ends at the gap, as today - only entries that
  exist in sequence are read.
- An entry whose item cannot be created or added for lack of memory: the list ends there, as today
  (the loader stops), but the entry's key is closed.
- A damaged User Menu entry that begins or ends a submenu: it is left out like any other damaged
  entry; the remaining items may then describe an unbalanced submenu, which the menu, the toolbar and
  the configuration page already tolerate (a list cut at a damaged entry was unbalanced the same way).
  The structure is not repaired; all items are kept and saved, and the user can fix it in the dialog.
- Configurations of old versions (lower-case conversion of masks, version-1 User Menu conversion) are
  read exactly as before for every readable entry.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Reading the viewers, alternative viewers, editors and User Menu lists at start-up MUST
  move to the next entry after a damaged entry instead of ending the list.
- **FR-002**: An entry is damaged when a value the loader requires cannot be read (missing, wrong
  type, too long) or, for viewers, its masks contain `|`; such an entry MUST be left out of the list.
- **FR-003**: Every entry key opened while reading these lists MUST be closed, also on the paths that
  end the list for lack of memory (no key handle left open).
- **FR-004**: The existing message for a value of the wrong type or a read error MUST stay as it is,
  shown once per damaged value read; no new message or text is added.
- **FR-005**: An intact list MUST load exactly as before: the same entries, the same order, the same
  values.
- **FR-006**: The lists saved on exit MUST hold the loaded entries, numbered from 1 without gaps, as
  the existing saves do; the save code is not changed.

### Key Entities

- **List entry**: one numbered key of the viewers, alternative viewers, editors or User Menu list.
  Viewers need readable masks (without `|`) and a type; editors need readable masks; a User Menu item
  needs a readable item name, command, "execute through shell" and "close shell window" value. The
  other values have defaults.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In each of the nine damaged rows of the probe, the list saved on exit equals the good
  entries in their order (before the change: 0 of 9).
- **SC-002**: No row reports a registry key left open at exit (before: 9 of 9 damaged rows did).
- **SC-003**: At most one message box per damaged entry of the wrong type, none for a missing value
  (unchanged from before).
- **SC-004**: The three control rows with intact lists behave exactly as before (start, no box, same
  list saved).

## Assumptions

- Assumption (autonomous run): the damaged entry is **skipped** and not written back on exit - the
  item's *Expected* names it, and feature 250 did the same for the highlighting list (item).
- Assumption (autonomous run): the low-memory paths keep ending the list (`break`), as the item's
  *Notes* allow, but close the entry key first (item).
- Assumption (autonomous run): no change to the registry layout, the save code, the configuration
  dialogs or any other loader; the settings import has its own item (conservative).
- The fix is in the start-up configuration loaders only; it needs no new UI string and no translation.
