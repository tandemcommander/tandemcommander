# Feature Specification: An HFS+ image whose catalog records were skipped as damaged is kept by Unpack with "Delete archive after unpacking"

**Feature Branch**: `332-uniso-hfs-skipped-records`  
**Created**: 2026-10-24  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let` - "ISO plug-in: UDF and HFS+ entries skipped as damaged let Unpack delete the image". From backlog item iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let.

## Background (traced and measured at 6070ac51)

The ISO plug-in (`uniso`, on in the default build) reads the HFS+ part of a hybrid disc image (ISO
9660 + HFS+, as `xorriso -hfsplus` and Mac tools write them) from its catalog. When a catalog record
is damaged - its key does not fit its node, its name is longer than 255 units, a folder / file record
is shorter than its structure, its name does not convert - the plug-in skips it without a word; a
record of a type it does not handle ends the whole HFS+ listing. In no case is the listing marked
incomplete (feature 328's mark that makes a whole-image unpack fail). Unpack (Alt+F9) of the whole
image with "Delete archive after unpacking" then extracts what was listed, reports success and deletes
the image: the skipped entries are lost.

Measured on the Debug build at 6070ac51 on the hidden desktop (a probe built on feature 330's; seeds
by `xorriso -hfsplus` and `genisoimage -udf` in WSL, damaged copies by a Python writer). The tree
`a/side.txt`, `top.txt`, `zlast/z.txt`; in the HFS+ hybrid `side.txt` is hidden from the ISO 9660
part, so it exists only in the HFS+ part. `side.txt`'s catalog record damaged four ways - record type
5 (the HFS+ listing ends there, `z.txt` missing too), key length 0xFFFF, a 256-unit name in a key that
fits, a file record shorter than its structure: **every one extracted the listed files without a
message and deleted the image** (`side.txt` lost). The intact image: all five files, image deleted
(correct). Every HFS+ hybrid of xorriso also shows "Cannot read sector #00000020" at the open - a
known, separate Inbox item (`iso-plug-in-a-valid-xorriso-iso-hfs-hybrid-opens-with-cannot`).

The item's UDF part - a file whose entry (ICB) cannot be read - is already fixed at HEAD by feature
330 (the failure ends the UDF walk, and a walk result other than OK marks the listing): the same probe
with `a/side.txt`'s UDF identifier pointing its entry past the end of the image keeps the image. This
feature keeps that row as a regression check and changes no UDF code.

HFS+ is read only as part of a hybrid; the hybrid's listing ignores the HFS+ reader's result, so the
listing mark is the only way the unpack learns that something was left out.

## Clarifications

### Session 2026-10-24

- Q: Does the UDF reader change in this feature? → A: no - feature 330 already marks a UDF file
  whose entry cannot be read (measured: U-FILE keeps the image at 6070ac51); a probe row keeps it
  checked (autonomous run: item - its *Log* "related item ... done in feature 330"; measured)
- Q: Should a record of a type the reader does not handle still end the HFS+ listing, or be skipped
  alone? → A: still end it, as today; only the mark is added (autonomous run: conservative - the item's
  *Expected* asks for the mark only; the existing behaviour is kept for what it does not name)
- Q: Is a name starting with U+0000 damage (mark) or metadata (no mark)? → A: metadata - TN1150's
  "\0\0\0\0HFS+ Private Data" folder that macOS creates; its contents (hard-link inodes) are listed at
  the HFS+ root today, so nothing is lost; marking it would stop every such Mac image from being
  deleted after an unpack (autonomous run: item - "thread records and the volume-label record, which
  are not entries, stay skipped without a mark" - the same class: records that are not user entries)
- Q: Does the user see a message when a record is skipped? → A: no new message or UI string - the
  image is kept silently, as feature 330's silent cases (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Unpack + delete keeps an HFS+ image whose catalog record was skipped (Priority: P1)

A user unpacks a damaged ISO 9660 + HFS+ hybrid (Alt+F9) with "Delete archive after unpacking". A
catalog record of a file of the HFS+ part is damaged. Today the listed files are extracted and the
image is deleted - the file of the damaged record is lost. Now the listed files are extracted and the
image stays.

**Why this priority**: data loss - the only copy of a file the plug-in did not list is deleted.

**Independent Test**: probe Unpack rows of crafted hybrids (a record type not handled, a key that
does not fit its node, a name over 255 units, a file record shorter than its structure) with "Delete
archive after unpacking": the listed files extracted, no new message, the image kept.

**Acceptance Scenarios**:

1. **Given** a hybrid whose HFS+ record of `a/side.txt` does not fit its node, has a 256-unit name, or
   is shorter than a file record, **When** it is unpacked whole with "Delete archive after unpacking",
   **Then** every other file (both parts) is extracted, and the image is kept.
2. **Given** a hybrid whose HFS+ record of `a/side.txt` has a record type the plug-in does not handle,
   **When** unpacked the same way, **Then** the files listed before it are extracted (the HFS+ listing
   still ends there, as today) and the image is kept.
3. **Given** a UDF + ISO 9660 hybrid whose UDF file `a/side.txt` has an entry that cannot be read,
   **When** unpacked the same way, **Then** the image is kept (already true since feature 330).

---

### User Story 2 - An intact HFS+ or UDF image is unpacked and deleted as before (Priority: P1)

**Why this priority**: the fix must not make every unpack fail - thread records and the volume-label
record are in every HFS+ catalog and are not entries.

**Independent Test**: the probe's control rows - the undamaged seeds unpacked the same way: every file
extracted, no new message, the image deleted.

**Acceptance Scenarios**:

1. **Given** the undamaged HFS+ hybrid or UDF hybrid, **When** it is unpacked with "Delete archive
   after unpacking", **Then** every file is extracted and the image is deleted as today.

### Edge Cases

- Thread records (an empty name; folder thread / file thread types) and the root folder's record
  (parent ID 1 - the volume label shown as "HFS (<label>)") are not entries: skipped, never marked.
- A folder or file record whose name's first unit is U+0000 (TN1150's metadata folder "\0\0\0\0HFS+ Private Data", created by
  macOS on HFS+ volumes, skipped today as an empty name): not a user entry - skipped without a mark,
  so Mac-made images still unpack and are deleted when asked.
- A folder or file record with an empty name that is not the root folder: damaged - marked.
- A record of a thread type that carries a name, or of an unknown type: not handled - marked (the
  listing ends there, as today).
- A damaged folder record: its contents (whose parent is not listed) are listed at the HFS+ root as
  today; the listing is marked, so a whole unpack fails and the image is kept.
- Browsing the image in the panel and copying selected files are unchanged (the mark only makes a
  whole-image unpack fail; no new message at the open).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: An HFS+ listing that skipped a catalog record holding an entry because the record is
  damaged - its key or name does not fit its node, its name is longer than 255 units, a folder / file
  record is shorter than its structure, a folder / file record other than the root folder has an empty
  name, its name does not convert - MUST be marked incomplete.
- **FR-002**: An HFS+ listing that met a record of a type it does not handle (neither folder nor file,
  with a name) MUST be marked incomplete; the listing still ends at that record, as today.
- **FR-003**: Thread records, the root folder's record (the volume label) and a folder or file record
  whose name starts with U+0000 (HFS+ metadata) MUST stay skipped without a mark. A record of a type
  the reader does not handle whose name starts with U+0000 is skipped as today and marked (damaged).
- **FR-004**: A whole-image unpack of a listing marked incomplete MUST extract the listed entries and
  fail, so "Delete archive after unpacking" keeps the image (feature 328's existing behaviour of the
  mark).
- **FR-005**: No message is added or changed: no new box at the open or at the unpack, no new UI text.
- **FR-006**: A listing without such a record MUST be exactly as today - its unpack succeeds and the
  image is deleted when asked. The UDF reader is not changed (feature 330 already marks a file entry
  that cannot be read).

### Key Entities

- **Listing incomplete mark**: feature 328's flag of an image's listing; set, a whole-image unpack
  fails and the image is kept.
- **HFS+ catalog leaf record**: key (length, parent ID, name) + record data (type: folder, file,
  folder thread, file thread).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: the probe's four damaged-HFS+ Unpack rows go from the image deleted before the fix to
  the image kept after it; its HFS+ and UDF control rows and the UDF file-entry row pass before and
  after.
- **SC-002**: the probes of features 322, 328, 329 and 330 keep their results.
- **SC-003**: the record rule is checked by unit rules (every class of record, including thread
  records, the volume label and the metadata name); saltests keep 0 failed; build and encoding guard
  clean.

## Assumptions

- Assumption (autonomous run): the item's UDF part is done (feature 330, measured at 6070ac51) - no
  UDF code changes; a probe row keeps it checked.
- Assumption (autonomous run): no message is added (as feature 330's silent cases): the image is kept
  without a word; no new UI string, no translation refresh, no manual change.
- Assumption (autonomous run): a record type the reader does not handle still ends the HFS+ listing
  (the existing behaviour; only the mark is added).
- Assumption (autonomous run): a name starting with U+0000 is HFS+ metadata (TN1150), not damage.
- Assumption (autonomous run): crafted images are made by a probe script from xorriso / genisoimage
  seeds (WSL, as features 329 / 330) patched by a Python writer.
