# Feature Specification: Extraction of a PAX tar takes every member a file system takes

**Feature Branch**: `308-pax-deep-unpack`
**Created**: 2026-10-22
**Status**: Draft
**Input**: Backlog item `whole-archive-unpack-of-a-pax-tar-skips-deep-members-and-may` - "Whole-archive Unpack of a PAX tar skips deep members and may delete the archive". From backlog item whole-archive-unpack-of-a-pax-tar-skips-deep-members-and-may.

## Measured before the feature (aa7f08bb, `main`, Debug x64)

Probe `probe/unp308_probe.ps1` (fixture `probe/mkunp308.py`, Python `tarfile`, PAX format), run on the
hidden desktop -> `probe/result_before.txt`: PASS 5 (END rows) / FAIL 5.

- UNP-DEEP (Alt+F9 Unpack, mask `*.*`): 2 of 34 files extracted, one "(206)" box; the 30 files under a
  299-byte folder part, `CJK(90)/c.txt` and `CJK(255)/in.txt` are missing; the unpack reports success.
- UNP-DEEP-DEL (the same + "Delete archive after unpacking"): the same 2 of 34 files, and `t.tar` is
  **deleted** - 32 members lost.
- UNP-TOOLONG-DEL (`CJK(300).txt` - no file system takes it - and `ok.txt`, + Delete): `ok.txt`, "(206)",
  `t.tar` **deleted**.
- UNP-DEB (whole Unpack of a `.deb`): 3 of 5 files, the two deep data members missing.
- COPY-DEEP (Select All + Copy from the opened archive; the listed top folder holds deep members): 2 of
  32 files - the folder's 30 deep files silently missing, no message during the copy.

## Clarifications

### Session 2026-10-22

- Q: When a selected folder is copied out of an opened archive and holds a member with a too-long component, is the "(206)" box shown again although the listing showed one at opening? → A: Yes, once per operation, and the copy ends as failed - the box at opening named only the first refused member, and the copy must not look complete (autonomous run: conservative)
- Q: Does a refused member that the mask or selection does not include fail the extraction? → A: No - only a member the operation was asked to extract is reported and fails it (autonomous run: item - "a member that cannot be extracted ... makes the whole unpack fail")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Unpacking a whole PAX tar extracts the deep members (Priority: P1)

A user unpacks a tar made by Python, GNU tar `--format=posix` or Windows `tar.exe` that holds a deep
source tree (folder parts longer than 255 bytes, which NTFS takes). Every member is extracted.

**Why this priority**: today the members are silently left out; with "Delete archive after unpacking"
the archive is deleted and they are lost.

**Independent Test**: probe rows UNP-DEEP, UNP-DEEP-DEL, UNP-DEB.

**Acceptance Scenarios**:

1. **Given** a PAX tar with members under a 299-byte folder part, a 270-byte CJK folder part and a
   765-byte folder name, **When** the user unpacks the whole archive (Alt+F9), **Then** every member is
   extracted with its content and nothing is asked.
2. **Given** the same archive and "Delete archive after unpacking" checked, **When** the unpack ends,
   **Then** every member is extracted and only then the archive is deleted.
3. **Given** a `.deb` whose data part holds members deeper than the listing holds, **When** it is
   unpacked whole, **Then** every member of both parts is extracted.

---

### User Story 2 - An unextractable member keeps the archive (Priority: P1)

