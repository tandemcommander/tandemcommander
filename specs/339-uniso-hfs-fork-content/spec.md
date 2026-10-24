# Feature Specification: ISO plug-in - an HFS+ file whose content is not in its data fork is not extracted empty

**Feature Branch**: `339-uniso-hfs-fork-content`
**Created**: 2026-10-24
**Status**: Draft
**Input**: Backlog item `iso-plug-in-an-hfs-file-whose-data-is-compressed-or-only-in` (`backlog/items/iso-plug-in-an-hfs-file-whose-data-is-compressed-or-only-in/desc.md`) - "ISO plug-in: an HFS+ file whose data is compressed or only in its resource fork extracts empty". From backlog item iso-plug-in-an-hfs-file-whose-data-is-compressed-or-only-in.

## Background (measured at 75fc0f43)

The ISO plug-in reads only the data fork of a file on an HFS+ volume. macOS keeps the content of some files
elsewhere: an HFS+-compressed file (the file's flag "compressed" set; the compressed data in the resource
fork or in an extended attribute, the data fork empty), and a file whose content is only in its resource
fork (a custom icon file "Icon\r", classic Mac files). A hidden-desktop probe (draft `iso339_probe.ps1`,
seed = an xorriso ISO 9660 + HFS+ hybrid in which `a/side.txt` exists only in the HFS+ part, its catalog
record crafted) on the Debug build of `main`:

| Row | side.txt's record | At HEAD (Alt+F9, "Delete archive after unpacking") |
|---|---|---|
| H-OK (control) | ordinary file | SIDE extracted, image deleted (right) |
| H-RSRC | content only in the resource fork | **empty side.txt, no box, image deleted** - the content lost |
| H-COMP | compressed, data in the resource fork | **empty side.txt, image deleted** |
| H-COMPIN | compressed, both forks empty (data in an attribute) | **empty side.txt, image deleted** |
| H-FLAG | compressed flag, data fork not empty | data fork written as the content, image deleted |
| H-NOMODE (control) | compressed flag but the BSD information not initialised (file mode 0) | SIDE extracted, image deleted (right: macOS ignores the flags then) |
| H-BOTH (control) | data fork and a resource fork | SIDE extracted, image deleted |

## Clarifications

### Session 2026-10-24

