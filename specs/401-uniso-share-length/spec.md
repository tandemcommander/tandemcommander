# Feature Specification: An ISO 9660 folder met again with another length is walked for its own length

**Feature Branch**: `401-uniso-share-length`  
**Created**: 2026-11-02  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-an-iso-9660-folder-met-again-with-a-larger` - "ISO plug-in: an ISO 9660 folder met again with a larger length is listed empty". From backlog item iso-plug-in-an-iso-9660-folder-met-again-with-a-larger.

## Background (traced and measured at 53eb98ab)

The ISO plug-in (`uniso`, on in the default build) walks the folders of an ISO 9660 volume once each
(feature 328: a crafted image whose folders point back to an ancestor never ended its walk). It
recognises "a folder met before" by the folder's start block alone, but every folder record of an
image gives its own data length. When two folder records of a crafted or damaged image point to the
same start block with different lengths, the second folder is treated as met before and listed
**empty**: no box is shown and the listing is not marked incomplete. A whole Unpack with "Delete
archive after unpacking" then counts as complete and deletes the image, although the files the
second folder's longer extent holds were never extracted.

Feature 400 met the same pattern in its new Xbox walk (review 1, `xd_share.iso`) and keyed that walk
by start sector and size; the ISO 9660 walk was left as 328 made it.

Measured on the Debug build at 53eb98ab with a new probe (`iso401_probe.ps1`, hidden desktop, images
written from scratch by `img401.py`: plain ISO 9660, nothing damaged; Unpack of the whole image with
"Delete archive after unpacking"): PASS 6 / FAIL 4.

| Row | Image | Before |
|-----|-------|--------|
| IS-SHARE | root: A (block S, 2048 bytes), B (S, 4096 bytes), TOP.TXT; S holds A1.TXT, S + 1 A2.TXT | A/A1.TXT, TOP.TXT - B empty (b/a1.txt, b/a2.txt missing), no window, the image deleted |
| IS-SHARE2 | the same, the longer record first | b/a1.txt missing, no window, the image deleted |
| IS-LOOP | A (S, 2048) holds L (S itself, 4096 bytes); TOP.TXT, ZLAST/Z.TXT | a/l/a1.txt, a/l/a2.txt missing, the image deleted |
| IS-MANY | A (S, 2048) and 40 folders at S with lengths 4096..83968 | only A/A1.TXT, TOP.TXT, the image deleted |
| IS-HLINK | A and B at one block with one length (control) | a/x.txt, top.txt, B empty, the image deleted (328's rule - unchanged) |

## Clarifications

### Session 2026-11-02

- Q: Is a folder met again with another length walked for its own length, or listed empty with the
  listing marked incomplete? → A: walked for its own length (the visit key is block and length) - every
  file its record covers is listed and extracted, a loop still ends because each pair is walked once
  (autonomous run: item - *Approach*, as 400's Xbox walk)
- Q: Does a folder met again with the same block and the same length now mark the listing incomplete,
  as the UDF and Xbox walks do since 400? → A: no, 328's behaviour stays (listed empty, not marked); the
  difference is recorded as an Inbox item (autonomous run: conservative - the item does not name it)
- Q: What happens when the longer length runs past the end of the image? → A: as for any folder that
  cannot be read (330 / 400): one error box per walk, the listing marked incomplete, later folders still
  walked (autonomous run: conservative - existing behaviour)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every folder of the image is listed with the files its own record covers (Priority: P1)

A user opens or unpacks a disc image in which two folder records point to one directory with
different lengths. Each folder shows the files its own record covers; a whole Unpack extracts all of
them, so "Delete archive after unpacking" never deletes an image whose files were not extracted.

**Why this priority**: this is the item - the image was deleted with files never extracted (data loss).

**Independent Test**: probe row IS-SHARE (and IS-SHARE2): Unpack of the crafted image with "Delete
archive after unpacking" extracts a/a1.txt, b/a1.txt, b/a2.txt, top.txt.

**Acceptance Scenarios**:

1. **Given** an ISO 9660 image whose root holds folder A (block S, 2048 bytes) and folder B (block S,
   4096 bytes) and file TOP.TXT, **When** the user unpacks the whole image with "Delete archive after
   unpacking", **Then** a/a1.txt, b/a1.txt, b/a2.txt and top.txt are extracted with their contents, no
   window is shown, and the image is deleted (everything was extracted).
2. **Given** the same image with the longer record first, **When** unpacked the same way, **Then**
   a/a1.txt, a/a2.txt, b/a1.txt and top.txt are extracted, no window, the image deleted.

---

### User Story 2 - Crafted folder loops still end (Priority: P1)

A crafted image whose folder points back to its own directory with another length, or holds many
folders naming one directory with many lengths, still opens and unpacks in bounded time.

**Why this priority**: feature 328's visited set exists against such loops; the change must not
reopen them.

**Independent Test**: probe rows IS-LOOP and IS-MANY: the program answers, the expected files are
extracted.

**Acceptance Scenarios**:

1. **Given** folder A (S, 2048) holding folder L (S itself, 4096 bytes), **When** unpacked, **Then**
   the program answers, a/a1.txt, a/l/a1.txt, a/l/a2.txt, top.txt, zlast/z.txt are extracted; a/l/l (met
   again with its own length) is listed empty as before.
2. **Given** 40 folders at one block with 40 lengths, **When** unpacked, **Then** each of them holds
   a1.txt and the program answers.

---

### User Story 3 - A folder met again with the same length behaves as before (Priority: P2)

Two folder records naming one directory with the same start block and the same length keep feature
328's behaviour (the second listed empty).

**Independent Test**: probe row IS-HLINK unchanged; 328's and 400's probes unchanged.

**Acceptance Scenarios**:

1. **Given** folders A and B at one block with one length, **When** unpacked, **Then** a/x.txt and
   top.txt, no window, the image deleted (as at 53eb98ab).

### Edge Cases

- A shorter record met after a longer one (IS-SHARE2): walked for its own length too (a subset).
- A folder pointing to itself with a longer length (IS-LOOP): walked once per distinct length, then
  met again.
- Rock Ridge volumes whose names do not fit (328's decision mode): the count walks add and take out
  their folders by the same key (block and length), so a count walk never leaves a folder marked met.
- The fit-check walk (328) uses its own set by the same key.
- Joliet volumes walk the same function: the same key.
- Out of memory while recording a folder: as today (the walk stops, the listing is marked).
- A longer length that runs past the end of the image: a folder that cannot be read (330 / 400's
  handling: one box per walk, the listing marked, later folders walked).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The ISO 9660 walk MUST recognise a folder met before by its start block **and** its
  data length together; a record with the same block and another length is walked for its own length.
- **FR-002**: A folder met again with the same block and the same length MUST keep feature 328's
  behaviour (listed empty, nothing marked).
- **FR-003**: Every walk MUST stay bounded: each distinct (block, length) pair is walked at most once
  per walk; the pairs come from the image's records.
- **FR-004**: The count walks of 328's decision mode MUST take out exactly the folders they added,
  by the same key.
- **FR-005**: No other reader (UDF, Xbox, HFS+) changes its behaviour (the Xbox walk may take the
  shared key function, which gives the same key it computes today), and no other behaviour of the
  ISO 9660 walk changes.

### Key Entities

- **Folder visit key**: a folder's start block (after the extended attribute record) together with
  its record's data length.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `iso401_probe` goes from PASS 6 / FAIL 4 to PASS 10 / FAIL 0 (IS-SHARE,
  IS-SHARE2, IS-LOOP, IS-MANY fixed; IS-HLINK unchanged).
- **SC-002**: Probes of 328 (`iso328_probe`, LOOP rows included) and 400 (`iso400_probe`) keep their
  results (20 / 0 and 48 / 0 as recorded; rows whose seed images need WSL Ubuntu are NOT DRIVEN
  when it is missing, and are compared as such).
- **SC-003**: The build and `saltests` pass (0 failed); the encoding guard reports 0 findings.

## Assumptions

- Assumption (autonomous run): the item's *Approach* is taken - walk again for the other length
  (not "mark incomplete"), as feature 400 did for the Xbox walk.
- Assumption (autonomous run): a folder met again with the same block and length keeps 328's
  behaviour (not marked, unlike UDF / Xbox since 400): the item does not name that case
  (stop-rules §1 step 4); the inconsistency is recorded as an Inbox item.
- Crafted or damaged images only; genisoimage / xorriso never write two records for one directory.
- No UI text, dialog or translation changes.
