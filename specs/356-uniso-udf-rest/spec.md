# Feature Specification: A UDF-only disc image is kept when it holds more than its listing shows

**Feature Branch**: `356-uniso-udf-rest`  
**Created**: 2026-10-31  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-a-udf-only-cooked-image-with-more-past-its` - "ISO plug-in: a UDF-only cooked image with more past its volume is still deleted by Unpack". From backlog item iso-plug-in-a-udf-only-cooked-image-with-more-past-its.

## Background (measured at 7afab447)

The ISO plug-in (`uniso`, on in the default build) opens a disc image of 2048-byte sectors (a "cooked"
image) whose sector 16 holds the UDF volume recognition sequence (`BEA01`) and no ISO 9660 descriptor -
a UDF-only image, as Windows' own image writer (IMAPI2FS), `mkudffs` and Blu-ray authoring write them -
and lists it from its UDF descriptors. Feature 354 keeps a cooked image after a whole Unpack with
"Delete archive after unpacking" when the file holds more than its ISO 9660 volume, but it needs the
volume's size from the ISO 9660 primary descriptor at sector 16: for a UDF-only image the rule does not
apply and the listing is always kept as complete. When such a file holds a second UDF volume joined
past the first (or any other data past the volume), the whole unpack succeeds and deletes the image
with the data the listing does not cover.

Where a UDF volume ends (measured on real images; `udfmeasure.py` of this feature):

| Image | Descriptors end (anchor at 256, both descriptor sequences, partition) | File | Past the descriptors |
|---|---|---|---|
| IMAPI2FS UDF 1.02 / 1.50 / 2.00 / 2.01 (a.txt) | 310 | 576 sectors | anchors of the volume itself, one per sector (each carries its own location and the same descriptor extents), the last at the file's last sector |
| IMAPI2FS UDF 2.50 | 464 | 736 | the same |
| mkudffs 2.3 hd / dvd / dvdrw / cdrw / cd | 1999 / 3856 / 3872 | 2000 / 4000 | zero bytes and the volume's own anchors at the file's last sector and 256 before it |
| mkudffs dvdr / bdr / cdr (VAT, open) | 4000 (the partition claims the whole medium) | 288 - 320 | - the file ends at the virtual allocation table (VAT) the listing reads, an (extended) file entry at the last sector |
| mkudffs cdr closed (VAT) | 4000 | 514 | the volume's own anchor at the file's last sector - 256 |
| mkudffs hd, 512-byte blocks | no anchor at 2048-byte sector 256 | | |

So the descriptors alone never give the end of a plain image: the volume's own closing anchor (at the
last sector, or 256 before it) and its own anchors in the rest must count as part of the volume, and an
open VAT volume ends at its VAT.

## Clarifications

### Session 2026-10-31

- Q: Which sectors count as the end of a UDF volume? → A: The volume ends at the file's end when the file's last whole sector, or the sector 256 before it, is an anchor of this volume (a valid anchor descriptor recording its own location and naming the same main and reserve descriptor sequences as the anchor at sector 256), or - for a volume with a virtual partition (VAT) - when the file's last whole sector is a file entry of that volume (its recorded location plus the partition's start is that sector). Otherwise the volume ends after the last of: the anchor at sector 256, the main and the reserve descriptor sequence, and the partitions the main sequence describes (autonomous run: item - its *Notes* name these and ask which marks the end without false positives; the measurement above chose them)
- Q: What counts as an empty rest past a UDF volume? → A: Every sector of it is zero bytes only or an anchor of this volume; anything else marks the listing (autonomous run: item - "whose rest is not zero bytes only marks", narrowed by the measurement: IMAPI2FS fills the rest with the volume's own anchors, which hold neither data nor another volume)
- Q: Which limits apply? → A: Feature 354's: at most 16 sectors past the volume keep the listing without reading; a rest longer than 512 sectors is not read and marks the listing (autonomous run: item - "by the same rule as feature 354 (SAL_ISO_LATER_VOLUME_SECTOR, SAL_ISO_ZERO_REST_SECTORS)")
- Q: What when the anchor at sector 256 is missing or invalid, its descriptor sequence names no partition, or the file ends within the volume? → A: The listing is marked incomplete (the size cannot be read or trusted), as features 353 - 355 do (autonomous run: rule - CLAUDE.md "a safe to delete? check fails closed")
- Q: Which images does the rule apply to? → A: Only cooked images of the plain detection (feature 354's `cookedIso`) whose sector 16 holds no ISO 9660 primary descriptor; images with an ISO 9660 descriptor keep feature 354's rule, raw images feature 353's / 355's, images with a track table and the other plain formats are unchanged (autonomous run: item, and conservative for what it does not name)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A UDF-only image holding a second volume is not deleted after a partial unpack (Priority: P1)

A user unpacks a whole UDF-only disc image (`.iso` or `.img`) with "Delete archive after unpacking"
checked. The file holds a second UDF volume (or other data) past the volume the plug-in lists. The
plug-in extracts what it lists, the unpack is treated as not complete, and the image is kept.

**Why this priority**: losing the data past the listed volume with the image is the item's main point.

**Independent Test**: probe rows R-TWO, R-TWOIMG, R-TWOABS, R-REST17: `a.txt` extracted, the image kept.

**Acceptance Scenarios**:

1. **Given** two UDF-only images joined in one `.iso`, **When** a whole unpack with "Delete archive
   after unpacking" runs, **Then** the first volume's files are extracted and the image is kept, with no
   new message.
2. **Given** the same file named `.img` without a `.ccd`, **When** the same unpack runs, **Then** the
   image is kept; only the existing "Missing .CCD file" boxes are shown.
3. **Given** a UDF-only image with more than 16 sectors past its volume that are not zero bytes or its
   own anchors, **When** the same unpack runs, **Then** the image is kept.

---

### User Story 2 - A plain one-volume UDF image still unpacks and is deleted (Priority: P2)

A user unpacks a UDF-only image that holds one volume - as IMAPI2FS, `mkudffs` (also with a VAT) or a
Blu-ray image writes it, or followed by zero bytes only. The unpack works as before: the files are
extracted and the image is deleted.

**Why this priority**: the item's *Expected*: a plain one-volume UDF image unpacks and is deleted as
today.

**Independent Test**: probe rows C-PLAIN, C-U250, C-REST16, C-ZERO100, C-ZERO512, C-ANCHOR600, C-MK*:
extracted, deleted.

**Acceptance Scenarios**:

1. **Given** a UDF-only image whose file ends with its own closing anchor (at the last sector or 256
   before it), **When** a whole unpack with "Delete archive after unpacking" runs, **Then** the files
   are extracted and the image is deleted.
2. **Given** an open VAT image whose file ends at its VAT, **When** the same unpack runs, **Then** the
   image is deleted.
3. **Given** a UDF-only image whose rest past its descriptors is at most 16 sectors, or at most 512
   sectors of zero bytes and its own anchors, **When** the same unpack runs, **Then** the image is
   deleted.

---

### User Story 3 - A volume end that cannot be read or trusted keeps the image (Priority: P3)

When the plug-in cannot tell where the UDF volume ends - no anchor at sector 256, no partition named,
the file ends within the volume, or a rest longer than it reads - the listing is treated as incomplete
and a whole unpack keeps the image.

**Why this priority**: a "safe to delete?" check fails closed (CLAUDE.md *Never lose the user's data*).

**Independent Test**: probe rows R-ZERO513, R-ZEROLATE, R-SHORT, R-NOANCHOR, R-MKHD512: the image kept.

**Acceptance Scenarios**:

1. **Given** a UDF-only image with more than 512 sectors past its descriptors and no closing anchor at
   its end, **When** a whole unpack runs, **Then** the image is kept.
2. **Given** a UDF-only image without a valid anchor at sector 256, **When** a whole unpack runs,
   **Then** the image is kept.
3. **Given** a UDF-only image that ends within its descriptors, **When** a whole unpack runs, **Then**
   the image is kept.

### Edge Cases

- A later volume whose closing anchor sits at the file's last sector but names its own descriptor
  sequences (a later session addressed as on a disc): not this volume's anchor - the rest is checked.
- A VAT volume followed by other data: its last sector is not its own file entry - the descriptors'
  end is used (the partition claims the whole medium: more than the file - marked).
- A UDF image with blocks other than 2048 bytes: no anchor at 2048-byte sector 256 - marked.
- A cooked image with an ISO 9660 descriptor at sector 16 (a UDF bridge image): feature 354's rule,
  unchanged.
- Listing and single-file extraction: unchanged; only whether a whole unpack counts as complete.
- A read that fails, or a file whose size cannot be read: the listing is marked incomplete.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the plug-in opens a cooked image (feature 354's plain cooked layout) whose sector 16
  holds no ISO 9660 primary descriptor, it MUST determine the end of the UDF volume from the anchor at
  sector 256, the descriptor sequences it names, the partitions the main sequence describes, the
  volume's closing anchor and, for a VAT volume, its VAT at the file's end.
- **FR-002**: The listing MUST be marked incomplete when the file holds more than 16 sectors past the
  volume's end and any sector of the rest is neither zero bytes only nor an anchor of this volume.
- **FR-003**: A rest of zero bytes and the volume's own anchors MUST NOT mark the listing when it is at
  most 512 sectors long; a longer rest MUST mark it, unless the file ends with the volume's closing
  anchor or its VAT.
- **FR-004**: The listing MUST be marked incomplete when the anchor at sector 256 is missing or not
  valid, when the main descriptor sequence names no partition, when the file holds fewer whole sectors
  than the volume's end, or when a sector that must be read cannot be read.
- **FR-005**: A UDF-only image whose file ends with its own closing anchor, or (VAT) with its own file
  entry, or holds at most 16 sectors past its volume's end MUST unpack and be deleted as before.
- **FR-006**: No UI string, message, listing or extraction changes; images with an ISO 9660 descriptor
  at sector 16, raw images, images with a track table and the other plain formats stay as they are.

### Key Entities

- **Anchor**: the UDF anchor volume descriptor pointer - at sector 256, and (closed media) at the
  volume's last sector and 256 before it; it names the main and the reserve descriptor sequence.
- **Volume end**: the sector after the volume's last sector, by FR-001.
- **Rest**: the sectors of the file past the volume end.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A whole unpack with "Delete archive after unpacking" of two joined UDF-only images keeps
  the image (`.iso` and `.img`): probe rows R-TWO, R-TWOIMG, R-TWOABS PASS (deleted before).
- **SC-002**: Every one-volume UDF-only image of the probe (IMAPI2FS 1.02 and 2.50, mkudffs hd / dvd /
  cdrw / VAT open and closed, zero rests up to 512 sectors, a closing anchor past a long zero rest) is
  extracted and deleted as before.
- **SC-003**: Every UDF-only image whose rest cannot be shown empty or whose end cannot be read is kept:
  rows R-REST17, R-ZERO513, R-ZEROLATE, R-SHORT, R-NOANCHOR PASS.
- **SC-004**: The probes of features 354 and 355 show no regression; the rule is a tested pure decision
  (`saltests` 0 failed).

## Assumptions

- Assumption (autonomous run): at most 512 sectors (1 MiB) of the rest are read, as feature 354; with a
  closing anchor or VAT at the file's end nothing past the descriptors is read beyond those sectors.
- Assumption (autonomous run): an anchor descriptor is recognised by its tag (identifier 2, its recorded
  location equal to the sector it is in, a correct tag checksum); the descriptor CRC is not checked
  (as the plug-in's UDF reader).
- Assumption (autonomous run): UDF images with 512-byte (or other non-2048) blocks are now kept after a
  whole unpack - the plug-in's UDF reader reads 2048-byte blocks only and its listing of them is not
  trusted.
- Assumption (autonomous run): a crafted image whose descriptors claim a size close to the file, or a
  joined volume whose descriptors copy the first one's, still hides what lies past it (as 353 - 355).
- Assumption (autonomous run): an image kept this way gets no new message (as features 353 - 355); no UI
  string changes, so no translation refresh.
- Assumption (autonomous run): the sessions of a UDF multi-session image are still not read; a VAT
  volume's listing already reads its newest VAT at the file's end.
