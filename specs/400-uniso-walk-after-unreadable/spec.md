# Feature Specification: After a folder that cannot be read, the ISO plug-in still lists the later folders of the image

**Feature Branch**: `400-uniso-walk-after-unreadable`  
**Created**: 2026-11-02  
**Status**: Draft  
**Input**: Backlog item `iso-plug-in-after-a-folder-that-cannot-be-read-no-later` - "ISO plug-in: after a folder that cannot be read, no later folder of the image is listed". From backlog item iso-plug-in-after-a-folder-that-cannot-be-read-no-later.

## Background (traced and measured at aaf95b94)

When the ISO plug-in (`uniso`, on in the default build) cannot read one folder of a disc image - its
directory lies past the end of the image, a record of it fails the plug-in's safety checks, a UDF
directory starts with an invalid tag, an ISO 9660 folder has length 0 - it shows (or, for some cases,
does not show) "Error reading directory structure ... Incomplete content of ISO image" and from then on
descends into **no later folder** of that file system's walk (ISO 9660, UDF, Xbox): every later folder
is listed empty, its files cannot be viewed, copied or extracted. Feature 330 marked such a listing
incomplete (a whole unpack fails and "Delete archive after unpacking" keeps the image) but kept the
walk as it was.

Measured on the Debug build at aaf95b94 with feature 330's probe (`iso330_probe.ps1 -Only
RD-EXT,RD-REC,UD-EXT,UD-TAG,XD-EXT`, hidden desktop; tree `a/side.txt`, `top.txt`, `zlast/z.txt`,
folder `a` damaged): every row extracts only `top.txt` from the damaged file system - `zlast/z.txt`
is readable but never listed; one box is shown; the image is kept.

By reading the code: the walks of the three readers descend a listed folder only while nothing in the
directory and below it has failed so far, and a failure anywhere below is passed up to every ancestor.
The ISO 9660 walk meets each directory once (feature 328's visited set); the UDF and Xbox walks have
no such set - their only bound is the panel's path-length limit, and for a crafted folder that refers
to itself (or to an ancestor) more than once the early stop after a failure was what ended some of
those walks.

## Clarifications

### Session 2026-11-02

- Q: How many error boxes does a listing with several damaged folders show? → A: at most one box per
  file system walk (the first failure's text, as today); later failures of the same walk are silent
  and still mark the listing incomplete (autonomous run: item - *Expected* leaves "once per damaged
  folder" or "once per listing" to the spec, *Notes* "must keep a crafted image from ... flooding
  boxes"; conservative - today's box count for one damaged folder is kept)
- Q: Inside the damaged folder itself, does the walk go on after a record that fails the safety
  checks? → A: no - that folder's walk ends at the bad record as today (its later records cannot be
  located safely); the walk goes on with the parent's next records and later folders (autonomous run:
  conservative - the item's *Expected* "every readable file is listed" is reached for every folder
  that can be read; a damaged directory's tail is not trusted)
- Q: Does out of memory (the reader could not hold a directory, a name or an entry) also let later
  folders be descended? → A: no - it still ends every later descent of the walk, as today (the files
  of the directories already open are still listed, as today); an entry the core refuses after the
  listing's rule took it keeps feature 328 / 329's handling (left out, the listing marked, the walk
  goes on, its box unchanged) (autonomous run: conservative - out of memory is not "a folder that
  cannot be read", and going on would repeat the failure in every later folder)
- Q: How is a crafted image kept from looping once later folders are descended? → A: each walk of the
  UDF and Xbox readers meets every directory once, as feature 328's ISO 9660 walk does; a directory
  met again is listed as an empty folder, without a box and without marking the listing (feature
  328's rule) (autonomous run: item - *Notes* "A fix must keep a crafted image from looping"; 328's
  rule reused)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Later folders of a damaged image are listed (Priority: P1)

A user opens (or unpacks) a disc image one of whose folders cannot be read. Today, every folder after
the damaged one is shown empty and its files cannot be viewed or extracted. Now every folder that can
be read is listed with its files - before and after the damaged one - the damaged folder shows what
could be read of it, the error box is shown once, and the listing stays marked incomplete (a whole
unpack with "Delete archive after unpacking" still keeps the image, feature 330).

**Why this priority**: it is the item - readable files of a damaged image are unreachable today.

**Independent Test**: probe Unpack rows of 330's damaged images (ISO 9660 folder past the end, an ISO
9660 record failing the safety checks, an ISO 9660 folder of length 0, a UDF folder past the end, a
UDF folder with an invalid tag, an Xbox folder past the end): `top.txt` **and** `zlast/z.txt` of the
damaged file system extracted, the box (or none, as before) shown once, the image kept.

**Acceptance Scenarios**:

1. **Given** an ISO 9660 image whose folder `a`'s directory lies past the end of the image, **When**
   it is unpacked whole with "Delete archive after unpacking", **Then** `top.txt` and `zlast/z.txt`
   are extracted, one "Error reading directory structure" box is shown, and the image is kept.
2. **Given** an ISO 9660 image where a record of folder `a` fails the safety checks, **When** unpacked
   the same way, **Then** `top.txt` and `zlast/z.txt` are extracted, one box, the image kept.
3. **Given** the UDF part of a hybrid whose folder `a`'s directory lies past the end (or starts with
   an invalid tag), **When** unpacked the same way, **Then** the UDF part's `top.txt` and
   `zlast/z.txt` are extracted with the ISO 9660 part's three files, one box, the image kept.
4. **Given** an Xbox image whose folder `a` starts past the end, **When** unpacked the same way,
   **Then** `top.txt` and `zlast/z.txt` are extracted, one box, the image kept.
5. **Given** an ISO 9660 image whose folder `a` has length 0, **When** unpacked the same way,
   **Then** `top.txt` and `zlast/z.txt` are extracted, no box (as before), the image kept.

---

### User Story 2 - Several damaged folders show one box (Priority: P2)

A damaged or crafted image holds several folders that cannot be read. The user sees one error box for
the walk - not one per folder - and every readable folder is still listed.

**Why this priority**: the item's *Notes* - once later folders are descended, every damaged folder
would otherwise show its own box (a crafted image could hold thousands).

**Independent Test**: probe rows of images with two or more damaged folders before and between
readable ones (ISO 9660, Xbox): one box, every readable file extracted, the image kept.

**Acceptance Scenarios**:

1. **Given** an image with damaged folders `a` and `b` and readable folder `zlast`, **When** it is
   unpacked whole, **Then** exactly one error box is shown, `top.txt` and `zlast/z.txt` are
   extracted, and the image is kept.

---

### User Story 3 - A crafted folder loop still ends (Priority: P2)

A crafted image whose folders refer back to themselves or to an ancestor - with and without a damaged
folder among them - still opens in seconds and lists each directory once; the ISO 9660 loops of
feature 328 behave as before.

**Why this priority**: the item's *Notes* - the early stop after a failure ended some crafted walks;
descending later folders must not turn them into an endless or exponential walk.

**Independent Test**: probe rows of crafted Xbox (and, where the image can be built, UDF) images
whose folder lists itself twice next to a damaged folder: the listing opens within the row's time
limit, the program answers, one box at most; feature 328's LOOP rows still pass.

**Acceptance Scenarios**:

1. **Given** an Xbox image whose folder `a` contains two entries pointing back to `a` and a damaged
   folder, **When** it is opened, **Then** the listing appears within the probe's time limit, the
   program answers, and at most one error box is shown.
2. **Given** feature 328's crafted ISO 9660 / Joliet loops, **When** opened, **Then** they behave as
   in 328's probe (LOOP rows pass).

### Edge Cases

- The root directory cannot be read: nothing of that file system is listed, as before (one box).
- A damaged folder is the last record: nothing changes for the walk (there is nothing later).
- Out of memory: later descents stop as before; one box at most.
- A directory met again in the same walk: listed as an empty folder, no box, the listing not marked
  (feature 328's rule, now also for UDF and Xbox).
- Feature 328's fit check and count walks of the ISO 9660 reader (quiet walks that decide Rock Ridge
  names): they follow the same descent rule and stay quiet; their failures do not count as the
  listing walk's box.
- A hybrid image whose ISO 9660 and UDF parts are both damaged: one box per file system walk (two
  boxes), as before.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After a folder that cannot be read (read error, a record that fails the safety checks,
  an invalid UDF tag, an ISO 9660 folder of length 0), the ISO 9660, UDF and Xbox walks MUST go on
  with the parent directory's next records and descend every later listed folder.
- **FR-002**: The listing MUST stay marked incomplete whenever any folder of the walk could not be
  read (feature 330): a whole unpack fails and "Delete archive after unpacking" keeps the image.
- **FR-003**: A walk MUST show at most one error box for failures met inside its folder walk; later
  failures of the same walk are silent but mark the listing incomplete.
- **FR-004**: Out of memory MUST still end every later descent of the walk (unchanged); the box rule
  of FR-003 applies to its box too. An entry the core refuses after the listing's rule took it keeps
  its feature 328 / 329 handling and box.
- **FR-005**: The UDF and Xbox walks MUST walk each directory at most once per walk; a directory met
  again is listed as an empty folder without a box and without marking the listing (feature 328's
  rule for ISO 9660).
- **FR-006**: Images without a damaged folder MUST list exactly as before (same entries, no box).
- **FR-007**: No new UI string; the existing messages are unchanged.
- **FR-008**: The descent and box rules MUST be pure decisions in a header under `src/common/` with
  `saltests` checks that fail for the old rule (descend only while nothing failed).

### Key Entities

- **Walk state**: per walk of one file system - whether the walk was stopped by out of memory (no
  later descent), whether its error box was already shown, and the directories met.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: For each of 330's damaged images (RD-EXT, RD-REC, RD-ZERO, UD-EXT, UD-TAG, XD-EXT), the
  readable file `zlast/z.txt` of the damaged file system is extracted (0 of 6 rows before, 6 of 6
  after), the image is kept, and the box is shown as before (once, or not at all).
- **SC-002**: An image with two damaged folders shows exactly one error box and extracts every
  readable file.
- **SC-003**: A crafted Xbox folder loop with a damaged folder opens within the probe's 30-second
  answer limit; feature 328's LOOP rows and 330's control rows still pass.
- **SC-004**: `saltests` checks of the descent and box rules pass, and a mutant restoring the old
  rule fails at least one of them.

## Assumptions

- Assumption (autonomous run): the box text is the first failure's message, as today; no summary box
  is added (FR-007, no new UI string).
- Assumption (autonomous run): HFS+ is out of scope - its catalog walk is not a folder descent and
  has its own Inbox items (322, 329, 330's leftovers).
- Assumption (autonomous run): an ISO 9660 multi-extent chain (feature 368) and Rock Ridge decisions
  (328) are unchanged; they only see more folders.
- Assumption (autonomous run): a UDF crafted loop image is built only if the probe's image maker can
  do it without a UDF writer; otherwise the UDF visited set is proven by `saltests` and code review
  and the row is recorded in `fix-log.md`.
