# Feature Specification: Drive list and folder type names come from Windows as Unicode

**Feature Branch**: `289-drive-list-wide-texts`
**Created**: 2026-10-21
**Status**: Draft
**Input**: From backlog item drive-list-code-page-texts. User description: "Backlog item drive-list-code-page-texts (backlog/items/drive-list-code-page-texts/desc.md) - implement exactly what it describes." (full input: title, problem, evidence, expected, measurement at cf860604 - see *Background* below)

## Background

Tandem Commander keeps names and texts in UTF-8 inside the program and draws them as Unicode.
A few texts that Windows gives to the program are still asked for in the **ANSI code page** of the
system (the "language for non-Unicode programs"):

- the **type name of folders** (the *Type* column of every folder, e.g. "File folder"), asked of
  the Windows shell once at start;
- the **name of a removable drive** (USB stick, card reader) as Windows shows it, in the
  *Change Drive* menu (Alt+F1 / Alt+F2) and in the drive bar tooltip;
- the **label of a CD / DVD drive**, read in a helper thread for the same menu and tooltip;
- the program's own **localized texts** of the drive list - "Local Disk", "Compact Disc",
  "Removable Disk", the floppy texts, "Documents", "Network", "OneDrive", "Google Drive",
  "Dropbox", the free-space text - and the type name of the "up" entry `..`
  ("Upper Directory"), loaded in the code page.

Where the code page cannot express a character, Windows gives `?` before the program ever sees
the text: a CD labelled in Cyrillic or Greek on a Czech or English system shows as `????`, and a
Windows display language outside the code page (for example an English "non-Unicode" setting
with a Czech or Japanese display language) gives a folder type name of question marks. The
other texts are in the code page while the panel, the menu and the tooltip read them as UTF-8
first (and fall back to the code page only when the bytes are not valid UTF-8) - so they mix two
encodings in one drive menu, and one menu item can join a UTF-8 label with a code-page word.

**Measured at cf860604** (ACP 1250, Czech display language; a PowerShell P/Invoke harness):

- the shell's code-page call gives bytes `3F 3F 3F` ("???") for the display name of a folder
  named "Дом"; the Unicode call gives the exact name;
- the folder type name of the system directory comes as code-page bytes
  `53 6C 6F 9E ... F9` ("Složka souborů"), not UTF-8 - right on this machine only thanks to the
  sinks' code-page fallback;
- this machine has no removable or CD drive and every enabled translation of the affected
  strings fits code page 1250, so the end-to-end symptom (a `????` CD / removable label, a `?`
  folder type name) cannot be shown here: confirming it on such a machine is owed to a person.

## Clarifications

### Session 2026-10-21

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A CD or removable drive named in another script shows its real name (Priority: P1)

A user inserts a USB stick or a CD whose label is in a script outside the system code page (for
example Cyrillic or Greek on a Czech system). The *Change Drive* menu and the drive bar tooltip
show the label as Windows shows it, not as question marks.

**Why this priority**: it is the visible, reported symptom - the user cannot tell which drive is
which.

**Independent Test**: on a machine with such a drive, open Alt+F1 and hover the drive bar
button; the label reads exactly as in Explorer. Without such a drive: the program's routines that
obtain a removable drive's display name and a CD label take the Unicode answer of Windows and
convert it to UTF-8 (a code review plus a debug seam that dumps the drive texts).

**Acceptance Scenarios**:

1. **Given** a CD labelled "Диск" in a system with code page 1250, **When** the user opens the
   *Change Drive* menu, **Then** the CD's item shows "Диск", not "????".
2. **Given** a removable drive whose Windows display name has characters outside the code page,
   **When** the user hovers its drive bar button, **Then** the tooltip shows the same name.
3. **Given** a CD drive with no medium or no label, **When** the menu is built, **Then** the item
   shows the localized "Compact Disc" as before.

---

### User Story 2 - Folder type names and "Upper Directory" are right in every language setting (Priority: P2)

A user whose Windows display language is outside the system code page, or who runs the program in
a language whose texts are outside it, sees the folder type name and the `..` type name in the
*Type* column correctly.

**Why this priority**: affects every folder in the panel, but only in mixed language settings.

**Independent Test**: the stored folder type name and up-directory type name are valid UTF-8
equal to the Unicode text Windows / the language module holds; on this machine their bytes change
from code page to UTF-8 while the panel shows the same text as before.

**Acceptance Scenarios**:

1. **Given** a Czech display language and code page 1250, **When** the panel shows a folder with
   the *Type* column, **Then** the type reads "Složka souborů" exactly as before the change.
