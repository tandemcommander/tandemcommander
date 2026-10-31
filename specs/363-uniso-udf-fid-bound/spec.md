# Feature Specification: ISO plug-in - a UDF file identifier that does not fit the folder buffer is refused

**Feature Branch**: `363-uniso-udf-fid-bound`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item iso-plug-in-a-udf-file-identifier-with-a-long-implementation - implement exactly what it describes." From backlog item iso-plug-in-a-udf-file-identifier-with-a-long-implementation.

## Clarifications

### Session 2026-11-01

- Q: Does the refusal show a message box, or is it silent like feature 362's unreadable folder? → A: the existing box "Invalid UDF Tag ID." - the identifier is refused exactly as the walk refuses an identifier with an invalid tag (autonomous run: item)
- Q: Does the bound cover only 38 + L_IU + L_FI, or the length padded to 4 bytes? → A: the padded length - it is the step to the next identifier, so the next position never passes the two sectors; no valid identifier exceeds one block (autonomous run: conservative)
- Q: Where does the rule live? → A: a pure function in the existing header `src/common/salisoudfentry.h` (features 361 / 362's rules of the same UDF reader) with `saltests` checks (autonomous run: rule, stop-rules §2.5)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged file identifier no longer costs the user the image (Priority: P1)

A user has a damaged or crafted UDF disc image (for example a genisoimage `-udf` hybrid) in which one of a
folder's file identifiers declares an implementation-use length (L_IU) or a name length (L_FI) that puts its
name past the bytes of the folder the ISO plug-in holds. Today the plug-in reads the name from memory past its
buffer (up to 64 KB past it), lists the entry under a made-up name (`_`), goes on walking the folder and never
marks the listing; a whole unpack (Alt+F9) with "Delete archive after unpacking" extracts a wrong tree, reports
success and **deletes the image**. After the fix the identifier is refused like an identifier with an invalid
tag: the existing box "Invalid UDF Tag ID." is shown, the folder's walk ends there, the listing is marked
incomplete (feature 330), the unpack fails and the image is kept. Nothing is read past the buffer.

**Why this priority**: the item's main point - a read past a stack buffer, and the user's only copy of the data
deleted.

**Independent Test**: probe `iso363_probe` rows R-AIU, R-TIU, R-SIU, R-AIU4K, R-AFI on the hidden desktop, Debug
build, copies of feature 330's `ud.iso` with one identifier changed by `img363.py`.

**Acceptance Scenarios**:

1. **Given** `ud.iso` whose root identifier of folder `a` has L_IU 0xFFFF, **When** the user unpacks it whole
   with "Delete archive after unpacking", **Then** "Invalid UDF Tag ID." is shown, the ISO 9660 part's three files
   are extracted with their content, nothing of the UDF part is extracted (its walk ends at the first entry), and
   the image is **kept**.
2. **Given** `ud.iso` whose root identifier of `top.txt` has L_IU 0xFFFF, **When** unpacked the same way,
   **Then** the box is shown, the ISO 9660 part and the UDF part's `a/side.txt` (listed before) are extracted, and
   the image is kept.
3. **Given** `ud.iso` whose identifier of `side.txt` inside folder `a` has L_IU 0xFFFF, **When** unpacked the same
   way, **Then** the box is shown, the ISO 9660 part and the UDF part's `top.txt` are extracted (330: no later
   folder is descended after a folder that could not be read), and the image is kept.
4. **Given** `ud.iso` whose root identifier of folder `a` has L_IU 0x1000 (past the buffer, inside 64 KB), or
   L_IU 4000 with L_FI 255 (the name starts inside the buffer and ends past it), **When** unpacked the same way,
   **Then** the same result as scenario 1.

---

### User Story 2 - Listing a damaged image reports it (Priority: P1)

The user presses Enter on such an image. Today nothing is reported and a made-up `_` entry is listed. After the
fix the box "Invalid UDF Tag ID." is shown, the program keeps answering, and no bug report appears.

**Why this priority**: the same defect, seen at listing.

