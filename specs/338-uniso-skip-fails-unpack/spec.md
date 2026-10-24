# Feature Specification: ISO plug-in - a whole unpack with a skipped file keeps the image

**Feature Branch**: `338-uniso-skip-fails-unpack`
**Created**: 2026-10-24
**Status**: Draft
**Input**: Backlog item `iso-plug-in-a-whole-unpack-counts-a-skipped-file-as-success` (`backlog/items/iso-plug-in-a-whole-unpack-counts-a-skipped-file-as-success/desc.md`) - "ISO plug-in: a whole unpack counts a skipped file as success and deletes the image". From backlog item iso-plug-in-a-whole-unpack-counts-a-skipped-file-as-success.

## Background (measured at 0cec8e25)

Unpack (Alt+F9) of a whole disc image with "Delete archive after unpacking" reported success whenever the
user did not press Cancel. A hidden-desktop probe (`probe/iso338_probe.ps1`) on the Debug build of `main`
showed the image deleted in every row where a file of the image was not extracted:

| Row | What happens | Image at HEAD |
|---|---|---|
| OK (control) | intact image, every file extracted | deleted (right) |
| R-SKIP | a file's data cannot be read, "Cannot read sector" answered Skip | **deleted** - the file's only copy lost |
| R-SKIPALL | two unreadable files, the first box answered Skip all, the second error is silent | **deleted** |
| C-SKIP | the target holds a folder of the file's name, "Error Creating File" answered Skip | **deleted** |
| O-SKIP | the target holds the user's own file of that name, the overwrite question answered Skip | **deleted** |
| O-YES (control) | the same, answered Yes | deleted (right: the image's file was extracted) |
| TWINS | two listed files of one name (a damaged or crafted directory); the overwrite question for the second answered Yes | **deleted** - the first file's content lost |
| D-SKIP | the target holds a file of a folder's name; the folder cannot be created, its file is skipped | **deleted** |

## Clarifications

### Session 2026-10-24

- Q: Does Skip in the overwrite question for a file the user already had in the target fail the whole unpack? → A: Yes - the image's file was not extracted; the user's file stays (autonomous run: item - *Expected* "any file was skipped")
- Q: How is a file written twice by one unpack told from the user's own file of the same name? → A: By the file system's identity of the files this unpack wrote (volume + file id, `salsamefile.h`); where an identity cannot be read the check fails closed (autonomous run: rule - CLAUDE.md "Same-file decisions go by identity, not by name")
- Q: Does a kept image get a new message saying why? → A: No - each skip already showed its box; a summary message is the related item's subject (autonomous run: conservative)
- Q: Do Copy (F5) out of an opened image and the extraction of one file change their results? → A: No - only the whole unpack, which is the route that deletes the image (autonomous run: conservative)
- Q: Does the twin check change what is asked or written (e.g. refuse the second write)? → A: No - the questions and writes stay as they are; only the unpack's result changes (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A skipped file keeps the image (Priority: P1)

A user unpacks a whole disc image with "Delete archive after unpacking". One file cannot be read (a
damaged sector, data the image stores only in part) or cannot be created in the target folder; the program
asks "Skip / Skip all / Cancel" and the user chooses Skip (or Skip all). The rest of the image is
extracted, the unpack ends as failed, and the image stays on disk - the skipped file can still be
recovered from it.

**Why this priority**: it is the item's main point - the image is deleted with the only copy of the skipped
file.

**Independent Test**: probe rows R-SKIP, R-SKIPALL, C-SKIP, O-SKIP: the other files are extracted, the image
is kept; row OK (control): an intact image is still deleted.

**Acceptance Scenarios**:

1. **Given** an image one of whose files cannot be read, **When** the user unpacks it whole with "Delete
   archive after unpacking" and answers Skip in the read-error box, **Then** every other file is extracted
   and the image is kept.
2. **Given** an image with two unreadable files, **When** the user answers Skip all at the first read error,
   **Then** the second unreadable file is skipped without a box, every other file is extracted, and the
   image is kept.
3. **Given** a target in which a file of the image cannot be created (a folder of the same name), **When**
   the user answers Skip in "Error Creating File", **Then** the other files are extracted and the image is
   kept.
4. **Given** a target holding the user's own file of the same name, **When** the user answers Skip in the
   overwrite question, **Then** the user's file stays unchanged, the other files are extracted and the image
   is kept; answered Yes, the user's file is replaced and the image is deleted as before.
5. **Given** an intact image and an empty target, **When** it is unpacked whole, **Then** every file is
   extracted, no window appears and the image is deleted as before.

---

### User Story 2 - A folder that cannot be created keeps the image (Priority: P2)

A folder of the image cannot be created in the target (a file of that name is there). Its contents cannot
be extracted; the unpack ends as failed and the image is kept.

**Why this priority**: the same loss through another route (the folder's files are skipped); the folder
step's own failure was ignored too.

**Independent Test**: probe row D-SKIP.

**Acceptance Scenarios**:

1. **Given** a target holding a file named like a folder of the image, **When** the image is unpacked whole
   and the boxes are answered, **Then** the other files are extracted, the user's file is unchanged, and the
   image is kept.

---

### User Story 3 - Two listed files of one name keep the image (Priority: P3)

A damaged or crafted directory lists two files that land on one file in the target (the same name, names
that differ only in case, names made the same by cleaning). The second overwrites the first - after the
overwrite question, or silently when the user switched that question off. The unpack ends as failed and the
image is kept, since one of the two files now exists only in the image.

**Why this priority**: crafted or damaged images only; the item names it as a second route to the same loss.

**Independent Test**: probe row TWINS.

**Acceptance Scenarios**:

1. **Given** an image listing two files of one name, **When** it is unpacked whole and the overwrite question
   for the second is answered Yes, **Then** the image is kept.
2. **Given** a target holding the user's own file of that name (not written by this unpack), **When** the
   overwrite is answered Yes, **Then** the image is deleted as before (row O-YES).

### Edge Cases

- A file that is skipped after Skip all - no box is shown for it, it still counts as not extracted.
- A read error met while an earlier answer of an overwrite or creation box set a "do the same for all"
  choice: no read-error box is shown (old behaviour, kept); the file still counts as not extracted.
- Cancel: the unpack stops and fails as before.
- An audio track entry (never extracted by the plug-in): counts as not extracted (the listing already marks
  such images since feature 334 - unchanged outcome).
- An HFS+ file whose stored extents end before its size, or a listed HFS+ entry that is not a file record:
  counts as not extracted (the partial file is removed as for a read error).
- A file excluded by the Unpack dialog's mask is not asked for and does not count.
- The identity of a written file cannot be read (no file id on the target volume, low memory): an existing
  target met later counts as a possible twin (fails closed - the image is kept).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A whole unpack MUST end as failed (so "Delete archive after unpacking" keeps the image) when
  any file it was asked for was not extracted whole: skipped after a read error (Skip, Skip all, or a silent
  skip), skipped or refused at creation (Skip in any creation or overwrite box), cut short by an error, an
  audio entry, or a file the reader cannot extract.
- **FR-002**: A whole unpack MUST end as failed when a folder of the image could not be created in the target.
- **FR-003**: A whole unpack MUST end as failed when a file it writes lands on a file that the same unpack
  already wrote (decided by the file system's identity of the files, not by their names); a target file
  that existed before the unpack and is replaced on the user's answer MUST NOT fail it - except where the
  identities cannot be read or remembered (see Edge Cases: then it fails closed and the image is kept). The overwrite
  question and the write itself stay as they are - only the unpack's result changes.
- **FR-004**: Each file system reader of the plug-in MUST report a file whose extraction ended without all
  its data as not extracted, also when no box was shown for its read error.
- **FR-005**: Every file that could be extracted MUST still be extracted (the unpack goes on after a skip as
  before); the boxes, their buttons and texts MUST stay as they are; no new message and no new UI string.
- **FR-006**: An intact image unpacked into a target without conflicting entries MUST still be unpacked and
  deleted exactly as before (row OK).
- **FR-007**: Copy (F5) out of an opened image and the extraction of one file MUST keep their present
  results (they never delete the image).

### Key Entities

- **Whole unpack result**: success only when every asked-for file and folder was extracted whole, no written
  file was written over by the same unpack, the user did not cancel, and the listing was complete
  (features 328 - 337).
- **Files written by this unpack**: the identities (volume + file id) of the files the unpack wrote, used to
  tell a twin from the user's own file.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `iso338_probe`: all 8 rows pass after the change (6 of them deleted the image before -
  10 PASS / 6 FAIL at 0cec8e25).
- **SC-002**: The probe's controls OK and O-YES still delete the image.
- **SC-003**: The ISO probes of features 330 and 337 keep their results (no row changes verdict).
- **SC-004**: The pure rules have unit checks that fail when the rule is reverted (negative control).

## Assumptions

- Assumption (autonomous run): Skip in the overwrite question of a file the user already had in the target
  fails the unpack too - the item's *Expected* says "any file was skipped"; 7-Zip (087) and TAR (308 / 309)
  fail an operation that leaves an asked-for member unextracted.
- Assumption (autonomous run): no message is added - why a kept image was kept is the subject of the related
  item `iso-plug-in-a-whole-unpack-of-an-image-with-audio-or-left` (a UI string with its `.slt` refresh);
  each skip already showed its own box.
- Assumption (autonomous run): the fix belongs to the ISO plug-in; the core's rule (delete only after a
  successful whole unpack) is right, the plug-in reported success wrongly. Other plug-ins are not changed
  here.
- Assumption (autonomous run): a twin is decided by the identity of the files this unpack wrote
  (`salsamefile.h`, as SFTP 139); where identities cannot be read, the check fails closed.
- The core's listing keeps two files of one name (`CSalamanderDirectory::AddFile` has no duplicate check -
  measured by row TWINS: both were extracted, the second over the first).
