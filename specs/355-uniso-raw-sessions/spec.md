# Feature Specification: ISO plug-in keeps a raw multi-session image not named .img

**Feature Branch**: `355-uniso-raw-sessions`
**Created**: 2026-10-31
**Status**: Draft
**Input**: User description: "Backlog item iso-plug-in-a-raw-multi-session-image-not-named-img-lists - implement exactly what it describes: a raw disc image (2352-byte sectors with the CD sync pattern - a `.bin` without its `.cue`, an Alcohol 120% `.mdf`, a raw dump named `.iso`) holding a second session past the first is listed as the first session only, and a whole Unpack with Delete archive after unpacking deletes it with the later session's files." From backlog item iso-plug-in-a-raw-multi-session-image-not-named-img-lists.

## Measured before (main at 4cc97934)

Probe `probe/iso355_probe.ps1` + `probe/img355.py` (seeds from 334's `mkimg334.sh`: `s1.iso`, 176 sectors,
a.txt; `s2.iso`, b.txt) on the Debug x64 build, hidden desktop: **30 PASS / 10 FAIL**. Deleted after a whole
unpack with "Delete archive after unpacking" (only a.txt extracted): raw Mode 1 s1 + s2 named `two.iso`,
`two.bin`, `two.mdf`; the same as Mode 2 Form 1 (XA); s1's volume size claiming 400 sectors; s1 truncated by
2 sectors; s1 + 17 sectors of non-zero user data; s1 + 513 zero sectors; s1 + 300 zero sectors whose last
user byte is 1; s1 + 300 sectors of audio-like bytes (a CD-Extra `.bin` without its `.cue`). Raw one-session
images, s1 + 16 non-zero sectors, s1 + 150 zero-user-data sectors (a post-gap), s1 + 2 zero sectors (a
run-out), s1 + 512 zero sectors and a cooked s1 named `.bin` are deleted (correct); 353's `.img` rows are kept
with the "Missing .CCD file" box. No real `.bin` / `.cue` / `.mdf` exists on the machine.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A raw multi-session image is kept by a whole unpack (Priority: P1)

A user has a raw disc image - a `.bin` whose `.cue` is not beside it, an `.mdf`, or a raw dump named `.iso` -
of a multi-session disc. They unpack the whole image (Alt+F9) with "Delete archive after unpacking". Today the
first session's files are extracted and the image is deleted: the later session's files are lost. After the
change the unpack does not count as complete, and the image is kept.

**Why this priority**: it is the data loss the item names.

**Independent Test**: the probe's R rows: a raw two-session image under each name, extracted whole with the
delete option, must still exist afterwards with a.txt extracted.

**Acceptance Scenarios**:

1. **Given** a raw two-session image named `.iso`, `.bin` or `.mdf`, **When** the user unpacks it whole with
   "Delete archive after unpacking", **Then** the first session's files are extracted and the image is kept.
2. **Given** the same image written as Mode 2 Form 1 (XA) sectors, **When** unpacked the same way, **Then** it
   is kept.
3. **Given** a raw image whose rest past the listed volume holds audio data (a data + audio disc without its
   `.cue`), **When** unpacked the same way, **Then** it is kept (the audio is never extracted).
4. **Given** a raw image whose volume descriptor claims more sectors than the file holds, or whose file ends
   within the volume, **When** unpacked the same way, **Then** it is kept (the size cannot be trusted).

---

### User Story 2 - A raw one-session image unpacks and is deleted as before (Priority: P2)

A raw image of a one-session data disc - the file ends with the volume, or with no more than 16 sectors past
it, or with a tail that holds no data (a post-gap or run-out of zero user data, at most 512 sectors) - is
extracted and deleted as today.

**Why this priority**: keeping every raw image would make "Delete archive after unpacking" useless for the
common `.bin` of a one-session disc.

**Independent Test**: the probe's C rows: each image extracted and deleted, no window shown.

**Acceptance Scenarios**:

