# Feature Specification: A cooked disc image is kept when it holds more than its listing shows

**Feature Branch**: `354-uniso-cooked-sessions`  
**Created**: 2026-10-31  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-a-cooked-multi-session-image-lists-one-session` - "ISO plug-in: a cooked multi-session image lists one session, then Unpack deletes it". From backlog item iso-plug-in-a-cooked-multi-session-image-lists-one-session.

## Background (measured at 64e207ca)

The ISO plug-in (`uniso`, on in the default build) opens a disc image of 2048-byte sectors (a "cooked"
`.iso` or `.img` - for example a `dd` copy of a multi-session disc) as a plain image: it lists the file
system whose volume descriptor is at sector 16 of the file - the first session. A later session past
that volume is not listed. A whole Unpack (Alt+F9) with "Delete archive after unpacking" then succeeds
and deletes the image, and the later session's files are lost. Feature 353 marks this case for raw
(2352-byte) `.img` files whose `.ccd` is missing; cooked images were left unchanged on purpose
(353's FR-003).

Measured with a new hidden-desktop probe `iso354_probe` (Debug build at 64e207ca; seeds by feature
334's `mkimg334.sh` - session 1 `s1.iso` of 176 sectors whose primary volume descriptor gives 176,
session 2 `s2.iso` addressed after it; cooked images by a new `img354.py`; xorriso images by a new
`mkxorriso354.sh`): 20 PASS / 8 FAIL.

- R-TWOISO, R-TWOIMG (s1 + s2 joined, named `.iso` / `.img`): only `a.txt` extracted, the image
  **deleted** - `b.txt` of session 2 lost. The defect.
- R-REST17 (17 sectors of data past the volume), R-ZERO513 (513 zero sectors), R-ZEROLATE (300 zero
  sectors whose last byte is not zero), R-SHORT (the file ends within the volume), R-BIGPVD (a volume
  size claiming more than the file), R-XESP (an appended partition past the volume): deleted.
- C-PLAIN, C-REST16, C-ZERO168, C-ZERO512, C-XDEV1, C-XMS: extracted and deleted - as wanted.

How common a rest past the ISO 9660 volume is (the item's *Notes*; measured in WSL with genisoimage
1.1.11 and xorriso 1.5.6; no real `.iso` exists on the measuring machine):

| Image | Sectors past the volume | Content of the rest |
|---|---|---|
| genisoimage default, `-pad`, `-udf`, El Torito | 0 | - (padding is inside the volume size) |
| xorriso `-as mkisofs` default, `-no-pad`, MBR, isohybrid GPT | 0 | - |
| xorriso native (`-dev`), one session | 168 | zero bytes only |
| xorriso native, two sessions in one file | 168 | zero bytes (sector 16 describes the newest session; both files listed) |
| xorriso `-append_partition` (an appended EFI partition, as Ubuntu ISOs since 20.10) | 1590 | the partition's data (not listed) |
| two sessions joined (the defect) | 176 | session 2 |

## Clarifications

### Session 2026-10-31

- Q: Should every cooked image with more than 16 sectors past its volume be kept (the item's rule as written), or may a rest that is provably empty still be deleted? → A: A rest of zero bytes only, read in full, is not marked - it holds no later volume (whose descriptors are never zero) and no data; any non-zero byte past the volume marks the listing (autonomous run: item - its *Notes* ask to measure how common a rest is before choosing the rule; the measurement found xorriso's native 168 zero sectors in every such image - and conservative: no case that holds data is deleted)
- Q: How much of a zero rest is read before the plug-in gives up and keeps the image? → A: At most 512 sectors (1 MiB); a longer rest is marked without reading further, so opening an image never reads more than 1 MiB extra (autonomous run: conservative - a check that does not see everything fails closed; 512 covers xorriso's 168 and isohybrid's alignment to 1 MiB)
- Q: Which images does the rule apply to? → A: Only cooked images of the plain detection: no CD sync pattern at the start, 2048-byte sectors from offset 0, recognised by the descriptor at sector 16 - whatever the extension (`.iso`, an `.img` without its `.ccd`, ...); images found by the other plain checks (NRG header offset, 2336, NCD, PDI, ECDC, CIF, C2D, Xbox, MDF, HFS, APFS) and every image with a track table are unchanged (autonomous run: item - "a cooked `.iso` or `.img`" - and conservative for the cases it does not name)
- Q: What about a cooked image whose sector 16 holds no ISO 9660 descriptor (UDF only)? → A: Unchanged; a limit recorded with an Inbox item (autonomous run: item - "a plain one-volume `.iso` unpacks and is deleted as today"; its size would need the UDF descriptors, beyond the item)
- Q: What when sector 16 holds an ISO 9660 descriptor whose volume size cannot be read, the file ends within the volume, or the rest cannot be read? → A: The listing is marked incomplete, as feature 353 does for raw images (autonomous run: rule - CLAUDE.md "a safe to delete? check fails closed")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A cooked multi-session image is not deleted after a partial unpack (Priority: P1)

A user unpacks a whole cooked disc image (`.iso` or `.img`) with "Delete archive after unpacking"
checked. The image holds a second session past the first session's volume. The plug-in extracts what
it lists (the first session's files), and the unpack is reported as not complete, so the image is kept
and the second session's data is not lost.

**Why this priority**: losing the later session's files with the image is the item's main point.

**Independent Test**: probe rows R-TWOISO, R-TWOIMG: `a.txt` extracted, the image kept.

**Acceptance Scenarios**:

1. **Given** a cooked two-session `.iso`, **When** a whole unpack with "Delete archive after
   unpacking" runs, **Then** the first session's files are extracted and the image is kept, with no
   new message.
2. **Given** the same image named `.img` without a `.ccd`, **When** the same unpack runs, **Then** the
   image is kept; only the existing "Missing .CCD file" boxes are shown.
3. **Given** a cooked image whose rest past the volume holds data the listing does not cover (17 or
   more sectors past the volume with a non-zero byte, for example an appended partition), **When** the
   same unpack runs, **Then** the image is kept.

---

### User Story 2 - A plain one-volume image still unpacks and is deleted (Priority: P2)

A user unpacks a cooked image that holds a single volume: the file equals the volume, has a few
sectors more, or has a rest of zero bytes only (as xorriso's native mode writes it). The unpack works
as before: the files are extracted and, with "Delete archive after unpacking", the image is deleted.

**Why this priority**: the change must not turn every `.iso` into one that is kept (the item's
*Notes*: a visible change).

**Independent Test**: probe rows C-PLAIN, C-REST16, C-ZERO168, C-ZERO512, C-XDEV1, C-XMS: files
extracted, the image deleted.

**Acceptance Scenarios**:

1. **Given** a cooked image whose file equals its volume, or holds up to 16 sectors more, **When** a
   whole unpack with "Delete archive after unpacking" runs, **Then** the files are extracted and the
   image is deleted.
2. **Given** a cooked image whose rest past the volume is zero bytes only and no longer than 512
   sectors, **When** the same unpack runs, **Then** the image is deleted.

---

### User Story 3 - A rest that cannot be checked, or a volume size that cannot be trusted, keeps the image (Priority: P3)

When the plug-in cannot tell that the rest past the volume is empty - the rest of zero bytes is longer
than it reads, or the file ends within the volume its descriptor claims (a damaged or crafted size) -
the listing is treated as incomplete and a whole unpack keeps the image.

**Why this priority**: a "safe to delete?" check fails closed (CLAUDE.md *Never lose the user's data*).

**Independent Test**: probe rows R-ZERO513, R-ZEROLATE, R-SHORT, R-BIGPVD: the image kept.

**Acceptance Scenarios**:

1. **Given** a cooked image with more than 512 zero sectors past its volume, **When** a whole unpack
   with "Delete archive after unpacking" runs, **Then** the image is kept.
2. **Given** a cooked image whose rest past the volume is zero bytes except a byte near its end,
   **When** the same unpack runs, **Then** the image is kept.
3. **Given** a cooked image whose volume descriptor gives more sectors than the file holds, **When** the
   same unpack runs, **Then** the image is kept.

### Edge Cases

- A cooked image with no ISO 9660 volume descriptor at sector 16 (UDF only): unchanged (limit; see
  Assumptions).
- An ISO 9660 descriptor at sector 16 whose volume size cannot be read (the two copies differ, a block
  size other than 2048, not a primary descriptor): the listing is marked incomplete.
- A raw image (CD sync pattern at the start) without its `.ccd`: feature 353's rule, unchanged.
- Images with a track table (NRG, CCD with `.ccd`, ...) and the other plain formats (NCD, PDI, MDF, Xbox,
  HFS, APFS, ...): unchanged.
- Listing and single-file extraction: unchanged; only whether a whole unpack counts as complete.
- A file whose size cannot be read, or a read of the rest that fails: the listing is marked incomplete.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the plug-in opens a cooked image (no CD sync pattern at its start, 2048-byte
  sectors from the start of the file, recognised by its volume descriptor at sector 16) and sector 16
  holds an ISO 9660 descriptor, it MUST compare the volume size the primary volume descriptor gives
  with the whole sectors the file holds.
- **FR-002**: The listing MUST be marked incomplete (a whole unpack fails, "Delete archive after
  unpacking" keeps the image) when the file holds more than 16 sectors past the volume and the rest
  past the volume holds any non-zero byte.
- **FR-003**: A rest past the volume of zero bytes only MUST NOT mark the listing when it is at most
  512 sectors long; a longer rest MUST mark it (not all of it is checked).
- **FR-004**: The listing MUST be marked incomplete when the file holds fewer whole sectors than the
  volume size, when the descriptor's volume size cannot be read, or when the rest cannot be read.
- **FR-005**: A cooked image whose file holds at most 16 sectors past its volume MUST unpack and be
  deleted as before.
- **FR-006**: No UI string, message, listing or extraction changes; the raw-image rule of feature 353
  and every image with a track table stay as they are.

### Key Entities

- **Listed volume**: the ISO 9660 volume whose primary volume descriptor is at sector 16 of the file;
  its size in sectors.
- **Rest**: the sectors of the file past the listed volume.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A whole unpack with "Delete archive after unpacking" of a cooked two-session image keeps
  the image (`.iso` and `.img`): probe rows R-TWOISO, R-TWOIMG PASS (both FAIL before).
- **SC-002**: Every one-volume cooked image of the probe whose rest is at most 16 sectors, or zero bytes
  up to 512 sectors, is extracted and deleted as before: rows C-PLAIN, C-REST16, C-ZERO168, C-ZERO512,
  C-XDEV1, C-XMS PASS.
- **SC-003**: Every image whose rest cannot be shown empty is kept: rows R-REST17, R-ZERO513,
  R-ZEROLATE, R-SHORT, R-BIGPVD, R-XESP PASS.
- **SC-004**: The probes of features 353, 352 and 334 show no regression; the rule is a tested pure
  decision (`saltests` 0 failed).

## Assumptions

- Assumption (autonomous run): the rest is read only when it is more than 16 sectors long, and at most
  512 sectors (1 MiB - isohybrid's alignment; xorriso's native padding is 168) are read; opening an
  image never reads more than that extra.
- Assumption (autonomous run): a rest of zero bytes can hold neither a later volume (its descriptors are
  not zero) nor data, so not marking it loses nothing; this narrows the item's rule ("more than 16
  sectors") by the measurement its *Notes* ask for, and keeps xorriso-native images deleted as today.
- Assumption (autonomous run): a cooked image without an ISO 9660 descriptor at sector 16 (UDF only)
  stays unchanged - the item's *Expected* keeps a plain one-volume `.iso` as today and its size would
  need the UDF descriptors; recorded as a limit and an Inbox item.
- Assumption (autonomous run): an image kept this way gets no new message (as features 334 and 353);
  no UI string changes, so no translation refresh.
- Assumption (autonomous run): images with an appended partition (for example Ubuntu installation ISOs)
  are now kept after a whole unpack - the partition's data is not listed, so deleting the image would
  lose it; recorded in the changelog as a visible change.
