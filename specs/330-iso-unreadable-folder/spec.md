# Feature Specification: An image whose folder could not be read is kept by Unpack with "Delete archive after unpacking"

**Feature Branch**: `330-iso-unreadable-folder`  
**Created**: 2026-10-23  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-unpack-deletes-image-with-unreadable-folder` - "ISO plug-in: Unpack with Delete archive deletes an image whose folder could not be read". From backlog item iso-plug-in-unpack-deletes-image-with-unreadable-folder.

## Background (traced and measured at ae41208d)

When the ISO plug-in (`uniso`, on in the default build) cannot read a folder of a disc image - its
directory lies past the end of the image, or a record of it fails the plug-in's safety checks - it
shows "Error reading directory structure at sector #... Incomplete content of ISO image." and goes
on with what it has. From then on the ISO 9660 walk descends into no later folder, and the listing is
not marked incomplete. Unpack (Alt+F9) of the whole image with "Delete archive after unpacking" then
extracts what was listed, reports success, and the image is deleted: files that were never extracted
are lost. Feature 328 made a whole unpack fail when the listing left out entries the panel refuses
(the plug-in's "listing incomplete" mark), not after a read error.

Measured on the Debug build at ae41208d with review 4 of 328's image `rderr.iso` (genisoimage `-R` of
`a/side.txt`, `top.txt`, `zlast/z.txt`; folder A's directory pointed past the end of the image) and
its probe row RDERR-UNP-DEL on the hidden desktop: the box above, **1 of 3 files extracted**
(`top.txt`; `zlast/z.txt` is readable but its folder comes after A and is never descended) and the
**image deleted**.

The plug-in's UDF reader (a UDF image, the UDF part of a hybrid; also its File Set Descriptor) and
Xbox reader show the same box after a failed directory read and do not mark the listing either - the
same defect for "an image whose folder could not be read". Review 1 (a reviewer that stopped; its
images) measured three more UDF folders that cannot be read, each deleting the image: a folder whose
file entry cannot be read (listed empty without a word), a directory starting with an invalid tag
("Invalid UDF Tag ID."), and a root that cannot be found ("Bad root ICB. Cannot read directory
structure." - nothing of the UDF part listed). HFS+ catalog records skipped as damaged stay with the
separate Inbox item `iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let`.

## Clarifications

### Session 2026-10-23

- Q: Which failures mark the listing incomplete? → A: every failure of the ISO 9660 folder walk that
  leaves something unlisted (a directory read error, a record that fails the safety checks, an empty
  directory extent, out of memory - each already ends the walk of that directory and of every later
  folder); the same rule for the Xbox walk; for UDF the same rule plus a root that cannot be found or
  read and a folder whose file entry cannot be read (review 1) (autonomous run: item - *Expected* "a
  listing that met a read error is marked incomplete"; the title "an image whose folder could not be
  read" covers the other readers)
- Q: Should later folders still be descended after a read error (it would list `zlast\z.txt`)? → A:
  no, unchanged in this feature; recorded as a new Inbox idea (autonomous run: item - "a separate
  question"; conservative)
- Q: Does the user see a new message? → A: no - the existing "Error reading directory structure ...
  Incomplete content of ISO image" box is the report; no second box, no new UI string (autonomous
  run: conservative - the box already says the content is incomplete)
- Q: Entries a UDF / HFS+ reader skips as damaged? → A: HFS+ unchanged - the Inbox item
  `iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let`; UDF: every such failure ends a folder's
  walk, so the UDF rule above already marks it (a file entry that cannot be read ends its directory)
  (autonomous run: conservative - fail closed; review 1)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Unpack + delete keeps an image whose folder could not be read (Priority: P1)

A user unpacks a damaged ISO image (Alt+F9) with "Delete archive after unpacking". One of its folders
cannot be read. Today the files that were listed are extracted, the image is deleted and every file
in the unreadable folder - and in every later folder - is lost. Now the files that were listed are
extracted, the error box is shown as today, and the image stays.

**Why this priority**: data loss - the only copy of files the plug-in could not extract is deleted.

**Independent Test**: probe Unpack rows of crafted images (an ISO 9660 folder past the end of the
image; an ISO 9660 record failing the safety checks; an Xbox folder past the end; a UDF folder whose
directory lies past the end) with "Delete archive after unpacking": the listed files extracted, the
error box shown, the image kept.

**Acceptance Scenarios**:

1. **Given** an ISO 9660 image whose folder A's directory lies past the end of the image, **When** it
   is unpacked whole with "Delete archive after unpacking", **Then** `top.txt` is extracted, the
   "Error reading directory structure" box is shown, and the image is kept.
2. **Given** an ISO 9660 image where a record of folder A fails the safety checks, **When** unpacked
   the same way, **Then** the box is shown and the image is kept.
3. **Given** an Xbox image or the UDF part of a hybrid whose folder's directory lies past the end,
   **When** unpacked the same way, **Then** the box is shown and the image is kept.
4. **Given** a UDF + ISO 9660 hybrid whose UDF folder entry cannot be read, whose UDF directory
   starts with an invalid tag, or whose UDF root cannot be found, **When** unpacked the same way,
   **Then** the image is kept (with the existing box, or none where none was shown).

---

### User Story 2 - A readable image is unpacked and deleted as before (Priority: P1)

**Why this priority**: the fix must not make every unpack fail.

**Independent Test**: the same probe's control rows - the undamaged seed images unpacked the same
way: every file extracted, no box, the image deleted.

**Acceptance Scenarios**:

1. **Given** the undamaged seed image of each damaged one, **When** it is unpacked with "Delete
   archive after unpacking", **Then** every file is extracted, no box is shown, and the image is
   deleted as today.

### Edge Cases

- The root directory itself cannot be read: the box is shown as today; the listing is marked
  incomplete (a whole unpack fails, the image is kept).
- A hybrid image whose ISO 9660 part cannot be read but whose UDF part can: the listing is marked
  incomplete (fail closed - the box says the content is incomplete).
- A folder cycle in a crafted image (feature 328's visited set lists a directory met again as empty)
  is not a read error: not marked, as today.
- Browsing the image in the panel and copying selected files are unchanged (the mark only makes a
  whole-image unpack fail).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: An ISO 9660 listing whose folder walk failed anywhere (a directory that cannot be read,
  a record failing the safety checks, an empty directory extent, out of memory) MUST be marked
  incomplete.
- **FR-002**: A UDF or Xbox listing whose walk failed anywhere (a directory that cannot be read, an
  invalid tag, a file entry that cannot be read, out of memory) MUST be marked incomplete; so MUST a
  UDF listing whose root cannot be found or read (its File Set Descriptor, its root ICB) and one
  where a folder's file entry cannot be read (the folder listed empty); and a hybrid whose declared
  ISO 9660 or UDF part does not open at all (review 2: its volume descriptors cannot be read - the
  part is dropped from the listing). An HFS+ part keeps its quiet handling (Inbox).
- **FR-003**: A whole-image unpack of a listing marked incomplete MUST extract the listed entries and
  fail, so "Delete archive after unpacking" keeps the image (feature 328's existing behaviour of the
  mark).
- **FR-004**: The messages shown are unchanged: the existing "Error reading directory structure" box,
  no second box, no new text.
- **FR-005**: A listing without such a failure MUST be exactly as today - its unpack succeeds and the
  image is deleted when asked.

### Key Entities

- **Listing incomplete mark**: feature 328's flag of an image's listing; set, a whole-image unpack
  fails and the image is kept.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: the new probe's damaged-image Unpack rows (ISO 9660 extent past the end, record failing
  the checks, empty extent; UDF directory past the end, unreadable folder entry, invalid tag, root
  not found; Xbox) go from the image deleted before the fix to the image kept after it; its control
  rows (the undamaged images) pass before and after.
- **SC-002**: features 328 (`iso328_probe`) and 329 (`iso329_probe`) probes stay all PASS.
- **SC-003**: saltests keep 0 failed; build and encoding guard clean.

## Assumptions

- Assumption (autonomous run): the existing box is the user's report - no new UI string, no
  translation refresh, no change to the manual.
- Assumption (autonomous run): later folders are still not descended after a read error (the item's
  "separate question"; a new Inbox idea records it).
- Assumption (autonomous run): crafted images are made by a probe script from seed images of
  genisoimage (WSL, as features 328 / 329) and by a Python writer (Xbox, as 329's `img329.py`).
