# Feature Specification: A cpio hard link whose data name normalizes to empty gets its data

**Feature Branch**: `394-cpio-empty-name-link`  
**Created**: 2026-11-02  
**Status**: Draft  
**Input**: Backlog item `a-cpio-hard-link-whose-data-name-normalizes-to-empty-is` - "A cpio hard link whose data name normalizes to empty is written as an empty file". From backlog item a-cpio-hard-link-whose-data-name-normalizes-to-empty-is.

## Background (measured at 32c55a19)

Debug x64 build of `main`; hidden-desktop probe `cpioempty_probe.ps1` (fixtures by
`mkcpioempty.py`, now in `probe/`): PASS 11 / FAIL 9. A newc / crc cpio (or an rpm) stores one file
with two names - `a.txt` with size 0 and a second name carrying the data `AAA` - as one inode with
link count 2. When that second name normalizes to nothing (`.`, `./` or an empty name), a whole
Unpack (Alt+F9) with "Delete archive after unpacking" writes `a.txt` as an EMPTY file, shows
nothing and DELETES the archive - the only copy of the data. The same with the data stored first
(data-first layout), with a crc archive whose carrier has a wrong checksum, and for Copy of the
listed names from the opened archive. Control: GNU cpio's folder member `.` plus `ok.txt` extracts
`ok.txt` and deletes the archive - correct, must stay so.

Feature 310 groups the names of one hard-linked file; feature 393 kept a refused (too long) name
in its group as "not asked" so the group's other names get its data. A name that normalizes to
nothing was left out of the group entirely, so its data never reached the other names.

## Clarifications

### Session 2026-11-02

