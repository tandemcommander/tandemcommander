# Feature Specification: A multi-session image opened through another plain layout is kept after a partial unpack

**Feature Branch**: `357-uniso-other-layouts`  
**Created**: 2026-10-31  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-a-multi-session-image-opened-through-another` - "ISO plug-in: a multi-session
image opened through another plain layout lists one session, then Unpack deletes it". From backlog item iso-plug-in-a-multi-session-image-opened-through-another.

## Background (measured at 8bf3ebd4)

The ISO plug-in opens an image without a table of sessions (no `.cue`, `.ccd`, Nero footer) by its "plain
detection": it tries a fixed series of layouts and lists the volume whose descriptor it finds at that layout's
sector 16 - one session. Features 353 (raw `.img` without `.ccd`), 354 (2048-byte sectors from offset 0) and 355
(a raw file with the CD sync pattern at offset 0) mark the listing incomplete when the file holds room for a later
session past the listed volume and that room is not empty, so a whole Unpack with "Delete archive after
unpacking" fails and keeps the image. The other layouts of the plain detection reach none of those rules.

Measured with crafted images (334's genisoimage seeds: session 1 = `a.txt` "A1", 176 sectors; session 2 =
`b.txt` "B2") written in ten layouts the detection reaches without a sync pattern at offset 0, each checked to
open through the intended layout:

| Layout | Stored sector | Before: two sessions | Before: one session |
|---|---|---|---|
| Easy CD Creator (sync and header zeroed) | 2352, user data at 24 | deleted | deleted (correct) |
| NRG offset 0x4B000 | 2048 | deleted | deleted (correct) |
| 2336-byte Mode 2 | 2336, user data at 8 | deleted | deleted (correct) |
| NCD offset 0x16E4E | 2048 | deleted | deleted (correct) |
| PDI offset 0x130 | 2048 | deleted | deleted (correct) |
| CIF (RIFF prefix) | 2056, user data at 8 | deleted | deleted (correct) |
| WinOnCD C2D offset 0x20000 | 2048 | deleted | deleted (correct) |
| WinOnCD C2D offset 0x76220 Mode 2 | 2352, user data at 24 | deleted | deleted (correct) |
| Roxio offset 0x120 | 2048 | deleted | (a file this short never opens) |
| CIF 2332 | 2332, user data at 8 | deleted | deleted (correct) |

Probe `iso357_probe` before: 44 PASS / 16 FAIL - every two-session row and the ECDC / NRG rows with 17 non-zero
sectors, 513 zero sectors or a file shorter than its volume deleted the image. The Xbox, HFS and APFS checks
open file systems without CD sessions and without an ISO 9660 descriptor at sector 16; the MDF check needs the
sync pattern at offset 0 and is already 355's.

## Clarifications

### Session 2026-10-31

- Q: Which layouts does the rule cover? → A: the eight CD layouts of the plain detection reached without a sync
  pattern at offset 0 - NRG offset, 2336, NCD, PDI, Easy CD Creator, CIF, C2D (all three variants), CIF 2332;
  not Xbox, HFS, APFS (no CD sessions; 355's rule would mark every such image because it has no ISO 9660 size)
  (autonomous run: item - its *Notes* ask to measure which layouts can carry a later session at all)
- Q: Which rule decides? → A: 355's `SalIsoRawRestDecision` at the opened layout, unchanged (keep for at most
  16 whole sectors past the volume, mark when the size is unknown, the file ends within the volume or more than
  512 sectors lie past it, else read the user data of every sector past the volume and mark unless all zero)
  (autonomous run: item - *Expected*)
- Q: A UDF-only volume opened at the NRG offset (that check also accepts `BEA01`)? → A: marked, as 355 marks a
  raw image whose size is unknown (fails closed) (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A two-session image in another layout is not deleted after a partial unpack (Priority: P1)

A user unpacks a whole disc image written by Easy CD Creator, WinOnCD, Roxio, NTI, Nero (offset image) or
another of the old layouts the plug-in recognises, with "Delete archive after unpacking". The image holds a
second session the listing does not show. Today the first session is extracted and the image is deleted - the
second session's files are lost.

**Why this priority**: it is the item's data loss.

**Independent Test**: two-session images of every covered layout, whole unpack with the option on - the image
must remain.

**Acceptance Scenarios**:

1. **Given** a two-session image in any covered layout, **When** the user unpacks it whole with "Delete archive
   after unpacking", **Then** the first session's files are extracted and the image is kept.
2. **Given** an image of a covered layout with 17 sectors of non-zero data past its volume, **When** unpacked the
   same way, **Then** it is kept.
3. **Given** an image of a covered layout with more than 512 sectors past its volume, or a file that ends within
   its volume, **When** unpacked the same way, **Then** it is kept.

### User Story 2 - A one-session image in those layouts still unpacks and is deleted (Priority: P2)

**Why this priority**: the fix must not keep every image of those layouts.

**Independent Test**: one-session images of every covered layout, and images followed by at most 16 sectors or
by up to 512 sectors of zero user data, are deleted after a whole unpack.

**Acceptance Scenarios**:

1. **Given** a one-session image of a covered layout, **When** unpacked whole with the option, **Then** its files
   are extracted and the image is deleted, without a window.
2. **Given** such an image followed by 16 sectors of data, or by 150 sectors of zero user data, **Then** it is
   deleted.

### Edge Cases

- A raw file (sync at offset 0) and a cooked file from offset 0 keep 355's and 354's rules unchanged; an `.img`
  without its `.ccd` keeps 353's.
- Xbox, HFS and APFS images keep today's behaviour.
- A Roxio image shorter than 0x7F53E bytes is not opened at all (an older limit; nothing is extracted or deleted).
- The sync, header and error-correction bytes of a stored sector are not read; only the user data is.
- A partial sector at the end of the file is not counted (it cannot hold a later volume).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the plain detection opened a file without the CD sync pattern at offset 0 through the NRG
  offset, 2336, NCD, PDI, Easy CD Creator, CIF, C2D or CIF 2332 layout, the plug-in MUST apply 355's rule of the
  rest past the listed volume, at the opened layout, and mark the listing incomplete when it says so.
- **FR-002**: A marked listing MUST make a whole unpack fail, so "Delete archive after unpacking" keeps the image
  (the existing mechanism of 328 / 338).
- **FR-003**: Images opened through the cooked layout from offset 0, with a raw start, through Xbox, HFS or APFS,
  and `.img` files without `.ccd`, MUST behave as before.
- **FR-004**: The decision which rule applies to which layout MUST be a pure function with unit checks.
- **FR-005**: No UI string, dialog or window is added.

### Key Entities

- **Plain layout**: the check of the plain detection that opened the file (offset of sector 0, stored sector size,
  user-data offset).
- **Rest past the volume**: the whole stored sectors of the file past the volume size of the descriptor at the
  layout's sector 16.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Every two-session row of the probe (10 layouts) and the ECDC / NRG rows with 17 non-zero sectors,
  513 zero sectors and a short file keep the image: 16 FAIL rows before -> 0 after.
- **SC-002**: Every one-session / short-tail / zero-tail row of the probe (14 rows) still deletes the image.
- **SC-003**: The probes of 353, 354, 355 and 356 pass unchanged; the unit checks pass with 0 failed.

## Assumptions

- Assumption (autonomous run): crafted images only - no real ECDC, CIF, C2D, NCD or PDI image is on the machine;
  a real image of those formats with trailing non-zero metadata past its volume would now be kept (fails closed,
  nothing is lost).
- Assumption (autonomous run): the sessions themselves are still not read; only the first is listed (as 353-355).
