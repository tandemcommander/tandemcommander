# Feature Specification: ISO plug-in - a UDF folder stored in more than one extent is read whole

**Feature Branch**: `364-uniso-udf-folder-extents`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item iso-plug-in-a-udf-folder-stored-in-more-than-one-extent-is - implement exactly what it describes." From backlog item iso-plug-in-a-udf-folder-stored-in-more-than-one-extent-is.

## Clarifications

### Session 2026-11-01

- Q: Walk every extent, or only mark a folder read short? → A: both - every recorded extent is walked (up to 32), and a folder still read short of its Information Length marks the listing incomplete (autonomous run: item - *Expected* allows either; walking keeps the user's files, the mark covers what cannot be walked)
- Q: Does a folder marked incomplete show a message box? → A: no - silent, as feature 330's unreadable sub-folder and 362's folder without data; no new UI string (autonomous run: conservative)
- Q: Are descriptors continued in an allocation extent (type 3) followed? → A: no - not followed (files do not follow them either); the folder is marked when read short (autonomous run: conservative; item Notes call it "the same case")
- Q: Is the walk cut to the Information Length when the extents are longer? → A: no - the existing walk over the extents' length is kept; cutting could hide entries of a folder whose entry understates its size without a mark (autonomous run: conservative)
- Q: Where does the decision live? → A: a pure function in `src/common/salisoudfentry.h` (features 361 - 363's rules of the same reader) with `saltests` checks (autonomous run: rule, stop-rules §2.5)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A fragmented folder is listed and unpacked whole (Priority: P1)

A user has a UDF disc image (for example from fragmented rewritable or packet-written media) in which a folder's
data is stored in two or more pieces (extents), contiguous or not. Today the ISO plug-in reads only the first piece:
the folder's later entries are not listed, a whole unpack (Alt+F9) with "Delete archive after unpacking" extracts
part of the tree, reports success and **deletes the image**. After the fix every piece of the folder is read in
order: every entry is listed and extracted with its content, and the image is deleted only because the unpack was
complete.

**Why this priority**: the item's main point - the user's files are silently missing and the only copy deleted.

**Independent Test**: probe `iso364_probe` rows R-ROOTSPLIT, R-ROOTFRAG, R-SUBSPLIT, R-SUBFRAG on the hidden
desktop, Debug build, copies of `big364.iso` (root and folder `sub` with 40 files each, 2.9 KB of folder data)
with one folder's single extent split by `img364.py`.

**Acceptance Scenarios**:

1. **Given** `big364.iso` whose root folder is stored in two contiguous extents (2048 + 916 bytes), **When** the
   user unpacks it whole with "Delete archive after unpacking", **Then** all 80 files of the UDF part are
   extracted with their content, no window is shown, and the image is deleted.
2. **Given** the same image whose second root extent lies elsewhere in the image (its old place zeroed),
   **When** unpacked the same way, **Then** the same result - an identifier that crosses from one extent into the
   next is read whole, no garbled name.
3. **Given** `big364.iso` whose folder `sub` is stored in two extents, contiguous or not, **When** unpacked the
   same way, **Then** the same result.
4. **Given** any of these images, **When** the user presses Enter on it, **Then** no window, the program keeps
   answering, no bug report.

---

### User Story 2 - A folder that still cannot be read whole keeps the image (Priority: P1)

Some folders still cannot be read whole: a later piece is declared "not recorded", the list of pieces continues
in a separate descriptor block the plug-in does not follow, there are more pieces than the reader holds, or the
pieces together are shorter than the size the folder's entry declares (its Information Length). Today such a
folder is listed cut without a word and a whole unpack deletes the image. After the fix the folder's readable part
is listed as before and the listing is marked incomplete (feature 330), so a whole unpack fails and the image is
**kept**.

**Why this priority**: the item's second alternative - detect a folder read short, never delete the image then.

**Independent Test**: probe rows R-ROOTCONT, R-ROOTUNREC (big364.iso), R-ALEN38, R-ALEN40 (feature 330's
`ud.iso`, folder `a`'s extent shortened, its Information Length kept).

**Acceptance Scenarios**:

1. **Given** `big364.iso` whose root has a first extent of 2048 bytes followed by a descriptor of extent type 3
   (the descriptors continue elsewhere), **When** unpacked whole with "Delete archive after unpacking", **Then**
   the root's files whose identifiers lie in the first 2048 bytes (00 .. 27) are extracted, no window, and the
   image is kept.
2. **Given** the same with a second extent of type 1 (allocated, not recorded), **When** unpacked the same way,
   **Then** the same result.
3. **Given** `ud.iso` whose folder `a` has one extent of 38 or 40 bytes and an Information Length of 88,
   **When** unpacked the same way, **Then** the ISO 9660 part and UDF `top.txt`, `zlast/z.txt` are extracted, UDF
   `a/side.txt` is not, no window, and the image is kept.

---

### User Story 3 - Intact images are unchanged (Priority: P2)

A valid UDF image whose folders each lie in one extent lists and unpacks as today.

**Why this priority**: no regression of the common case.

**Independent Test**: control rows L-BIG, C-BIG, C-UD; the probes of features 330, 361, 362 and 363 re-run.

**Acceptance Scenarios**:

1. **Given** the intact `big364.iso` or `ud.iso`, **When** unpacked whole with "Delete archive after unpacking",
   **Then** every file is extracted, no window, and the image is deleted.

### Edge Cases

- A folder stored in more extents than the reader holds (the same limit as for files, 32) - the walked extents
  are listed, the listing is marked incomplete.
- An extent other than the last whose length is not a whole number of 2048-byte blocks (invalid by ECMA-167) -
  the walk stops after it; if the folder is then read short of its Information Length, the listing is marked.
- A first descriptor that is not a recorded extent (type 1, 2 or 3) - nothing can be walked; the folder takes
  feature 362's unreadable-folder path (the root "Bad root ICB", a sub-folder listed empty with the listing
  incomplete).
- An Information Length smaller than the extents (the extents say more than the entry) - the walked extents are
  walked whole, as the one extent was before (the walk is not cut to the Information Length; such a folder is not
  marked). A later recorded extent past that length is walked too (new - review 1, NOTE 2): a valid image never
  has one; its bytes fail closed (an invalid tag, the listing marked).
- A folder whose data is embedded in its entry - unchanged (one piece; marked only when shorter than its
  Information Length).
- Every existing refusal (feature 361's refused entry, 362's folder without data, 363's identifier past the
  buffer) is unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The ISO plug-in MUST read a UDF folder's data from every recorded extent its file entry lists, in
  order, up to the same limit of 32 extents the plug-in uses for a file.
- **FR-002**: An identifier that crosses from one extent into the next MUST be read from both extents (never from
  the bytes physically following the first one).
- **FR-003**: A folder whose walked extents together are shorter than its entry's Information Length MUST mark the
  listing incomplete (feature 330), so a whole unpack fails and "Delete archive after unpacking" keeps the image.
  This covers a later extent that is not recorded (type 1 or 2), descriptors continued in an allocation extent
  (type 3, not followed), more than 32 extents, and one extent shorter than the Information Length.
- **FR-004**: The readable part of such a folder MUST still be listed and extractable as before.
- **FR-005**: A folder whose single extent covers its Information Length MUST be listed and unpacked exactly as
  before (no change of the walk, no new window).
- **FR-006**: No new user-visible text: the mark is silent at listing, as feature 330's unreadable sub-folder.
- **FR-007**: The decision which extents are walked, how many bytes, and whether the folder is read whole MUST be
  a pure rule with unit checks (stop-rules §2.5).

### Key Entities

- **Folder entry**: a UDF file entry of a folder - its allocation descriptors (extent length, type, location) and
  its Information Length (the folder's size in bytes).
- **Folder stream**: the folder's data as the concatenation of its recorded extents; a sequence of file
  identifiers.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `iso364_probe` goes from 20 PASS / 8 FAIL (main, b1d9e31b) to all rows PASS.
- **SC-002**: Every image in the probe whose folder is not read whole is kept after a whole unpack with "Delete
  archive after unpacking" (0 images deleted, was 4).
- **SC-003**: Fragmented valid images yield all 80 files (was 28 or 68).
- **SC-004**: The probes of features 330, 361, 362 and 363 still pass with their recorded counts; `saltests`
  passes with new checks for the rule.

## Assumptions

- Assumption (autonomous run): the item allows either walking every extent or marking a folder read short; both are
  done - every recorded extent is walked (the user gets the files) and a folder still read short is marked
  (conservative where walking is impossible).
- Assumption (autonomous run): an allocation extent descriptor (type 3) is not followed - neither files nor folders
  follow it today; the folder is marked instead (item Notes name it "the same case").
- Assumption (autonomous run): the walk is not cut to the Information Length when the extents are longer - that
  would hide entries of a folder whose entry understates its size without a mark; the existing behaviour for that
  case is kept.
- Assumption (autonomous run): the 32-extent limit matches `CUDF::UnpackFile`'s `icbs[32]`; a folder past it is
  marked, never cut silently.
- Only the ISO plug-in (`src/plugins/uniso/`) and a header under `src/common/` change; no UI string, no plug-in
  interface change.
