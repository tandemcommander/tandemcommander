# Feature Specification: ISO plug-in - a UDF folder entry without descriptors is unreadable, not empty

**Feature Branch**: `362-uniso-udf-folder-no-descs`
**Created**: 2026-10-31
**Status**: Draft
**Input**: User description: "Backlog item iso-plug-in-a-udf-folder-entry-without-descriptors-is-listed - implement exactly what it describes." From backlog item iso-plug-in-a-udf-folder-entry-without-descriptors-is-listed.

## Clarifications

### Session 2026-10-31

- Q: Does a sub-folder whose entry has no descriptors get a message box? → A: no - the same silent unreadable-folder path as feature 330 (listed empty, listing marked incomplete); no new UI string (autonomous run: conservative)
- Q: Is a folder entry with descriptors whose first descriptor has length 0 treated as unreadable too? → A: yes (revised after review 1, SHOULD 1): such a first extent ends the descriptor sequence (ECMA-167 4/12), so the entry describes no byte either - the item's harm (listed empty without a mark, image deleted) was measured for it by the reviewer; the earlier answer "no, unchanged" kept the data loss (autonomous run: item - its Expected covers an entry that describes no folder data)
- Q: Is a folder whose first extent is shorter than one file identifier (1 - 37 bytes) unreadable too? → A: yes (review 2, SHOULD 1): it cannot hold the parent's identifier (38 bytes + names, padded to 4 - 40 in every image of genisoimage, mkudffs and IMAPI2FS measured); the same harm was measured with 20 bytes; the threshold is 38 so that no valid folder is refused (autonomous run: item)
- Q: Where does the rule live? → A: a pure function in the existing header `src/common/salisoudfentry.h` (feature 361's rules of the same reader) with `saltests` checks; the folder reader applies it (autonomous run: rule, stop-rules §2.5)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A damaged sub-folder no longer costs the user the image (Priority: P1)

A user has a damaged or crafted UDF disc image (for example a genisoimage `-udf` hybrid) in which the file entry
of a sub-folder declares no allocation descriptors (L_AD 0) - with short / long descriptors or as an embedded
(type 3) entry. Every real UDF folder holds at least the identifier of its parent, so such an entry cannot
describe the folder: its contents are lost to the reader. Today the ISO plug-in lists the folder as empty
without any mark; a whole unpack (Alt+F9) with "Delete archive after unpacking" extracts everything else, reports
success and **deletes the image** - the folder's files are gone for good. After the fix the folder is treated
as unreadable (feature 330): it is listed empty, the listing is marked incomplete, the unpack fails and the
image is kept.

**Why this priority**: the item's main point - the user's only copy of the data is deleted.

**Independent Test**: probe `iso362_probe` rows R-ALAD0, R-AEMB0, R-ZLAD0 on the hidden desktop, Debug build,
copies of feature 330's `ud.iso` whose folder `a` or `zlast` has L_AD 0.

**Acceptance Scenarios**:

1. **Given** `ud.iso` whose folder `a`'s entry (short descriptors) has L_AD 0, **When** the user unpacks it
   whole with "Delete archive after unpacking", **Then** every file except the UDF part's `a/side.txt` is
   extracted with its content, no window appears, and the image is **kept**.
2. **Given** `ud.iso` whose folder `a`'s entry is embedded (type 3) with L_AD 0, **When** unpacked the same way,
   **Then** the same result as scenario 1.
3. **Given** `ud.iso` whose last folder `zlast`'s entry has L_AD 0, **When** unpacked the same way, **Then**
   every file except the UDF part's `zlast/z.txt` is extracted and the image is kept.

---

### User Story 2 - A damaged root folder is reported (Priority: P1)

The file entry of the UDF root folder itself has L_AD 0 (short / long descriptors, or embedded as mkudffs writes
it). Today the UDF volume is listed empty without a word and a whole unpack deletes the image. After the fix the
existing box "Bad root ICB. Cannot read directory structure." is shown (as for any unreadable root entry), the
listing is marked incomplete, and the image is kept; the ISO 9660 part of a hybrid image still lists and unpacks.

**Why this priority**: the same data loss, at the top of the volume.

**Independent Test**: probe rows L-ROOTLAD0, L-ROOTEMB0, R-ROOTLAD0, R-ROOTEMB0.

**Acceptance Scenarios**:

1. **Given** `ud.iso` whose UDF root entry has L_AD 0, **When** the user presses Enter on it, **Then** "Bad
   root ICB" is shown and the program keeps answering.
2. **Given** the same image, **When** unpacked whole with "Delete archive after unpacking", **Then** "Bad root
   ICB" is shown, the ISO 9660 part's three files are extracted, and the image is kept.
3. **Given** mkudffs `mk_cdr.img` whose embedded root entry has L_AD 0, **When** listed / unpacked whole,
   **Then** "Bad root ICB" is shown, nothing is extracted, and the image is kept.

---

### User Story 3 - Real empty folders and intact images are unchanged (Priority: P2)

A real empty folder (genisoimage writes its parent identifier: L_AD > 0) and an empty mkudffs volume (embedded
root with its parent identifier) list and unpack as today, and a whole unpack of an intact image still deletes
it when asked to.

**Why this priority**: no regression of the readable case.

**Independent Test**: control rows L-UE, C-UD, C-UE, C-MKCDR; the probes of features 330 and 361 re-run.

**Acceptance Scenarios**:

1. **Given** `ue.iso` (genisoimage `-udf` of an empty folder `e`, `f.txt`, `g/h.txt`), **When** listed, **Then**
   no window; **When** unpacked whole with "Delete archive after unpacking", **Then** both parts' files and both
   empty folders `e` are extracted, no window, the image is deleted.
2. **Given** the intact `ud.iso` and the empty `mk_cdr.img`, **When** unpacked the same way, **Then** all their
   files are extracted, no window, the image is deleted.

### Edge Cases

- A folder entry with L_AD 0 *and* a reserved descriptor type stays refused by feature 361 (same outcome).
- A folder entry whose first (only) descriptor has extent length 0, or less than 38 bytes (L_AD kept), cannot hold the
  parent's identifier either: the same unreadable path (reviews 1 and 2; probe rows R-ALEN0, R-ROOTLEN0, L-ROOTLEN0,
  R-ALEN20, R-ROOTLEN20, L-ROOTLEN20).