2. **Given** a display language outside the code page, **When** the panel shows folders, **Then**
   the type name is the display language's text, not question marks.

---

### User Story 3 - The drive menu's texts are one encoding (Priority: P3)

Every text the drive list composes - localized words, labels, free space, OneDrive account names -
is UTF-8, so no menu item or tooltip joins two encodings.

**Why this priority**: consistency; today it is right only by the sinks' fallback, and wrong
where a UTF-8 part and a code-page part meet in one string.

**Independent Test**: the debug seam that dumps the drive menu's texts shows valid UTF-8 for
every item; the menu and tooltips on this machine look exactly as before.

**Acceptance Scenarios**:

1. **Given** a fixed drive without a label, **When** the menu is built, **Then** the item reads the
   localized "Local Disk" followed by the free space, all valid UTF-8, displayed as before.
2. **Given** a OneDrive for Business account, **When** the user picks its item, **Then** the
   program opens the same account as before (the account name is taken from the item text with
   the same encoding it was composed with).

---

### Edge Cases

- A label or display name whose UTF-8 form is longer than the code-page form: the stored text
  must never be cut in the middle of a character; the buffers hold the longest text Windows can
  return for that field, or the text is cut at a whole character.
- Windows fails the Unicode call (no medium, a slow CD): the existing fallback texts ("Compact
  Disc", "Removable Disk") are used, exactly as when the code-page call failed.
- The CD thread times out (500 ms): unchanged - the item shows "Compact Disc".
- A label containing `&`: still doubled for the menu, as today.
- Texts that are pure ASCII: the bytes are identical before and after.
- The plug-in items of the menu (file-system names, commands) are UTF-8 already by contract and
  are not touched.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The type name of folders MUST be obtained from Windows as Unicode and stored as
  UTF-8, without cutting it.
- **FR-002**: The type name of the `..` entry MUST be loaded from the language module as UTF-8.
- **FR-003**: The display name of a removable drive (menu and drive bar tooltip) MUST be obtained
  from Windows as Unicode and stored as UTF-8; the existing trimming of the " (X:)" suffix stays.
- **FR-004**: The label of a CD / DVD drive (menu and drive bar tooltip) MUST be obtained from
  Windows as Unicode and stored as UTF-8; the helper thread, its timeout and its fallback stay.
- **FR-005**: Every localized text the drive list puts into a menu item or a drive bar tooltip
  (local / compact / removable disk, floppy texts, Documents, Network, OneDrive and its
  "Personal", Google Drive, Dropbox, the free-space size) MUST be UTF-8.
- **FR-006**: Code that reads a part back out of a drive menu text (the OneDrive for Business
  account name) MUST measure that text in the same encoding it was composed with.
- **FR-007**: Texts that render correctly today MUST render identically after the change (the
  sinks are UTF-8 first; ASCII texts keep their bytes).
- **FR-008**: No text is cut in the middle of a character; no new user-visible string is added.
- **FR-009**: The texts in scope MUST be observable without a GUI by a debug-only seam (or the
  existing drive dump seam of feature 246), so a probe can check they are valid UTF-8.

### Key Entities

- **Folder type name**: one text for all folders, read once at start.
- **Up-directory type name**: the localized "Upper Directory".
- **Drive item text**: hot key, tab, label / name, optional tab and free space - one string per
  menu item.
- **Drive bar tooltip text**: label / name with free space, built when the user hovers.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On a machine with a CD or removable drive labelled outside the code page, the menu
  and tooltip show the label character for character as Explorer does (person step).
- **SC-002**: On this machine, every drive menu item and drive bar tooltip text dumped by the
  probe is valid UTF-8, and the visible texts are the same as before the change (0 differences in
  the decoded text).
- **SC-003**: The folder type name and the up-directory type name stored by the program are valid
  UTF-8 equal to the Unicode text from Windows / the language module (probe, both the English and
  the Czech language module).
- **SC-004**: No code-page shell or volume call remains among the sites named by the item (code
  check), the encoding guard reports 0 findings, the build and the unit checks pass.

## Assumptions

- Assumption (autonomous run): the item's scope is the drive list (Change Drive menu, drive bar
  and its tooltip) plus the two folder type names; other code-page texts of the program (hot path
  names, plug-in texts, the reconnection chain of remembered network drives - item
  `remembered-network-drive-with-a-non-code-page-or-long-path`) are out of scope.
- Assumption (autonomous run): the end-to-end symptom cannot be produced here (no removable / CD
  drive, display language inside the code page); the change is verified by the bytes the program
  stores and by the unchanged display, and the real-drive check is owed to a person.
- Assumption (autonomous run): no new UI strings, no registry or installer change, no plug-in
  interface change.