- Q: Is such a file extracted with its content (decompressed / its resource fork) or counted as not extracted? → A: Counted as not extracted: the reader cannot decompress HFS+ compression (several methods, the data in an attribute B-tree it does not read) and Windows has no place for a resource fork as a file's content; the item allows either (autonomous run: item + conservative)
- Q: Is the user told why the file was not extracted? → A: Yes - a box naming the file and the reason (compressed / only in the resource fork) with Skip, Skip all and Cancel, as the reader's read-error box; after Skip all (or another silent answer of the same operation) no box, the file still not extracted (autonomous run: rule - the existing "fragmented" refusal of the same reader shows a box; 338's readers' silent path)
- Q: What about a file that has both a data fork and a resource fork? → A: Unchanged - its data fork is extracted and counted as done (the item names compressed and resource-fork-only files only); recorded as a limit and an Inbox item (autonomous run: conservative)
- Q: When is a file "compressed"? → A: When the compressed flag is set in the BSD flags of its catalog record and the BSD information is initialised (TN1150: a file mode whose type bits are zero means the whole structure is not initialised); the attribute B-tree is not read (autonomous run: item *Notes* - the flag is the cheaper sign - and TN1150)
- Q: Does the listing change (size, attributes)? → A: No - only extraction (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A compressed or resource-fork-only HFS+ file keeps the image (Priority: P1)

A user unpacks a whole disc image with an HFS+ part (made on a Mac) with "Delete archive after unpacking".
One of its files is HFS+-compressed or holds its content only in its resource fork. The program tells the
user that this file cannot be extracted (Skip / Skip all / Cancel), does not write an empty file in its
place, extracts the rest, ends the unpack as failed and keeps the image.

**Why this priority**: the item's main point - the image is deleted with the file's only content.

**Independent Test**: probe rows H-RSRC, H-COMP, H-COMPIN, H-FLAG: one box naming side.txt, Skip: side.txt
not written, the other files extracted, the image kept; H-OK: an intact image is still deleted, no box.

**Acceptance Scenarios**:

1. **Given** an image whose HFS+ file keeps its content only in its resource fork, **When** the user unpacks
   it whole with "Delete archive after unpacking" and answers Skip in the box that names the file and the
   resource fork, **Then** the file is not written, every other file is extracted and the image is kept.
2. **Given** an image whose HFS+ file is compressed (the data in the resource fork, in an attribute, or a
   data fork beside the flag), **When** it is unpacked whole and the box naming the file as compressed is
   answered Skip, **Then** the file is not written, the rest is extracted and the image is kept.
3. **Given** an intact HFS+ image, **When** it is unpacked whole, **Then** every file is extracted, no new box
   appears and the image is deleted as before.

---

### User Story 2 - Skip all and Cancel (Priority: P2)

With two such files, Skip all at the first box skips the second without a box; Cancel ends the unpack. In
both cases the image is kept and no empty file is left in place of a refused one.

**Why this priority**: the same loss through the box's other answers.

**Independent Test**: probe rows H-SKIPALL (one box, both files missing, image kept) and H-CANCEL (side.txt
missing, image kept).

**Acceptance Scenarios**:

1. **Given** two compressed files, **When** the first box is answered Skip all, **Then** no second box
   appears, neither file is written and the image is kept.
2. **Given** a compressed file, **When** its box is answered Cancel, **Then** the unpack stops, the file is
   not written and the image is kept.

---

### User Story 3 - Ordinary files stay as they are (Priority: P3)

Files whose content is in the data fork extract exactly as before - also when the BSD information is not
initialised (a stray "compressed" flag is ignored, as macOS does) and when the file also has a resource fork.

**Why this priority**: no regression for the common case.

**Independent Test**: probe rows H-OK, H-NOMODE, H-BOTH: every file extracted with its content, no box,
image deleted.

**Acceptance Scenarios**:

1. **Given** a file with the compressed flag but uninitialised BSD information and data in the data fork,
   **When** unpacked, **Then** its data fork is extracted and counted as done.
2. **Given** a file with a data fork and a resource fork, **When** unpacked, **Then** its data fork is extracted
   and counted as done (as before).

### Edge Cases

- A genuinely empty file (both forks empty, not compressed) is extracted as an empty file, as before.
- Copy (F5) of the refused file out of an opened image, or viewing it: the same box; no empty file is
  written; Skip leaves the other selected files to be copied.
- A symbolic link (its target in the data fork) and an HFS+ hard link record (empty data fork, no resource
  fork; the related item) are unchanged.
- A target file of the same name that already exists is not touched for a refused file (the refusal comes
  before the file is created).
- A compressed flag on a file whose data fork holds data is still refused (macOS reads such a file through
  its compression, never from the data fork).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Extraction of an HFS+ file MUST NOT write the data fork as the file's content when the file is
  compressed (the compressed flag set in initialised BSD information) or when its data fork is empty and its
  resource fork is not.
- **FR-002**: Such a file MUST count as not extracted (feature 338's rule): a whole unpack that meets it ends
  as failed and "Delete archive after unpacking" keeps the image.
- **FR-003**: The refusal MUST come before the target file is created: no empty file and no change to an
  existing target file of that name.
- **FR-004**: The user MUST be told which file was not extracted and why (compressed / only in the resource
  fork) with the choices Skip, Skip all and Cancel; after Skip all, or when the operation is already silent,
  later refusals show no box and still count as not extracted; Cancel ends the operation.
- **FR-005**: The decision MUST be a pure rule with unit checks: compressed flag + initialised BSD information
  → compressed; otherwise empty data fork + non-empty resource fork → resource fork only; otherwise the data
  fork is the content.
- **FR-006**: Files whose content is the data fork (including those with uninitialised BSD information or a
  resource fork beside a non-empty data fork) MUST extract exactly as before.
- **FR-007**: The new texts MUST be translated for every enabled language (formal register).

### Key Entities

- **HFS+ file record**: the catalog entry of a file - its BSD information (owner flags with the compressed
  flag, file mode), its data fork and its resource fork (each with a logical size).
- **Content kind**: data fork / compressed / resource fork only - decided from the record.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In all 6 rows where the content is not in the data fork (H-RSRC, H-COMP, H-COMPIN, H-FLAG,
  H-SKIPALL, H-CANCEL), the image is kept and no empty or wrong file stands in for the refused one (0 of 6
  before).
- **SC-002**: The 3 control rows (H-OK, H-NOMODE, H-BOTH) extract every file with its content, show no new
  box and delete the image, as before.
- **SC-003**: The pure rule's unit checks pass, and a mutant that ignores either sign fails at least one of them.
- **SC-004**: Earlier ISO plug-in probes of the HFS+ reader (332, 333) keep their results.

## Assumptions

- Assumption (autonomous run): no Mac-made image is available on this machine (as in 332 / 333); images are
  crafted from an xorriso HFS+ hybrid. A check with a Mac-made image with compressed files is owed to a person.
- Assumption (autonomous run): the listed size stays the data fork's size (often 0 for such files); showing
  the real size needs the attribute B-tree and is not part of the item.
- Assumption (autonomous run): a file with both forks keeps extracting only its data fork and counting as done;
  the dropped resource fork is recorded as an Inbox item (a maintainer's trade-off: failing every such whole
  unpack would keep most classic Mac images).
- Assumption (autonomous run): HFS+ hard links stay as they are (the related item).
