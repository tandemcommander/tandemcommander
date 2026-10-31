# Feature Specification: A CloneCD image without its .ccd is kept when it holds more than its listing shows

**Feature Branch**: `353-uniso-noccd-sessions`  
**Created**: 2026-10-31  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-a-clonecd-image-without-its-ccd-lists-one` - "ISO plug-in: a CloneCD image without its .ccd lists one session, then Unpack deletes it". From backlog item iso-plug-in-a-clonecd-image-without-its-ccd-lists-one.

## Background (measured at b9272d3e)

The ISO plug-in (`uniso`, on in the default build) opens a CloneCD disc image (`.img`) by reading the
`.ccd` text file beside it, which describes the disc's sessions and tracks. When the `.ccd` is missing
(lost, renamed, not copied), the plug-in shows "Missing .CCD file. Displayed image could be
incomplete." and detects the image as a plain one: it lists only the file system whose volume
descriptor is at sector 16 of the file - the first session of a multi-session dump. A whole Unpack
(Alt+F9) with "Delete archive after unpacking" then succeeds and deletes the image, and the later
sessions' files are lost. Feature 352 marks the listing incomplete when a `.ccd` exists but is
refused; a missing `.ccd` was left unchanged on purpose (352's FR-006: an `.img` without `.ccd` is
often a plain disk image).

Measured with a new hidden-desktop probe `iso353_probe` (Debug build at b9272d3e; images by a new
`img353.py` from feature 334's `mkimg334.sh` seeds - session 1 of 176 sectors whose primary volume
descriptor gives a volume of 176 sectors, session 2 addressed after it; raw 2352-byte Mode 1 sectors
as CloneCD stores them; no `.ccd`): 10 PASS / 2 FAIL.

- R-NOCCD2 (two raw sessions, 176 + 176 sectors): only `a.txt` of session 1 extracted, the image
  **deleted** - `b.txt` of session 2 lost. The defect.
- R-REST17 (one session + 17 raw sectors after its volume - room for a later volume's sector 16):
  deleted.
- C-NOCCD (one raw session), C-REST2 / C-REST16 (one session + 2 / 16 sectors - no room for a later
  volume descriptor), C-COOKED (a plain 2048-byte `.img`): `a.txt` extracted, the image deleted - as
  wanted.

Every row shows the "Missing .CCD file" box (once per open of the image).

## Clarifications

### Session 2026-10-31

- Q: How does the plug-in tell, cheaply, that an image without its `.ccd` holds more than the plain detection lists? → A: By size: the listed volume's size (from its primary volume descriptor at sector 16) against the sectors the file holds; reading the rest of the file to search for a later volume descriptor is not done (opening would read the whole image) (autonomous run: item *Notes* names both; the size comparison is the conservative one - it never reads more and marks every image a later session could hide in)
- Q: How many sectors past the listed volume are tolerated before the image counts as holding more? → A: 16 - a later session's volume descriptor lies at its own sector 16, so a rest of 16 sectors or fewer cannot hold a later volume; 17 or more can, and is marked (autonomous run: conservative - no tolerance that could let a later session be deleted; CLAUDE.md *Never lose the user's data*: fails closed)
- Q: Which images without a `.ccd` does the check apply to? → A: Only raw images (2352-byte sectors with the CD sync pattern at the start, as CloneCD writes them); a plain `.img` of 2048-byte sectors (a disk image) is unchanged (autonomous run: item - "a plain single-volume `.img` (disk image, one session) unpacks and is deleted as today" - and conservative: keeps the existing behaviour for the case the item does not name)
- Q: What when the size of the listed volume cannot be read (no primary volume descriptor at sector 16 - for example a UDF-only or HFS raw dump)? → A: The listing is marked incomplete (autonomous run: conservative - refuses rather than guesses)
- Q: Is a new message shown for a kept image? → A: No - the existing "Missing .CCD file. Displayed image could be incomplete." box already says the listing may be incomplete; no UI string changes (autonomous run: conservative; as feature 352)
- Q: When the start of the file has the CD sync pattern (raw) but the image is then opened by one of the other plain checks (not the volume descriptor at sector 16 of the raw layout), does the rule still apply? → A: Yes - "raw" is decided by the sync pattern at the start of the file alone; the listed volume's size is read where the opened layout puts sector 16, and when no primary volume descriptor is there the listing is marked (autonomous run: conservative - one simple rule that fails closed rather than a list of exceptions)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A multi-session image without its .ccd is not deleted after a partial unpack (Priority: P1)

A user unpacks a whole CloneCD image (Alt+F9) with "Delete archive after unpacking" checked, and the
image's `.ccd` is not beside it. The image holds a second session past the first session's volume.
The plug-in shows the existing "Missing .CCD file" box, extracts what it lists (the first session's
files), and the unpack is reported as not complete, so the image is kept and the second session's
data is not lost.

**Why this priority**: losing the later sessions' files with the image is the item's main point.

**Independent Test**: probe row R-NOCCD2: `a.txt` extracted, only "Missing .CCD file" boxes, the image
kept.

**Acceptance Scenarios**:

1. **Given** a raw two-session `.img` without `.ccd`, **When** a whole unpack with "Delete archive after
   unpacking" runs, **Then** the first session's files are extracted and the image is kept.
2. **Given** a raw one-session `.img` without `.ccd` followed by 17 or more sectors past its volume,
   **When** a whole unpack with "Delete archive after unpacking" runs, **Then** the image is kept.

---

### User Story 2 - A one-session image and a plain disk image still unpack and are deleted (Priority: P2)

A user unpacks an `.img` without `.ccd` that holds a single volume - a raw one-session dump (possibly
with a track-at-once run-out of a few sectors) or a plain 2048-byte disk image. The unpack works as
before: the files are extracted and, with "Delete archive after unpacking", the image is deleted.

**Why this priority**: the change must not turn every image without `.ccd` into one that is kept.

**Independent Test**: probe rows C-NOCCD, C-REST2, C-REST16, C-COOKED: `a.txt` extracted, the image
deleted.

**Acceptance Scenarios**:

1. **Given** a raw one-session `.img` without `.ccd` whose file ends within 16 sectors after its volume,
   **When** a whole unpack with "Delete archive after unpacking" runs, **Then** the files are extracted
   and the image is deleted.
2. **Given** a plain `.img` of 2048-byte sectors without `.ccd`, **When** the same unpack runs, **Then**
   the result is as before this feature (extracted, deleted).

### Edge Cases

- The `.ccd` exists and is valid, or exists and is refused: unchanged (feature 352's behaviour).
- The `.ccd` cannot be opened for another reason (access denied, locked): treated as missing - the
  plug-in cannot tell, and the image is detected without it in both cases.
- The raw image's sector 16 holds no primary volume descriptor (UDF only, HFS): marked (fails closed).
- The file ends before the listed volume does (a truncated image): this feature does not mark it (the
  rest is not past the volume); unchanged.
- The file's length is not a whole number of sectors: only whole sectors count.
- A raw image whose sector 0 has no sync pattern (for example a first audio track): the plain
  detection does not treat it as raw; unchanged.
- An image the plain detection does not open at all ("Unknown file format"): unchanged - nothing is
  listed or unpacked.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When an `.img` is opened without its `.ccd` and detected as a raw image (the CD sync
  pattern at the start of the file, 2352-byte sectors - whichever plain check then opens it), and the file holds more than 16 whole sectors past the end of the volume the plain
  detection lists, the plug-in MUST mark the listing incomplete, so that a whole unpack fails and
  "Delete archive after unpacking" keeps the image.
- **FR-002**: When the size of the listed volume cannot be read for such a raw image, the listing MUST be
  marked incomplete.
- **FR-003**: A raw image without `.ccd` whose file ends within 16 sectors past its volume, and an `.img`
  without `.ccd` detected with 2048-byte sectors, MUST list, unpack and be deleted as before this
  feature.
- **FR-004**: The files the plain detection lists MUST still be listed and extracted; only the
  completeness of the listing changes.
- **FR-005**: The existing "Missing .CCD file" box MUST stay as it is; no UI string, dialog or menu is
  added or changed.
- **FR-006**: The behaviour with a `.ccd` present (valid or refused) MUST NOT change.
- **FR-007**: The decision (raw or not, volume size, file size → marked or not) MUST be a pure rule with
  unit checks.

### Key Entities

- **Listed volume**: the file system whose volume descriptor is at sector 16 of the image; its size in
  sectors is given by its primary volume descriptor.
- **Rest of the image**: the whole sectors of the file past the listed volume's end.
- **Listing incomplete mark**: the existing state (features 328, 334, 352) that makes a whole unpack of
  the listing fail, so the image is kept.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe, a two-session raw image without `.ccd` is kept after a whole unpack with
  "Delete archive after unpacking" (0 of 1 deleted, before: 1 of 1).
- **SC-002**: In the probe, every one-session image without `.ccd` within 16 sectors of its volume, and
  the plain 2048-byte image, is still deleted after the same unpack (4 of 4).
- **SC-003**: Feature 352's probe (22 rows) and feature 351's probe pass as recorded.
- **SC-004**: The unit rule's checks pass, and a mutant of the rule (no mark for a raw image past its
  volume) fails at least one check.

## Assumptions

- Assumption (autonomous run): CloneCD writes `.img` files as raw 2352-byte sectors; an `.img` with
  2048-byte sectors is a plain disk image, never a CloneCD dump.
- Assumption (autonomous run): a later session of a CloneCD dump lies in the file past the first
  session's volume (the probe's images place it directly after; real dumps place it at least as far).
- Assumption (autonomous run): a raw one-session dump whose track holds more than 16 sectors past its
  volume (a large post-gap or padding to a minimum track length) is kept after a whole unpack - it is
  not deleted, the user deletes it by hand; no data is lost.
- Crafted images only; a real CloneCD dump without its `.ccd` is a person's check if one is owed.
- Out of scope: reading the sessions of an image without `.ccd` (the plug-in still lists only the first
  session); the track-table item `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables`.
