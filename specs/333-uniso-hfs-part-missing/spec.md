# Feature Specification: A hybrid disc image whose HFS+ part does not open is kept by Unpack with "Delete archive after unpacking"

**Feature Branch**: `333-uniso-hfs-part-missing`  
**Created**: 2026-10-24  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-an-hfs-part-of-a-hybrid-that-does-not-open-is` - "ISO plug-in: an HFS+ part of a hybrid that does not open is dropped without a mark".

## Background (traced and measured at e9f777da)

The ISO plug-in (`uniso`, on in the default build) lists a hybrid disc image (ISO 9660 and / or UDF
plus HFS+, as `xorriso -hfsplus` and Mac tools write them) with one folder per file system. When the
HFS+ part does not open (its volume header is not one the reader takes, its catalog is refused or
cannot be read), the part is dropped quietly - no message, and the listing is not marked incomplete
(feature 328's mark that makes a whole-image unpack fail). Feature 330 added the mark for a declared
ISO 9660 or UDF part that does not open, not for HFS+.

Measured on the Debug build at e9f777da on the hidden desktop (probe `iso333_probe.ps1`; seeds by
xorriso in WSL Ubuntu, damaged copies by a Python writer). The tree `a/side.txt`, `top.txt`,
`zlast/z.txt`; `side.txt` is hidden from the ISO 9660 part, so it exists only in the HFS+ part.
Unpack (Alt+F9) of the whole image with "Delete archive after unpacking":

- the intact hybrid: all five files of both parts extracted, the image deleted (correct) - **the HFS+
  part of a valid xorriso hybrid opens** (the item's first question);
- the HFS+ volume header's version 5, the catalog's header node kind 0, the catalog size 0, the
  catalog's first extent past the end of the image: **only the ISO 9660 part's two files extracted,
  no message, the image deleted - `side.txt` lost**;
- the layout of Ubuntu's / Debian's install images (`xorriso -isohybrid-mbr -isohybrid-apm-hfsplus`
  with an EFI boot image): an Apple partition map ("ER" at sector 0) whose `Apple_HFS` partition holds
  the EFI image - **no HFS+ volume**. The plug-in takes it as ISO 9660 + HFS+ and its HFS part does not
  open. Marking that would make every such install image's whole unpack fail.

So the Apple partition map or an `Apple_HFS` partition does not show that an HFS+ volume is there; the
HFS+ volume header's own signature at the place the partition map gives does.

## Clarifications

### Session 2026-10-24

- Q: What shows that an HFS+ part is "declared" (the item's *Expected*)? → A: an HFS+ volume header
  signature where the reader looks for the volume header - "H+", or an HFS wrapper "BD" whose embedded
  volume signature is "H+". Not the Apple partition map ("ER") or an `Apple_HFS` partition alone
  (measured: Ubuntu-style install images have both and no HFS+ volume) (autonomous run: item - its
  *Notes* "marking a part that fails on valid images would make their whole unpack fail"; measured)
- Q: Is the mark tied to the track type naming HFS (as 330's `HasISO` / `HasUDF`)? → A: no - the
  volume header signature itself is the declaration; the reader tries the HFS part of every
  ISO / UDF hybrid, and a part that shows an HFS+ signature and does not open has files that are not
  listed (autonomous run: rule - CLAUDE.md "a safe to delete? check fails closed")
- Q: APFS parts, original HFS (a "BD" volume without an embedded HFS+ volume) and HFSX ("HX") - mark
  them? → A: no; none of them carries the HFS+ signature the rule asks for, so they stay as today (the
  plug-in never lists them; marking would make every such hybrid's whole unpack fail - the item says
  APFS needs its own decision, the same holds for the other two) (autonomous run: item + conservative)
- Q: A message when the HFS+ part does not open? → A: no new message or UI string - the quiet open
  stays (autonomous run: item - "The quiet open stays (no new box)")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Unpack + delete keeps a hybrid whose HFS+ part does not open (Priority: P1)

A user unpacks a damaged ISO 9660 + HFS+ hybrid (Alt+F9) with "Delete archive after unpacking". Its
HFS+ part does not open. Today the ISO 9660 part is extracted and the image is deleted - files only in
the HFS+ part are lost. Now the ISO 9660 part is extracted and the image stays.

**Why this priority**: data loss - the only copy of the HFS+-only files is deleted.

**Independent Test**: probe Unpack rows of crafted hybrids (volume header version wrong, catalog
header node not a header, catalog size 0, catalog extent past the end) with "Delete archive after
unpacking": the ISO 9660 files extracted, no new message, the image kept.

**Acceptance Scenarios**:

1. **Given** a hybrid whose HFS+ volume header has the signature "H+" but a version other than 4,
   **When** it is unpacked whole with "Delete archive after unpacking", **Then** the ISO 9660 part is
   extracted and the image is kept.
2. **Given** a hybrid whose HFS+ catalog is refused or cannot be read (header node, size 0, extent
   past the end), **When** unpacked the same way, **Then** the ISO 9660 part is extracted and the image
   is kept.

---

### User Story 2 - Valid images and images without an HFS+ volume unpack and delete as before (Priority: P1)

**Why this priority**: marking a valid image would make every whole unpack of it fail - Ubuntu- and
Debian-style install images are common.

**Independent Test**: probe rows of the intact hybrid and of an Ubuntu-style APM install image: all
files extracted, the image deleted, as before.

**Acceptance Scenarios**:

1. **Given** an intact ISO 9660 + HFS+ hybrid, **When** unpacked whole with "Delete archive after
   unpacking", **Then** every file of both parts is extracted and the image is deleted.
2. **Given** an image with an Apple partition map whose `Apple_HFS` partition holds no HFS+ volume
   (the EFI image of an install ISO), **When** unpacked the same way, **Then** its files are extracted
   and the image is deleted.

### Edge Cases

- The HFS+ volume header's signature itself destroyed: no HFS+ volume is declared, the image is deleted
  as before (a limit, as feature 330's UDF part with a destroyed anchor).
- An HFS wrapper ("BD") with an embedded HFS+ volume whose header then does not read or is wrong:
  declared, marked.
- Original HFS ("BD" without an embedded HFS+ volume), HFSX ("HX"), APFS: not declared, unchanged.
- The volume header cannot be read at all (past the end of the image): no signature seen, not marked.
- Out of memory while opening the HFS+ part after its signature was seen: marked (fail closed).
- The HFS+ part opens: nothing changes (its own records are marked by features 329 / 332).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the HFS+ part of a hybrid shows an HFS+ volume header signature ("H+", or "BD"
  with an embedded "H+") and then does not open, the listing MUST be marked incomplete, so a
  whole-image unpack fails and "Delete archive after unpacking" keeps the image.
- **FR-002**: When no such signature is seen (no HFS+ volume, original HFS, HFSX, APFS, an
  unreadable header), the behaviour MUST stay as today: the part is dropped without a mark.
- **FR-003**: No new message box or UI string; the HFS+ open stays quiet in a hybrid.
- **FR-004**: The decision "does this volume header declare an HFS+ volume" MUST be a pure rule with
  unit checks (saltests), including the negative cases.
- **FR-005**: Images whose HFS+ part opens and images without an HFS+ volume MUST unpack and be
  deleted as before (no regression of features 322 / 329 / 330 / 332).

### Key Entities

- **HFS+ volume header signature**: two bytes at 1024 bytes into the HFS+ partition ("H+", "HX", or
  "BD" for an HFS wrapper whose master directory block names an embedded volume "H+" at byte 124).
- **Listing mark** (feature 328's `ListingLeftOut`): makes a whole-image unpack fail; the image is kept.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 4 of 4 damaged-HFS+ probe rows keep the image (0 of 4 at e9f777da).
- **SC-002**: The intact hybrid and the Ubuntu-style install image are still deleted after a full
  unpack (2 of 2 controls).
- **SC-003**: The pure rule's checks pass in saltests, and a mutant that ignores the signature fails.
- **SC-004**: Probes of features 322, 329, 330 and 332 show no new FAIL rows.

## Assumptions

- Assumption (autonomous run): the HFS+ volume header signature is the declaration of an HFS+ part
  (measured: Ubuntu-style images carry "ER" and an `Apple_HFS` partition without an HFS+ volume).
- Assumption (autonomous run): APFS, original HFS and HFSX hybrids keep today's behaviour; their
  decision is recorded as an Inbox item, not taken here.
- The "Cannot read sector #00000020." / "#00000200." boxes at the open of xorriso images are other
  items (Inbox), not part of this feature.
