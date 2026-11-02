# Feature Specification: An ISO 9660 folder whose length cannot be a directory of the image is a folder that cannot be read

**Feature Branch**: `403-uniso-dir-length`  
**Created**: 2026-11-02  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-an-iso-9660-folder-length-of-2-gib-or-more-shows` - "ISO plug-in: an ISO 9660 folder length of 2 GiB or more shows a stuck memory box". From backlog item iso-plug-in-an-iso-9660-folder-length-of-2-gib-or-more-shows.

## Background (traced and measured at 618dae27)

The ISO plug-in (`uniso`, on in the default build) reads each folder of an ISO 9660 volume (also its
Joliet variant and the ISO 9660 part of a UDF hybrid - all go through one folder walk) by allocating a
buffer of the folder record's data length and reading the directory into it. The length comes from the
image as a 32-bit unsigned value but is held as a signed 32-bit number: a length of 2 GiB or more
becomes negative, and the allocation asks for 18,446,744,073,709,549,568 bytes. The core's memory box
("Insufficient memory to allocate ... bytes", Abort / Retry / Ignore) appears and the listing waits for
it. Abort ends the program; Ignore (then Yes) makes the allocation fail with an exception nothing
catches - the program closes with a bug report. A damaged or crafted image can thus end the program.

Measured on the Debug build at 618dae27 with a new probe (`iso403_probe.ps1`, hidden desktop, images
written from scratch by `img403.py`; Unpack of the whole image with "Delete archive after unpacking";
the memory box answered Ignore): PASS 6 / FAIL 6.

| Row | Image | Before |
|-----|-------|--------|
| IS-NEG | root: A (block 21, length 0xFFFFF800), TOP.TXT, ZLAST/Z.TXT | memory box; Ignore -> the program closes with a bug report; nothing extracted, image kept |
| IS-NEG2 | A (21, 2048; A1.TXT), B (21, 0xFFFFF800), TOP.TXT, ZLAST/Z.TXT (401 review's `isoneg`) | the same |
| IS-MIN | A (21, 0x80000000), TOP.TXT, ZLAST/Z.TXT | the same |
| IS-HUGE | A (21, 0x7FFFF800 - positive, near 2 GiB) | PASS - the 2 GiB buffer is allocated, the read fails at the image's end: one read-error box |
| IS-PAST | A at the image's last sector, 3 sectors claimed | PASS - one read-error box (control) |
| IS-EDGE | A of 3 sectors ending exactly at the image's last sector (nothing damaged) | PASS - listed whole, no window, image deleted (control) |

Checked from the item's *Notes*: the Joliet and UDF-hybrid paths share the same walk (one site); file
extraction reads files sector by sector and never allocates by a file's length.

## Clarifications

### Session 2026-11-02

- Q: What is the "sane limit" above which a folder length is refused before anything is allocated?
  → A: 256 MiB (268,435,456 bytes). A real directory of that size would hold hundreds of thousands of
  entries in one folder (about 6-14 records per 2048-byte sector); any length above it is treated as a
  folder that cannot be read (autonomous run: conservative - far above any real directory, and an
  allocation of that size does not fail on a 64-bit system)
- Q: How is "past the end of the image" decided before the buffer is allocated? → A: for a folder of
  more than one sector, its last sector is read first; when that read fails the folder is a folder that
  cannot be read, nothing is allocated (autonomous run: conservative - uses the same read path as the
  listing, works for every image container; a one-sector folder is read as before)
- Q: Review 1 found nested readable folders of 256 MiB each still adding 256 MiB per level - is the limit
  per folder or for all buffers held at once? → A: for all buffers the walk holds at once (count walks
  included) - the item's *Expected* says no way to end the program from a damaged image (autonomous run:
  item)
- Q: Is any new message shown? → A: no - the existing "Error reading directory structure at sector #N.
  Incomplete content of ISO image." box, once per walk (features 330 / 400); no new UI string
  (autonomous run: item)
- Q: When the volume's root folder itself has a length the rule refuses, does the image still open?
  → A: yes, as for a root whose read fails today - the read-error box, an empty listing marked
  incomplete (a whole Unpack keeps the image) (autonomous run: conservative - existing behaviour of an
  unreadable root)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged folder length never offers to end the program (Priority: P1)

A user opens or unpacks a disc image one of whose folders claims a length of 2 GiB or more. Instead of
the memory box that can only end the program, the plug-in treats that folder as one it cannot read:
one "Error reading directory structure" box, the listing marked incomplete, every other folder listed
and extracted, the image kept by a whole Unpack with "Delete archive after unpacking".

**Why this priority**: this is the item - a damaged image could end the program.

**Independent Test**: probe rows IS-NEG, IS-NEG2, IS-MIN.

**Acceptance Scenarios**:

1. **Given** an ISO 9660 image whose root holds folder A (length 0xFFFFF800), TOP.TXT and folder ZLAST
   (Z.TXT), **When** the user unpacks the whole image with "Delete archive after unpacking", **Then**
   top.txt and zlast/z.txt are extracted, exactly one window is shown and it is the read-error box, and
   the image is kept.
2. **Given** 401 review's image (A at block 21 with 2048 bytes holding A1.TXT, B at 21 with
   0xFFFFF800), **When** unpacked the same way, **Then** a/a1.txt, top.txt, zlast/z.txt are extracted,
   one read-error box, the image kept.
3. **Given** a folder length of exactly 0x80000000, **When** unpacked, **Then** as scenario 1.

---

### User Story 2 - An implausibly large or past-the-end folder is refused before memory is taken (Priority: P2)

A folder length below 2 GiB that is still larger than any real directory, or that runs past the end of
the image, is treated the same way without first allocating a buffer of that size.

**Why this priority**: the *Expected* of the item names these cases; today they already end in the
read-error box but after allocating up to 2 GiB (which itself can fail with the memory box on a busy
system).

**Independent Test**: probe rows IS-HUGE, IS-PAST; `saltests` checks of the length rule.

**Acceptance Scenarios**:

1. **Given** folder A with length 0x7FFFF800, **When** unpacked, **Then** top.txt, zlast/z.txt, one
   read-error box, the image kept.
2. **Given** folder A at the image's last sector claiming 3 sectors, **When** unpacked, **Then** the same.

---

### User Story 3 - Valid folders are listed as before (Priority: P1)

Every folder that is a real directory of the image - including a multi-sector folder ending exactly at
the image's last sector - is listed and extracted whole, with no window.

**Why this priority**: no regression for valid images.

**Independent Test**: probe row IS-EDGE; regression probes of features 328, 400, 401, 402.

**Acceptance Scenarios**:

1. **Given** folder A of 3 sectors ending at the image's last sector, **When** unpacked with "Delete
   archive after unpacking", **Then** a/a1.txt, a/a3.txt, top.txt, zlast/z.txt are extracted, no window,
   and the image is deleted.

### Edge Cases

- Nested folders each within the limit whose buffers together would pass it (review 1, IS-DEEP): the
  deeper folder is a folder that cannot be read; a sibling after it is read again.
- Length 0: unchanged (330: a silent folder that cannot be read; the listing marked).
- Length exactly the limit (256 MiB): allowed by the rule; one byte more: refused.
- A folder refused for its length that is met again with the same length in the same walk: 328 / 401's
  visited rule applies as before (listed empty).
- The quiet walks (fit check, count walks) refuse the folder silently; the listing walk shows the box
  once (400).
- The root folder's own length: the same rule (the root is read through the same walk); a refused root
  behaves as an unreadable root today - the box, the image opens with an empty listing marked
  incomplete.
- A last-sector check of a folder whose sectors would run past sector 0xFFFFFFFF: refused.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A folder record whose data length is 0x80000000 or more MUST be treated as a folder that
  cannot be read: no memory box, no buffer of that size.
- **FR-002**: A folder record whose data length is larger than the limit (256 MiB) MUST be treated the
  same way.
- **FR-003**: A folder of more than one sector whose last sector cannot be read MUST be treated the same
  way before its buffer is allocated.
- **FR-003a**: The directory buffers the walk holds at once (a folder's while the folders below it are
  walked, count walks included) MUST stay within the limit (256 MiB) together; a folder whose buffer
  would pass it MUST be treated the same way (review 1: nested readable folders of 256 MiB each took
  256 MiB more per level).
- **FR-004**: "Treated as a folder that cannot be read" MUST mean features 330 / 400's behaviour: the
  existing read-error box at most once per walk (none in a quiet walk), the listing marked incomplete,
  later folders still walked, a whole Unpack with "Delete archive after unpacking" keeps the image.
- **FR-005**: The length rule MUST be a pure, unit-tested rule in a header under `src/common/` (64-bit
  arithmetic, no wrap).
- **FR-006**: Every folder with a length from 1 byte to the limit whose sectors are readable MUST be
  read as before.
- **FR-007**: No new UI string, no change to the plug-in interface.

### Key Entities

- **Folder record**: start block and data length taken from the image.
- **Walk**: one pass over the volume's folders (the listing walk, the quiet fit and count walks), with
  its box-once state (400) and visited set (328 / 401).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `iso403_probe` passes 16 / 16 rows (before: 6 / 6 FAIL rows IS-NEG, IS-NEG2, IS-MIN
  with the memory box and a program end; review 1 added IS-DEEP and IS-OVER).
- **SC-002**: Regression probes of 328, 400, 401, 402 pass as at their closing.
- **SC-003**: `saltests` passes with new checks of the length rule; a mutant of the rule fails them.
- **SC-004**: No image of the probe can end the program or show the memory box.

## Assumptions

- Assumption (autonomous run): the limit is 256 MiB; a real ISO 9660 directory is far smaller.
- Assumption (autonomous run): the Xbox walk's own large-size allocation is a separate Inbox item
  (`iso-plug-in-an-xbox-folder-entry-claiming-a-huge-size`) and is not changed here.
- Assumption (autonomous run): the unchecked `new` returning NULL tests in the plug-in (the core's
  allocator throws on Ignore) are outside this item.
