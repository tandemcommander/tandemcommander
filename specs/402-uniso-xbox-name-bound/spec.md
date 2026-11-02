# Feature Specification: ISO plug-in - an Xbox entry name is never read past the end of its directory

**Feature Branch**: `402-uniso-xbox-name-bound`
**Created**: 2026-11-02
**Status**: Draft
**Input**: User description: "Backlog item iso-plug-in-an-xbox-entry-name-can-be-read-past-the-end-of - implement exactly what it describes." From backlog item iso-plug-in-an-xbox-entry-name-can-be-read-past-the-end-of.

## Background

The ISO plug-in lists an Xbox (XDVDFS) disc image by walking its folders. Each folder's directory is
held in memory with the size the image gives for it; each directory entry is a fixed 14-byte head
(start, size, attributes, name length) followed by the name. Before this feature the walk checked only
that the head lies in the directory's bytes, not the name: a damaged or crafted image whose last entry
gives a name longer than what is left of the directory made the walk copy bytes from outside the
directory's memory into the name.

Measured at 76e8f098 (probe `iso402_probe`, images written from scratch by `img402.py`, Unpack of the
whole image with "Delete archive after unpacking"): four images whose last entry's name runs 1, 198,
253 bytes past the end of the root or of a sub-folder all listed a file named `zz` followed by bytes of
the program's memory (`zzýýýý`), showed no error, did not mark the listing incomplete, and the image
was deleted after unpacking. The control image whose last name ends exactly at the end of the
directory listed `zz` correctly.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged Xbox image is reported, not listed with invented names (Priority: P1)

A user opens or unpacks an Xbox disc image one of whose directories ends inside an entry's name
(damaged or crafted). The program must not list a name made of bytes that are not in the image, must
tell the user once that the directory structure could not be read, and must not delete the image after
an unpack that could not extract everything.

**Why this priority**: it is the defect - reading outside the directory's memory gives invented
names (and could crash the program), and the silent incomplete listing lets "Delete archive after
unpacking" delete an image whose content was not all extracted.

**Independent Test**: probe rows XD-NAME, XD-OVER1, XD-MAX (root) and XD-SUB (a sub-folder).

**Acceptance Scenarios**:

1. **Given** an Xbox image whose root holds top.txt, zlast/z.txt and then an entry whose name runs past
   the end of the root's data, **When** the user unpacks the whole image with "Delete archive after
   unpacking", **Then** exactly one "Error reading directory structure" box is shown, top.txt and
   zlast/z.txt are extracted and nothing else, and the image is kept.
2. **Given** the same with the name running only one byte past the end, **When** unpacked, **Then** the
   same outcome.
3. **Given** the same with the name length 255, **When** unpacked, **Then** the same outcome.
4. **Given** an image whose sub-folder a holds side.txt and then an entry whose name runs past a's data,
   followed in the root by top.txt and zlast/z.txt, **When** unpacked, **Then** one box, a/side.txt,
   top.txt and zlast/z.txt are extracted, and the image is kept.

---

### User Story 2 - A valid Xbox image is unchanged (Priority: P1)

**Why this priority**: the bound must not refuse a name that lies exactly at the end of the directory
(off-by-one), nor change any valid image.

**Independent Test**: probe row XD-EDGE; feature 400's probe (its XD rows and controls) and 401's
probe still pass.

**Acceptance Scenarios**:

1. **Given** an image whose last entry's name ends exactly at the end of the root's data, **When**
   unpacked with "Delete archive after unpacking", **Then** top.txt, zlast/z.txt and zz are extracted,
   no window is shown and the image is deleted (as before the feature).

### Edge Cases

- The name runs past the end by one byte (off by one) - refused.
- The name ends exactly at the end of the directory - accepted.
- A name length of 255 (the largest the format can give) - refused when it does not fit, never read.
- The damaged entry is in the root: the entries before it stay listed, the listing is marked
  incomplete (the image opens; a whole unpack keeps it).
- The damaged entry is in a sub-folder: that folder's walk ends there; the parent's later entries and
  folders are still walked (feature 400).
- Several damaged directories in one image: the walk's one box (feature 400), not one per directory.
- Sizes near the top of the 32-bit range: the check is computed without wrap-around.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The Xbox folder walk MUST check, before it reads an entry's name, that the entry's head
  and its whole name lie in the directory's data; the check MUST be computed without wrap-around.
- **FR-002**: An entry that fails the check MUST be treated as a damaged record: the walk of that
  directory ends there, no byte outside the directory's data is read, and the entry is not listed.
- **FR-003**: A damaged record MUST show the walk's error box "Error reading directory structure" at
  most once per walk (feature 400's one box) and MUST mark the listing incomplete (feature 330), so a
  whole unpack with "Delete archive after unpacking" keeps the image.
- **FR-004**: The entries listed before the damaged record, and the later entries and folders of its
  parent directories, MUST still be listed and extractable.
- **FR-005**: An entry whose name ends exactly at the end of the directory's data MUST be listed as
  before; no valid image changes its listing.
- **FR-006**: The check is a pure rule with automated checks (unit rules), including the boundary
  (fits exactly, one byte over), the largest name length and sizes near the 32-bit limit.
- **FR-007**: No new user interface text: the existing error box text is reused.

### Key Entities

- **Directory entry (Xbox)**: a 14-byte head (subtree offsets, start sector, file size, attributes,
  name length 0-255) followed by the name bytes, inside a directory's data of a known size.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The four damaged-image probe rows pass (before: 4 FAIL): no listed name contains a byte
  that is not in the image, exactly one error box, the image kept.
- **SC-002**: The control row passes before and after (an exactly fitting name is listed).
- **SC-003**: Feature 400's and 401's probes keep their results (48 / 0 and 10 / 0).
- **SC-004**: The unit rules pass with 0 failures, and a mutant of the rule without the name bound
  fails them.

## Assumptions

- Assumption (autonomous run): a damaged record in the root ends the root's walk with "incomplete"
  rather than "failed": the entries before it stay listed and the image opens (the existing behaviour
  of a root whose read fails; conservative - shows what can be read, keeps the image on unpack). The
  ISO 9660 reader's own root rules are not changed.
- Assumption (autonomous run): the existing box text `IDS_ERROR_LISTING_IMAGE` ("Error reading
  directory structure at sector ...") is reused with the directory's sector; no translation work.
- The silent bail-out on unexpected 0xFF padding in the same walk, empty names and the walk's
  treatment of the Xbox directory as a linear list (not a tree) are outside this item.
- Probes run on the hidden desktop with the Debug build; the guard bytes of the Debug heap make the
  over-read visible in the names.
