# Feature Specification: Opening a folder found by quick search goes straight to the new folder

**Feature Branch**: `376-qs-enter-no-flash`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item opening-a-folder-found-by-quick-search-briefly-shows-the - implement exactly what it describes." From backlog item opening-a-folder-found-by-quick-search-briefly-shows-the.

## Background

While quick search filters a panel (feature 244, on by default) the panel shows only the items
whose names contain the typed text, on a tinted background. When the user opens a matching
folder (Enter, or a double click), the search has to end first: the panel's whole listing must
be back before the path changes, so that the remembered position for a later return and the
Back history describe the whole folder (CLAUDE.md standing rule, 244).

Measured at `d4fb03e7` (Debug x64, hidden-desktop probe `qs376_probe.ps1`; a folder with five
subfolders, one of them, `big`, holding 30,000 files; Detailed view; type `big`, press Enter;
the panel's pixels are sampled every ~6 ms for 4 s and each sample classified):

| Round | Filtered view | Whole parent folder (the flash) | New folder |
|---|---|---|---|
| 1 | 1 sample | 39 samples, 7-303 ms after Enter | from 307 ms |
| 2 | 1 sample | 38 samples, 21-301 ms | from 308 ms |
| 3 | 1 sample | 38 samples, 6-295 ms | from 309 ms |

The defect is not intermittent: ending the search **draws** the whole parent folder (not only
marks it for drawing) every time, before the new folder is read. A person notices it only when
reading the new folder takes longer than about one screen refresh - a large or slow folder - which
is why it looked intermittent.

## Clarifications

### Session 2026-11-01

- Q: Which ways of opening a folder are in scope? → A: Every way that opens a folder from the filtered view through the panel's "open the item" action (Enter, double click, Ctrl+PageDown on a folder) - they share one code path; other path changes made while a search runs (Backspace is a search key there; Alt+Left, the drive menu, Change Directory, a hot path) are outside the item and stay as they are (autonomous run: item - it names Enter on a folder in a filtered panel).
- Q: What does the panel show if opening the folder fails and the panel stays in the parent folder (access denied, the folder vanished)? → A: The whole parent folder, as today, drawn once after the failure (autonomous run: conservative - same end state as today).
- Q: Should the column header and the scroll bars also keep the filtered state until the new folder is drawn? → A: Yes - nothing of the panel (items, column header, scroll bars) is redrawn for the parent's whole listing; the opened folder's drawing replaces all of it (autonomous run: recommended).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Opening a found folder shows no intermediate parent listing (Priority: P1)

A user types into a panel to quick search, focuses a matching folder and presses Enter. The panel
changes from the filtered view directly to the opened folder's listing. The unfiltered parent
folder is never drawn in between, however long the new folder takes to read.

**Why this priority**: it is the reported defect.

**Independent Test**: the probe rows FLASH: no sample shows the whole parent folder between Enter
and the new listing.

**Acceptance Scenarios**:

1. **Given** a filtered panel with the cursor on a matching folder that takes ~300 ms to read,
   **When** the user presses Enter, **Then** every sample until the new listing appears shows the
   filtered view (or a picture in the middle of drawing the new listing), none the whole parent
   folder.
2. **Given** the same, **When** the new folder's listing appears, **Then** the search has ended:
   the new folder shows all its items, untinted, without the search text.

---

### User Story 2 - Everything around the opening stays as it was (Priority: P2)

After opening the folder, going back up (Backspace / `..`) returns to the parent folder with the
cursor on the folder that was opened and the parent's position as remembered for the whole
listing; Back history works as before; the 244 behaviour of the search is unchanged.

**Why this priority**: the fix touches the order of ending the search and drawing; it must not
change where the user lands.

**Independent Test**: probe rows LOC and BACK; the feature 244 probe (45 rows, `-Expect new`)
and saltests.

**Acceptance Scenarios**:

1. **Given** the user opened `big` from the filtered view, **When** they press Backspace, **Then**
   the panel is in the parent folder with the cursor on `big`.
2. **Given** the feature 244 probe, **When** it runs on the new build, **Then** every row passes
   as before (C16: Enter into a matching directory shows the complete directory).

---

### Edge Cases

- Opening the folder fails and the panel stays in the parent folder (access denied, the folder
  was deleted meanwhile, an over-long name): the whole parent folder is drawn, correctly laid out,
  as today (one drawing after the failure instead of one before).
- Opening the folder leads somewhere else (a junction whose target is shown instead, a failure
  that shortens the path): the panel shows where it ended, as today.
- The filtered view is in an archive or a plug-in file system: the same order applies (the code
  path is shared).
- Something draws the panel while the new folder is read (a window over it is moved away, a
  message box): the panel draws the whole parent listing consistently (it must never draw stale
  or out-of-range items).
- Opening a file (not a folder) from the filtered view is unchanged: the search keeps running.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Opening a folder from a filtered panel MUST NOT draw the unfiltered parent listing
  before the opened folder's listing is drawn, when opening succeeds - neither the items nor the
  column header nor the scroll bars.
- **FR-002**: The whole listing MUST still be back in the panel before the path changes, and the
  remembered position (top item and cursor) for a return MUST be that of the whole listing with
  the opened folder under the cursor, as today.
- **FR-003**: If the panel does not leave the parent folder (failure) or nothing else drew it,
  the panel MUST be drawn with the whole listing once the opening has finished, so that it never
  keeps showing the filtered picture with the search ended.
- **FR-004**: The search MUST have ended when the opened folder is shown: no tint, no search text
  in the directory line or the information line.
- **FR-005**: Every other end of a quick search (Esc, empty text, a refresh, a tab switch, the
  other panel, a path change from elsewhere, closing) MUST behave exactly as before.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe (3 rounds, folder read ~300 ms), samples showing the whole parent
  folder after Enter drop from 38-39 per round to 0.
- **SC-002**: The probe rows LOC and BACK pass in every round; the feature 244 probe passes all
  its rows; saltests report 0 failed.
- **SC-003**: The opened folder appears no later than before (the time from Enter to the new
  listing does not grow by more than one screen refresh).

## Assumptions

- Assumption (autonomous run): the measurement shows the parent listing is drawn synchronously
  by the layout routine, not by a stray paint message; the fix therefore lays the whole listing
  out without drawing it and draws only what the opening produces (or the parent once after a
  failure).
- Assumption (autonomous run): other ways of changing the path while a search runs (outside the
  "open the item" action) may show the same effect; they are outside this item and are recorded
  as a separate Inbox item if measured.
- No UI text, dialog, setting, registry value, plug-in interface or translation changes.
