# Feature Specification: The Renamer builds a new name of any length the file system accepts

**Feature Branch**: `282-renamer-long-new-name`
**Created**: 2026-10-21
**Status**: Draft
**Input**: User description: "Backlog item renamer-long-new-name-limits - implement exactly what it describes." From backlog item renamer-long-new-name-limits.

## Background

The Renamer (Batch Rename, Ctrl+Shift+R) builds each item's new name - the folder part the mode
keeps plus the expanded New name pattern (with Search / Replace and the case changes applied), or
the line typed in manual mode - into a buffer of 260 bytes of UTF-8. A name of 90 CJK letters is
270 bytes (an ordinary 90-letter Windows name), so such an item cannot be renamed to another long
name: the rename is refused "Expanded string is too large." and the preview shows that error in
place of the new name. Only Undo restores the long name (feature 207 fixed Undo's own copy).

"Include subdirectories" reads a selected folder's contents into a 260-byte folder buffer and
refuses any found item whose full name reaches 260 bytes ("Unable to read directory because of too
long path name"), while the same item selected in the panel is accepted - two limits for the same
file.

Measured at c02b0f78 with `probe/ren_longnew_probe.ps1` (result_before.txt): 11 PASS / 7 FAIL -
long-new, long-undo, manual-long, long-rel, long-rel-deep refused "Expanded string is too large.";
sub-long-file and sub-long-dir refused on loading "too long path name". The controls (one
component of 300 characters - refused; a short rename and Undo) pass.

## Clarifications

### Session 2026-10-21

- Q: Is the New name pattern field's own limit (520 bytes of the typed pattern, refused by the
  field) raised as well? → A: no - the item is about the name built from the pattern; the field
  refuses (never cuts) and a long name is reached through the pattern's variables; recorded as an
  Inbox item. (autonomous run: conservative)
- Q: What does the preview's path column show for an item whose folder is longer than its old
  260-byte buffer? → A: the folder whole (no piece cut inside a character). (autonomous run: rule -
  "a path or name is never cut")
- Q: Where is the upper limit of a built new name? → A: the UTF-8 form of the longest path the file
  system accepts (3 x 32,767 + 1 bytes); beyond it the existing "Expanded string is too large."
  refusal. (autonomous run: item - "any length the file system accepts")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A long item renamed to another long name (Priority: P1)

The user selects a file whose name is long in UTF-8 (for example 90 CJK letters) and gives a new
name that is also long: a pattern adding a suffix, a literal name, a manual-mode line, or a
relative path with new folders.

**Why this priority**: it is the item's main defect - a valid rename the file system accepts is
refused, and the preview marks the item as an error.

**Independent Test**: on a fixture, rename "L.txt" (L = 90 CJK letters) to "Lb.txt" in file-name
mode, "x.txt" to "Lc.txt" in manual mode, and "x.txt" to "M\MM.txt" (M = 45 CJK letters) and to
a 300+-unit relative path in relative-path mode; each is renamed with no box, Undo restores.

**Acceptance Scenarios**:

1. **Given** a file "L.txt", **When** it is renamed to "Lb.txt", **Then** it has the new name, no
   error is shown, and the preview showed the new name (not an error).
2. **Given** that rename done, **When** the user runs Undo, **Then** the file is back under "L.txt".
3. **Given** manual mode with a line "Lc.txt" for "x.txt", **When** the rename runs, **Then** the
   file is "Lc.txt".
4. **Given** relative-path mode and a new name "M\MM.txt" or "<100 a>\<100 b>\<100 c>.txt",
   **When** the rename runs, **Then** the folders are created and the file is renamed into them.

---

### User Story 2 - Items found through "Include subdirectories" follow the same limit (Priority: P1)

The user selects a folder and ticks "Include subdirectories"; the folder holds an item whose full
name has 260+ bytes of UTF-8, or the folder's own name is that long.

**Why this priority**: the item names this inconsistency explicitly; the user cannot rename such
files at all through the recursive listing.

**Independent Test**: a folder "sub" holding "L.txt", and a folder "L" holding "x.txt"; with the
box ticked both files are listed (no refusal) and renamed to "a.txt" / "y.txt".

**Acceptance Scenarios**:

1. **Given** a folder "sub" holding "L.txt", **When** "Include subdirectories" is ticked, **Then**
   no box is shown, the preview lists the file, and the rename to "a.txt" gives "sub\a.txt".
2. **Given** a folder "L" holding "x.txt", **When** the box is ticked and the rename to "y.txt"
   runs, **Then** the result is "L\y.txt".

---

### User Story 3 - A name the file system does not accept is still refused, never cut (Priority: P2)

**Why this priority**: the guard against regressions - the larger limit must not turn a refusal
into a cut name or a silent wrong rename.

**Independent Test**: "x.txt" renamed to a single component of 300 characters is refused with an
error; the file keeps its name and nothing else is created.

**Acceptance Scenarios**:

1. **Given** a new name whose component exceeds the file system's limit, **When** the rename runs,
   **Then** an error is shown and nothing changes on disk.
2. **Given** an expanded name longer than the longest path the file system accepts, **When** the
   rename runs, **Then** it is refused as too large (the existing error), never cut.

### Edge Cases

- A short rename and its Undo behave exactly as before (control).
- A folder item renamed with "Include subdirectories" ticked afterwards (209's reload) still lists
  the renamed folder's own contents.
- The preview's path column for an item in a long folder shows the folder whole (never a piece cut
  inside a character).
- A name that is not valid UTF-8 (WTF-8 with a lone surrogate) is carried through unchanged as
  before.
- Out of memory while building a name: the item is refused with the existing error, nothing is
  renamed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Renamer MUST build each new name (folder part + expanded pattern, Search /
  Replace, case changes; or a manual-mode line) in storage large enough for the longest path the
  file system accepts (32,767 UTF-16 units in UTF-8), allocated from the heap, never in a 260-byte
  buffer.
- **FR-002**: A new name that does not fit that storage MUST be refused with the existing "Expanded
  string is too large." error - never cut.
- **FR-003**: The preview MUST show such a new name (and judge its validity) the same way the
  rename builds it - the long name, not the error.
- **FR-004**: "Include subdirectories" MUST read folders and accept found items up to the same
  length as a selected item; a folder or item longer than the longest path is refused with the
  existing "too long path name" error, never cut.
- **FR-005**: The stored full-name length of an item MUST hold the UTF-8 length of the longest
  path (no wrap-around of a narrow length field).
- **FR-006**: The preview's path column MUST show an item's folder whole, at any length.
- **FR-007**: Every other behaviour (short names, Undo, "Remove source path", the 8.3 clash
  handling of 199 / 206, 209's reload, the existing errors) MUST stay as it is.

### Key Entities

- **New name**: the full target path built per item; UTF-8 (WTF-8), any length up to the longest
  path the file system accepts.
- **Source item**: a selected or recursively found file or folder; full name, name, extension,
  stored length.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe `ren_longnew_probe.ps1` goes from 11 PASS / 7 FAIL to 18 PASS / 0 FAIL
  (9 rows, each RUN + END).
- **SC-002**: The over-length control is still refused with nothing changed on disk.
- **SC-003**: The earlier Renamer probes (199, 206, 207, 209) still pass.

## Assumptions

- Assumption (autonomous run): "any length the file system accepts" means up to the Windows long
  path limit of 32,767 UTF-16 units, i.e. at most 3 x 32,767 + 1 bytes of UTF-8 (the plug-in
  constant `SAL_MAX_PATH_UTF8`); the file system itself refuses a component over 255 units.
- Assumption (autonomous run): the panel folder (`Root`, refused before the dialog by 207) and the
  New name / Search / Replace pattern fields (520 / 520 / 260 bytes, a refusal of the field) are
  separate limits, not part of this item; the pattern field limit is recorded as an Inbox item.
- Assumption (autonomous run): no new UI strings - the existing errors are reused.