1. **Given** a raw one-session image named `.iso`, `.bin` or `.mdf`, **When** unpacked whole with the delete
   option, **Then** it is extracted and deleted.
2. **Given** a raw image with 16 sectors of any data past its volume, or up to 512 sectors whose user data is
   zero bytes, or a tail of whole zero sectors, **When** unpacked the same way, **Then** it is deleted.

---

### Edge Cases

- A tail longer than 512 sectors is not read and keeps the image even when it is all zero (as 354).
- A tail of zero sectors whose very last user byte is not zero keeps the image (the whole tail is read).
- An `.img` without its `.ccd` keeps 353's rule unchanged (it is marked for more than 16 sectors past the
  volume, zero or not, and shows the "Missing .CCD file" box).
- A cooked (2048-byte) image is 354's rule, unchanged.
- An image opened through a track table (NRG, CCD with its `.ccd`) is not touched.
- A partial sector at the end of the file (fewer bytes than one sector) cannot hold a later volume and is
  not read.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the plain detection opens a file whose first sector carries the CD sync pattern (a raw
  start) and 353's missing-`.ccd` rule does not apply, the listing MUST be marked incomplete when the volume
  size at the opened layout's sector 16 cannot be read (no valid primary volume descriptor), or the file ends
  within that volume.
- **FR-002**: For such a file, the listing MUST stay complete when the file holds no more than 16 whole
  sectors (of the opened layout) past the volume.
- **FR-003**: For such a file with more than 16 whole sectors past the volume, the listing MUST be marked
  incomplete when more than 512 sectors lie past the volume; otherwise the user data of every whole sector
  past the volume (at the opened layout) MUST be read and the listing marked unless all of it is zero bytes
  and all of it could be read.
- **FR-004**: A marked listing MUST make a whole unpack fail so "Delete archive after unpacking" keeps the
  image (the existing mechanism of feature 328); no new window, message or UI string.
- **FR-005**: The behaviour of `.img` files whose `.ccd` is missing (353), of cooked images (354), and of
  images opened through a track table MUST NOT change.
- **FR-006**: The decision MUST be a pure rule in `src/common/salisotrack.h` with `saltests` checks.

### Key Entities

- **Raw image**: a disc image stored in 2352-byte (or another raw layout's) sectors, starting with the CD
  sync pattern; the listed volume's size is read from its primary volume descriptor.
- **Rest past the volume**: the whole sectors of the file after the listed volume's last sector.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All 10 raw rows that lost data before (R rows of the probe) keep the image after the change;
  0 FAIL rows in the probe.
- **SC-002**: All 8 one-session or no-data-tail rows (C rows) are still extracted and deleted, and 353's two
  `.img` rows unchanged.
- **SC-003**: The regression probes of 353 and 354 pass as before (16 / 0 and 28 / 0).
- **SC-004**: `saltests` passes with new checks for the rule; a mutant that never marks fails them.

## Assumptions

- Assumption (autonomous run): the zero-rest check of 354 is applied to raw images by the user data of each
  sector at the opened layout - raw sectors carry sync, header and error-correction bytes that are never all
  zero, so the cooked byte check cannot be reused; the item says "perhaps with 354's zero-rest check" and
  the conservative answer that loses no data and keeps the delete option useful for one-session `.bin`s is
  to check it (a zero tail holds neither a later volume, whose descriptors are not zero, nor data).
- Assumption (autonomous run): 353's `.img` rule (no zero check) is left unchanged - changing it would
  reverse a decided row of 353 (its R-REST17 of zero sectors is kept); the difference is recorded as a limit.
- Assumption (autonomous run): no real `.bin` / `.mdf` was available; the tail of a real one-session dump is
  reasoned from the CD format (a post-gap is stored as sectors of zero user data, a run-out as zero bytes) and
  checked with crafted images; a person step asks for real dumps.
- The images are crafted from 334's genisoimage seeds; the sessions themselves are still not read (only the
  first is listed).