A member whose name has a component no file system takes (over 255 UTF-16 units) cannot be extracted.
The user is told (the system's "(206)" text with the path), the rest is extracted, and the unpack
counts as failed, so "Delete archive after unpacking" never deletes the archive.

**Why this priority**: data loss - the member exists only in the archive.

**Independent Test**: probe row UNP-TOOLONG-DEL.

**Acceptance Scenarios**:

1. **Given** a PAX tar with `CJK(300).txt` and `ok.txt` and Delete checked, **When** unpacked whole,
   **Then** a "(206)" box with the path is shown, `ok.txt` is extracted and the archive is kept.

---

### User Story 3 - Copying a folder from the opened archive copies its whole subtree (Priority: P2)

A user opens the archive in a panel (the listing leaves out members deeper than it can hold, as since
feature 306, with its "(206)" box at opening), selects a listed folder and copies it out. Every member
under that folder is extracted, also those the listing could not show.

**Why this priority**: the same silent omission as Story 1 on the other extraction route; no delete
option there, so no loss of the archive.

**Independent Test**: probe row COPY-DEEP.

**Acceptance Scenarios**:

1. **Given** the deep archive opened in a panel, **When** the user selects all and copies, **Then** the
   folder `a*29` arrives with `top.txt` and its 30 deep files, plus `ok.txt`.

### Edge Cases

- A member refused for a too-long component that the selection or mask does not include: not reported
  during that extraction, does not fail it (it was not asked for).
- Several refused members in one unpack: one box (the first path), as in feature 306; the unpack fails.
- The panel listing: unchanged - the listing bound (folder part / folder name over 255 bytes) still
  refuses those members alone when the archive is opened, with one "(206)" box; feature 306's probe
  stays 28 / 0.
- Extract one file (F3 view, single-file copy) of a refused member: it is never listed, so it cannot be
  asked for; if it were, the operation fails instead of reporting success.
- GNU long names (type `L`) and ustar names: not refused on `main` and not changed here.
- cpio / rpm members: their own reader, not changed.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The panel listing's bound (a folder part or a folder name over 255 bytes, a `.deb`
  prefix counted) MUST apply only while the archive is listed for a panel.
- **FR-002**: Every extraction (whole-archive Unpack, Copy of selected items, extraction of one file)
  MUST extract every member of a PAX path that a file system takes - no component over 255 UTF-16
  units - whatever its depth.
- **FR-003**: A member with a component over 255 UTF-16 units MUST still be refused in every pass -
  never cut, never extracted under its ustar fallback name.
- **FR-004**: When an extraction meets a refused member that it was asked to extract (it matches the
  mask or the selection), it MUST show the system's "(206)" text with the member's whole path (once
  per operation), continue with the other members, and end as failed.
- **FR-005**: A failed whole-archive Unpack MUST NOT delete the archive ("Delete archive after
  unpacking" acts only on success - the core's existing rule; this feature makes the result honest).
- **FR-006**: The listing (members shown, the "(206)" box at opening, the rest of the archive usable)
  MUST stay as feature 306 left it.

### Key Entities

- **Refused member**: a tar member whose PAX path cannot be used in the current pass - in the
  listing: too deep for the listing or a too-long component; in an extraction: a too-long component only.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `unp308_probe.ps1`: UNP-DEEP 34 of 34 files, UNP-DEEP-DEL 34 of 34 and the archive
  deleted, UNP-TOOLONG-DEL `ok.txt` + "(206)" + the archive kept, UNP-DEB 5 of 5, COPY-DEEP 32 of 32;
  every END row PASS (no crash, no stray window).
- **SC-002**: Feature 306's probe `pax306_probe.ps1` unchanged: 28 PASS / 0 FAIL.
- **SC-003**: `saltests` and the encoding guard stay at 0 failures.

## Assumptions

- Assumption (autonomous run): after a refused member the extraction continues with the rest (as
  today) and ends as failed - the user gets everything extractable and keeps the archive; aborting at
  the refusal would extract less and gain nothing (conservative, keeps the existing behaviour).
- Assumption (autonomous run): Copy of a selected folder extracts its members deeper than the listing
  (the item's Expected: "every extraction pass extracts every member a file system takes").
- Assumption (autonomous run): GNU long names are left to the blocked item
  `opening-a-tar-whose-member-name-has-a-300-letter-component` (branch `307-tar-long-component`); when
  it is resumed, its GNU refusal must use the same pass-dependent rule (recorded in that item's log).
- No UI string is added: the "(206)" text is the system's, as in feature 306.