- Q: Get the data to the other names, or report and fail? → A: get the data - the item's first choice, done the way feature 393 does for a refused name (the empty-name member stays in its group as not asked; it is never written under its own name) (autonomous run: item - *Expected*)
- Q: Data-first layout (the empty-name carrier comes before the other name)? → A: feature 310's rule for a data member that passed unwritten: the other name is reported ("(2)", `name -> data name`) and the operation fails, so the archive is kept (autonomous run: item - *Expected* "or ... reported and the operation fails"; rule - features 310 / 393 limit)
- Q: Is the empty-name member itself reported when the archive is opened or extracted? → A: no - it was never listed or reported and nothing can be asked for under its name; only its role as the group's data carrier changes (autonomous run: conservative)
- Q: Is the data written from such a carrier (and from feature 393's refused carrier) checked against the crc checksum? → A: yes - data that is written is verified as for any other member; a mismatch is the existing checksum error, the written file is removed and the operation fails (autonomous run: conservative - refuses rather than writes unverified data; the item's "never ... with success")
- Q: Members whose normalized name is empty but which are not part of a hard-link group (a folder `.`, a single-name file `.`, odc / binary formats, tar)? → A: unchanged - they stay without effect, as before (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The other names of the file get its data (Priority: P1)

A user unpacks a cpio archive or an rpm whose hard-linked file stores its data under a name that
normalizes to nothing. The file's other names are written with the data; the archive is deleted
only when everything was extracted.

**Why this priority**: today the user ends up with an empty file and, with "Delete archive after
unpacking", without the archive - data loss.

**Independent Test**: whole Unpack with "Delete archive after unpacking" of the fixture rows
`UNP-EMPTY-DOT-DEL`, `-DOTSLASH-`, `-NUL-`, `UNP-CRC-EMPTY-DOT-DEL`, `UNP-RPM-EMPTY-DOT-DEL`; Copy
row `COPY-EMPTY-DOT`.

**Acceptance Scenarios**:

1. **Given** a newc cpio with `a.txt` (size 0) and `.` (`AAA`) as one file, then `ok.txt`, **When**
   the user unpacks it all with "Delete archive after unpacking", **Then** `a.txt` holds `AAA`,
   `ok.txt` is extracted, nothing is asked and the archive is deleted.
2. **Given** the same with the carrier named `./` or an empty name, or in a crc cpio, or as the
   payload of an rpm, **When** unpacked the same way, **Then** the same result.
3. **Given** the opened archive of scenario 1, **When** the user copies all listed names, **Then**
   `a.txt` holds `AAA`.

---

### User Story 2 - Never an empty file with success (Priority: P1)

When the data cannot reach the other names, they are reported and the operation fails, so the
archive is kept.

**Why this priority**: the item's safety bound - "never an empty file with success".

**Independent Test**: rows `UNP-EMPTY-DOT-FIRST-DEL`, `COPY-EMPTY-DOT-FIRST`,
`UNP-CRC-EMPTY-DOT-BADSUM-DEL`.

**Acceptance Scenarios**:

1. **Given** the data-first layout (`.` with `AAA` first, then `a.txt` size 0), **When** unpacked
   with "Delete archive after unpacking", **Then** a "(2)" message names `a.txt`, `a.txt` is not
   written, `ok.txt` is, and the archive is KEPT.
2. **Given** the same opened archive, **When** the user copies all listed names, **Then** the "(2)"
   message names `a.txt` and `a.txt` is not written.
3. **Given** a crc cpio whose empty-name carrier has a wrong checksum, **When** unpacked with
   "Delete archive after unpacking", **Then** the checksum error is shown, no `a.txt` with wrong or
   empty content stays, and the archive is KEPT.

---

### User Story 3 - Nothing else changes (Priority: P2)

Archives without such a carrier extract as before.

**Independent Test**: control row `UNP-DOTDIR-DEL`; regression probes of features 306, 308, 309,
310, 321 and 393.

**Acceptance Scenarios**:

1. **Given** a cpio with the folder member `.` and `ok.txt`, **When** unpacked with "Delete archive
   after unpacking", **Then** `ok.txt` is extracted, nothing is asked, the archive is deleted.
2. **Given** the archives of the earlier probes, **When** they run, **Then** their results are
   unchanged.

### Edge Cases

- The carrier is the only member of its group that holds data and no other name is asked: nothing is
  written (it is never written under its own name).
- Several waiting names: every one gets a copy of the data (feature 310's path).
- An F3 view / single-name copy of `a.txt` with the data stored later under `.`: `a.txt` gets the
  data (the single-member pass reads on to the group's data member).
- A tar archive member whose name normalizes to nothing: unchanged (tar has no such grouping).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A newc / crc cpio member (also in an rpm payload) whose name normalizes to nothing MUST
  stay a member of its hard-link group, treated as not asked and never written under its own name.
- **FR-002**: When such a member carries the group's data and a name of the group waits for it, that
  name MUST get the data (and every further waiting name a copy), with the data member's time and
  attributes as for any other carrier.
- **FR-003**: When such a member carries the data and passes before any asked name of its group, the
  asked names MUST be reported and the operation MUST fail (archive kept), as feature 310 does.
- **FR-004**: Data written from a carrier that is itself not extracted (an empty or a refused name)
  MUST be verified against the crc checksum like any other data; a mismatch fails the operation and
  removes the written file.
- **FR-005**: Members with an empty normalized name that are not hard-link group members MUST keep
  their behaviour (ignored, no message).
- **FR-006**: No UI text, plug-in interface or stored setting changes.

### Key Entities

- **Hard-link group**: the names of one file in a newc / crc cpio (same device and inode, link count
  above one); one of them carries the data.
- **Empty-name carrier**: a group member whose name normalizes to nothing.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe goes from PASS 11 / FAIL 9 to all rows PASS (10 RUN rows).
- **SC-002**: In no probe row is a file written empty or an archive deleted while data was not
  extracted.
- **SC-003**: The regression probes of features 306, 308, 309, 310, 321 and 393 keep their results.

## Assumptions

- Assumption (autonomous run): the archive's other members keep extracting after the reported names
  (as feature 310 does); only the success of the operation changes.
- Assumption (autonomous run): only crafted archives store data under an empty name (item *Notes*);
  no listing or message changes for them.
