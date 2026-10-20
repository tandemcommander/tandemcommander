# Feature Specification: case twins are addressed exactly (Compare Directories, viewer, User Menu, Ctrl+X)

**Feature Branch**: `261-case-twins-exact-match`
**Created**: 2026-10-20
**Status**: Draft
**Input**: Backlog item case-sensitive-twins-first-match: "Case-sensitive folders: several features take the first case-insensitive twin". From backlog item case-sensitive-twins-first-match.

A case-sensitive folder (WSL, `fsutil file setCaseSensitiveInfo`) can hold two files whose names
differ only in case - "case twins", e.g. `a.txt` and `A.txt`. Features 230-232 taught drag & drop,
Reselect, Restore Selection, Hide Selected Names and the refresh merge to tell twins apart. Four
more places still take the first name that matches ignoring case.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Compare Directories pairs the exact twin (Priority: P1)

A user compares a case-sensitive folder holding `a.txt` and `A.txt` with a folder holding only
`A.txt` (the same content). Today `a.txt` is paired with the other side's `A.txt`, so both left
files are marked different. The user expects `A.txt` to be paired with `A.txt` and only `a.txt`
marked (it has no counterpart).

**Why this priority**: Compare Directories drives copy / delete decisions on the marked files; a
wrong pairing marks identical files and hides real differences.

**Independent Test**: probe rows CMPTWIN1, CMPTWINR, CMPSUB of `probe/twin261_probe.ps1`.

**Acceptance Scenarios**:

1. **Given** left (case-sensitive) `a.txt` "lower!" + `A.txt` "UP" and right `A.txt` "UP" with the
   same time, **When** Compare Directories by size and time runs, **Then** only left `a.txt` is
   marked.
2. **Given** left `A.txt` "UP12" and right (case-sensitive) `a.txt` "x" + `A.txt` "UP12", **When**
   the compare runs, **Then** left `A.txt` is not marked.
3. **Given** sub-folders `Sub` on both sides, left holding `aB.txt` + `Ab.txt`, right `ab.txt` +
   `AB.txt` (twins on both sides, sizes equal by position), **When** the compare runs with
   "Include subdirectories", **Then** the sub-folders are reported different (other names).
4. **Given** case-sensitive folders holding `Readme.txt` (left) and `README.txt` (right) and no
   twins, **When** the compare runs, **Then** they are paired as one name (feature 232 kept).

---

### User Story 2 - The viewer's next / previous file keeps its place (Priority: P2)

A user views `A.txt` of a case-sensitive folder `a.txt`, `A.txt`, `z.txt`; another program adds
`0.txt` and the panel refreshes. Next file must show `z.txt` (today `A.txt` again), previous file
`a.txt` (today `0.txt`).

**Why this priority**: wrong navigation, no data at risk.

**Independent Test**: probe rows VIEWNEXT, VIEWPREV.

**Acceptance Scenarios**:

1. **Given** the viewer on `A.txt` and the list shifted by one, **When** next file, **Then** `z.txt`.
2. **Given** the same, **When** previous file, **Then** `a.txt`.

---

### User Story 3 - User Menu compare names and Ctrl+X greying take the exact twin (Priority: P3)

The User Menu's second compare name (the item of the same name in the other panel) and the ghosted
"cut" mark in the other panel showing the same folder take the twin with exactly the same name.

**Why this priority**: by reading only (a configured User Menu item / the real clipboard are needed
to drive them); the decision is the same rule as Story 2 and is checked by `saltests`.

**Independent Test**: `saltests` checks of the shared lookup rule; a person step for the GUI.

**Acceptance Scenarios**:

1. **Given** the active panel's focused `A.txt` and the other panel (case-sensitive) holding
   `a.txt` and `A.txt`, **When** a User Menu item uses the compare names, **Then** the second name
   is the other panel's `A.txt`.
2. **Given** both panels on one case-sensitive folder with `a.txt` and `A.txt`, **When** `A.txt` is
   cut (Ctrl+X), **Then** `A.txt` - not `a.txt` - is ghosted in the other panel.

### Edge Cases

- No twins anywhere: every feature behaves exactly as before (a name differing only in case from
  the only candidate is still found / paired).
- Twins on one side only: a name differing only in case from a twin is not paired with it (which
  twin is meant cannot be told); every byte-identical name is.
- Canonically equivalent names (NFC vs NFD) stay two names (feature 004, FR-009).
- Folders that are not case-sensitive cannot hold twins: no change there.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Compare Directories pairs two names that are equal ignoring case only when they are
  byte-identical, whenever either name has a case twin in its own folder; without twins on either
  side a case-only pair stays one name (feature 232).
- **FR-002**: The same rule decides whether two sub-folders compared with "Include subdirectories"
  hold the same names.
- **FR-003**: The viewer's next / previous / first / last file finds the remembered file by its
  exact name; a name equal only ignoring case is taken only when it is the only such name.
- **FR-004**: The User Menu's second compare name from the other panel follows FR-003's rule.
- **FR-005**: Ctrl+X ghosts in the other panel (same folder) the item FR-003's rule picks.
- **FR-006**: The lookup rule of FR-003-FR-005 is one pure, unit-tested decision.
- **FR-007**: Remembered folder sizes are not changed: the code is unreachable (its Store / Restore
  calls are commented out).

### Key Entities

- **Case twins**: two byte-different names of one folder that are the same name ignoring case.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `twin261_probe.ps1`: 5 FAIL of 14 rows before -> 0 FAIL after; the controls
  CMPTWIN2 and CMPSINGLE pass before and after.
- **SC-002**: Feature 232's probe `cmp232_probe.ps1` still passes 16 / 0.
- **SC-003**: `saltests` 0 failed, including the new checks of the lookup and pairing rules.

## Assumptions

- Assumption (autonomous run): the item's hint "compare with `CmpNameExt` when both panels are
  case-sensitive" is generalised to "byte-exact when a twin exists on either side" - it also fixes a
  case-sensitive folder compared with an ordinary one (CMPTWINR) and keeps feature 232's pairing
  of a case-only pair without twins (the conservative choice: no change where the item names none).
- Assumption (autonomous run): a lookup by name keeps its case-insensitive fallback when exactly one
  candidate matches (existing behaviour, as feature 230's rule).
- Assumption (autonomous run): the Turkish / Azeri locale comparison is upstream behaviour that
  would change the panel's sort order; it is filed as its own Inbox item, not changed here.
- A timed listing on an SMB share is a person step (`real-file-server-person-rows`), not part of
  this feature.