- A folder in more than one extent is read only up to its first extent - older, not this item (Inbox, review:362).
- A file (not a folder) with L_AD 0 is a real empty file and is unchanged: the folder reader is not used for files.
- The Release build: with the fix the walk never starts from the terminating descriptor's unset offset for such
  an entry (the item's note), because the folder is not walked at all.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A UDF folder file entry (root or sub-folder) that declares no allocation descriptors - L_AD 0 with
  short, long or extended descriptors, or an embedded (type 3) entry with L_AD 0 - or whose first descriptor (or
  embedded data) gives fewer than 38 bytes, too few for the parent's identifier, MUST be treated as an unreadable
  folder entry, exactly as an entry that cannot be read today.
- **FR-002**: For a sub-folder this MUST mean: listed (as today) but not descended, and the listing marked
  incomplete (feature 330), so a whole unpack fails and "Delete archive after unpacking" keeps the image.
- **FR-003**: For the root folder this MUST mean the existing "Bad root ICB" box, the listing marked incomplete,
  nothing of the UDF part listed.
- **FR-004**: Folder entries whose first descriptor (or embedded data) gives at least 38 bytes, and every file entry,
  MUST be read as before.
- **FR-005**: No new UI string, no change of the plug-in interface, no change outside the ISO plug-in's folder
  reader and its rule.
- **FR-006**: The decision ("a folder entry whose first extent can hold an identifier can be walked") MUST be a pure rule with
  `saltests` checks (stop-rules §2.5).

### Key Entities

- **Folder file entry**: the UDF descriptor that locates a folder's identifiers - its descriptor-type flags and
  its L_AD (byte length of its allocation descriptors / embedded data).
- **Listing completeness mark** (feature 328/330 `ListingLeftOut`): makes a whole unpack fail and keeps the image.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In all 9 damaged-image unpack rows (folder a / zlast / embedded a / root / embedded root with L_AD 0;
  folder a / root with a first extent of length 0 and of 20 bytes) the image is kept (before: deleted in 9 of 9).
- **SC-002**: All 4 damaged-root listing rows show "Bad root ICB" (before: no window in 4 of 4).
- **SC-003**: All 4 control rows (real empty folder listed and unpacked, intact hybrid, empty volume) give the same
  result as before the change (deleted after a full unpack, no window).
- **SC-004**: The probes of features 330, 356 (the roots of every mkudffs media type) and 361 give their recorded
  results.

## Assumptions

- Assumption (autonomous run): the ISO plug-in's folder reader `MapICB(CAD, CICBTag*, CAD*)` is used only for
  folders (its two callers: root in `ListDirectory`, sub-folders in `ScanDir` for entries flagged as folders) -
  measured at 5d74e338; the rule is applied there only.
- Assumption (autonomous run): no new message for the sub-folder case - feature 330's unreadable-folder path shows
  none either (the listing mark is what keeps the image).
- Assumption (autonomous run): only the first descriptor's length is checked (`MapICB` reads one descriptor);
  a folder in several extents is an older, separate defect (Inbox, review:362).
