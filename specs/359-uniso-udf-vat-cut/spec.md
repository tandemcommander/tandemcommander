# Feature Specification: ISO plug-in - a cut UDF VAT image no longer hangs the listing

**Feature Branch**: `359-uniso-udf-vat-cut`
**Created**: 2026-10-31
**Status**: Draft
**Input**: User description: "Backlog item iso-plug-in-a-cut-udf-vat-image-may-hang-the-listing - implement exactly what it describes." From backlog item iso-plug-in-a-cut-udf-vat-image-may-hang-the-listing.

## Clarifications

### Session 2026-10-31

- Q: Which message should a file get that holds no sector of the partition, and which one a file that holds a few partition sectors without the VAT? → A: no partition sector - "Error reading virtual allocation table" at once (no fallback); some partition sectors - they are searched, and without a VAT among them feature 358's "Missing virtual allocation table." (autonomous run: item)
- Q: Should the fix also count a raw dump's sectors in its real sector size (2352 bytes), so that whole raw VAT images open? → A: no - a separate defect, recorded as an Inbox item; this feature only makes the search end (autonomous run: rule - scope, stop-rules 2.11)
- Q: Should the first search window (around the partition's claimed end), which can also wrap when the claimed length is under 7 sectors, be changed? → A: no - it is read once and bounded (at most 14 reads); only the fallback could repeat (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Opening a cut VAT image does not hang the program (Priority: P1)

A user has a disc image of a sequentially written medium (CD-R, DVD-R, BD-R in UDF with a virtual allocation
table, VAT) whose file was cut short - a truncated download or copy - so that it ends before or shortly after
the start of its UDF partition. The user presses Enter on it in a panel, or unpacks it whole (Alt+F9). Today,
when the image is a raw sector dump (2352-byte sectors) cut that way, Tandem Commander stops answering for
ever while the ISO plug-in looks for the VAT, and has to be killed - the user's other work in it is lost. After
the fix the plug-in reports that the table cannot be read, the image does not open, and the program keeps
running.

**Why this priority**: a hang that loses the user's other work - the item's whole point.

**Independent Test**: probe `iso359_probe` rows L-RAWCUT (Enter) and R-RAWCUT (Unpack with "Delete archive
after unpacking") on the hidden desktop.

**Acceptance Scenarios**:

1. **Given** a raw Mode 1 dump of an mkudffs cdr image cut to 260 sectors whose partition starts at sector 288
   (past the file's end), **When** the user presses Enter on it, **Then** within 30 s only the box "Error reading
   virtual allocation table ..." appears and the program answers.
2. **Given** the same image, **When** the user unpacks it whole with "Delete archive after unpacking", **Then**
   only the read-error box appears, nothing is extracted and the image is kept.

---

### User Story 2 - A 2048-byte image cut near its partition start ends at once (Priority: P1)

The item's own row: an mkudffs cdr image (2048-byte sectors) cut to its partition start + 3 sectors, and one cut
exactly at its partition start. Both must be answered at once: the program stays alive, the image is kept. A
file that holds no sector of the partition shows "Error reading virtual allocation table"; a file that holds a
few partition sectors without the VAT shows "Missing virtual allocation table." (feature 358).

**Why this priority**: the case the item names; it must stay bounded.

**Independent Test**: probe rows L-CUT3, R-CUT3, L-CUT0.

**Acceptance Scenarios**:

1. **Given** the image cut to partition start + 3 sectors, **When** listed (Enter) or unpacked whole, **Then**
   the program answers, only the "Missing virtual allocation table." box appears, the image is kept.
2. **Given** the image cut at its partition start (no partition sector in the file), **When** listed, **Then**
   only the "Error reading virtual allocation table" box appears.

---

### User Story 3 - Whole VAT images open as before (Priority: P2)

A plain mkudffs cdr image, whose VAT is in its last sector, lists as today (no window). The other rows of
features 356 and 358 stay as they are.

**Why this priority**: no regression of the readable case.

**Independent Test**: probe row L-MKCDR; probe 358 (40 rows) re-run.

**Acceptance Scenarios**:

1. **Given** mk_cdr.img, **When** listed, **Then** no window appears and the archive opens.

### Edge Cases

- The file ends at or before the partition start: no fallback window, the read error at once.
- The failed sector lies within 7 sectors past the file's last partition sector: no fallback (the window would
  hold nothing new), the read error - as before.
- The fallback window's own reads fail (a raw dump, whose sectors the plug-in counts in 2048 bytes): the search
  ends with the read error after that one window, never repeats it.
- Very large files (over 2^32 sectors counted): the count is not cut to 32 bits before the comparison.
- A raw Mode 1 dump of a whole VAT volume does not open ("Error reading virtual allocation table"), because the
  plug-in counts the file's sectors in 2048 bytes - unchanged by this feature (separate Inbox item).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The VAT search MUST end for every file size and every outcome of its reads: the fallback to the
  file's last sectors is taken at most once per search.
- **FR-002**: The fallback window MUST be computed without wrapping: its first sector is the file's last
  partition sector count less 7, but not below 0; its end is that count.
- **FR-003**: When the file ends at or before the partition start (no partition sector in the file), the
  fallback MUST NOT be taken; the search ends with "Error reading virtual allocation table" (the volume does not
  open, feature 358's state).
- **FR-004**: The fallback condition MUST keep today's meaning where it did not wrap: taken only when the failed
  sector lies more than 7 sectors past the file's partition sectors.
- **FR-007** (review 1): the fallback MUST be decided in the track's own sectors - for a track of a later session
  (whose partition start is a disc address past the track's sectors) the track's last 7 sectors are searched
  as before, where the VAT of such a track is.
- **FR-005**: The decision of FR-001 to FR-004 and FR-007 MUST be a pure rule in `src/common/salisoudfvat.h` checked by
  `saltests`.
- **FR-006**: No UI string, dialog or message changes; VAT images whose VAT is found list and unpack as before.

### Key Entities

- **VAT search window**: the partition sectors the reader looks at for the VAT's file entry - first around the
  partition's claimed end, then (once) the file's last 7 partition sectors.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The hang rows L-RAWCUT and R-RAWCUT go from FAIL (main window not answering, killed) to PASS
  (answers, only the read-error box, image kept).
- **SC-002**: L-CUT0 goes from "Missing virtual allocation table." to "Error reading virtual allocation table";
  L-CUT3, R-CUT3, L-RAWFULL, L-MKCDR stay PASS; probe 358 stays 40 / 0.
- **SC-003**: `saltests` passes with the new checks; a mutant that drops the at-most-once guard or computes the
  window in 32 bits fails them.

## Assumptions

- Assumption (autonomous run): the item's stated trigger (a 2048-byte image ending fewer than 7 sectors after
  the partition start) was measured not to hang at 13bcb6a1 (the wrapped window ends the loop at once); the
  hang is reached through a failed read at a fallback sector below 7, measured with a raw Mode 1 dump. The fix
  covers both by the item's own Expected (at most once, no wrap).
- Assumption (autonomous run): "a file too short for the partition" means a file that holds no sector of the
  partition; a file that holds some partition sectors is searched there and, without a VAT among them, shows
  feature 358's "Missing virtual allocation table." (conservative: both are existing messages, the volume does
  not open either way).
- Assumption (autonomous run): counting a raw dump's sectors in its real sector size (2352 bytes) - which would
  let such images open - is a separate defect, recorded as an Inbox item (scope).
- Assumption (autonomous run): the first window around the partition's claimed end is left as it is (it is
  bounded; only the fallback could repeat).
- The ISO plug-in (`uniso`) is enabled in the default build; the fix changes only `udf.cpp`, the pure header
  and `saltests`.