**Independent Test**: probe rows L-AIU, L-AIU4K, L-AFI.

**Acceptance Scenarios**:

1. **Given** any of the images of story 1 scenarios 1 and 4, **When** the user presses Enter on it, **Then**
   "Invalid UDF Tag ID." is shown, the program keeps answering, no bug report.

---

### User Story 3 - Intact images are unchanged (Priority: P2)

A valid UDF image lists and unpacks as today; a whole unpack still deletes it when asked to.

**Why this priority**: no regression of the readable case.

**Independent Test**: control rows L-UD, C-UD; the probes of features 330, 361 and 362 re-run.

**Acceptance Scenarios**:

1. **Given** the intact `ud.iso`, **When** listed, **Then** no window; **When** unpacked whole with "Delete
   archive after unpacking", **Then** all six files of both parts are extracted, no window, the image is deleted.

### Edge Cases

- An identifier that ends exactly at the end of the held bytes fits (no refusal at the bound).
- UDF limits one identifier to one logical block (2048 bytes, padding included); the walk holds at least 2048
  bytes from any identifier it reads (it reads two sectors and starts each identifier at most one sector into
  them), so no valid identifier is ever refused.
- The 4-byte padding: an identifier is refused also when its padded length passes the held bytes, so the next
  identifier's position never lies past the two sectors.
- An identifier with L_FI 0 (the parent identifier) and a large L_IU is refused too: its length moves the walk.
- Deleted identifiers (`UDF_DELETED`) and multi-extent folders are out of scope (other Inbox items).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Before the folder walk reads a file identifier's name, it MUST decide whether the identifier -
  38 bytes + L_IU + L_FI, padded to a multiple of 4 - lies within the bytes the walk holds from the identifier's
  position; computed without wrap-around.
- **FR-002**: An identifier that does not fit MUST be refused exactly as an identifier with an invalid tag is
  today: the box "Invalid UDF Tag ID.", the folder's walk ends, the result reaches the top as an unreadable folder
  and the listing is marked incomplete (feature 330), so a whole unpack fails and "Delete archive after
  unpacking" keeps the image.
- **FR-003**: Nothing past the folder buffer MAY be read for any identifier, whatever its L_IU and L_FI.
- **FR-004**: Identifiers that fit MUST be read as before (same name, same next position).
- **FR-005**: No new UI string, no change of the plug-in interface, no change outside the ISO plug-in's UDF
  folder walk and its rule.
- **FR-006**: The decision MUST be a pure rule in `src/common/salisoudfentry.h` with `saltests` checks (stop-rules
  §2.5).

### Key Entities

- **File identifier**: the UDF descriptor (tag 257) of one folder entry - flags, L_FI (name length, 8 bits),
  L_IU (implementation-use length, 16 bits), then the implementation use and the name, padded to 4 bytes.
- **Folder buffer**: the two sectors the walk holds; an identifier is read from position p (at most one sector
  in).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In every damaged probe row (R-AIU, R-TIU, R-SIU, R-AIU4K, R-AFI) the image is kept and exactly the
  readable files are extracted (before: deleted in 5 of 5).
- **SC-002**: In every damaged listing row the user is told ("Invalid UDF Tag ID.") and the program answers
  (before: told in 0 of 3).
- **SC-003**: The control rows and the earlier UDF probes (330, 361, 362) pass unchanged.
- **SC-004**: The rule's checks fail when the bound is removed or computed with wrap-around (negative control).

## Assumptions

- Assumption (autonomous run): the refusal shows the existing "Invalid UDF Tag ID." box, as the invalid-tag path
  does today - the item says "refused like an invalid tag" (item).
- Assumption (autonomous run): the bound covers the padded length, not only 38 + L_IU + L_FI, so the next position
  stays within the buffer; valid images are unaffected (UDF 2.01 2.3.4: an identifier never exceeds a logical
  block) (conservative).
- The seed image comes from feature 330's `mkimg330.sh` (WSL Ubuntu, genisoimage); without it the rows are NOT
  DRIVEN.
