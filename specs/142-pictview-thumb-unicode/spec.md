# Feature Specification: PictView - Update Thumbnail and Exif information for any file name

**Feature Branch**: `142-pictview-thumb-unicode`
**Created**: 2026-10-14
**Status**: Draft
**Input**: The maintainer: "queue the medium and critical problems you meet and fix them through
the Spec Kit flow." The final independent review of PictView's Update Thumbnail (2026-10-13)
found:

- **medium**: a JPEG whose name (or folder) has letters outside the system code page cannot
  get its thumbnail updated when the volume keeps no short (8.3) names - the default for
  every volume but the system one on current Windows. The library that rewrites the Exif data
  takes code-page paths only. Each such file then shows the box "Unable to create a file with
  the new thumbnail. Disk full? ..." with OK only - one box per file of a selection, and the
  text names a cause that is not the cause.
- **low, same place**: "Skip all" is not honoured for this error; a file made writable for an
  agreed replace of a read-only file does not get its read-only attribute back.
- **medium (public claim)**: `PRIVACY.md` names the temporary file of *Save As* but not the
  one *Update Thumbnail* writes next to the picture.

## User Scenarios & Testing

### User Story 1 - Update Thumbnail works for every file name (Priority: P1)

A photo named in any script - Japanese, Greek, an emoji - in a folder named likewise, on any
volume, gets its Exif thumbnail updated like a file with an English name. The Exif data are
kept as feature 135 keeps them.

**Why this priority**: photos named by phones and cameras' apps in the user's language are the
ordinary case in most of the world; the command simply did not work for them on a data disk.

**Independent Test**: on a volume without short names: a camera JPEG named with Japanese
letters in a folder named with Greek letters; Update Thumbnail; the file's thumbnail is the new
one, everything else in the file is byte-identical (the checker of 132 / 135).

**Acceptance Scenarios**:

1. **Given** a name outside the system code page and no short name, **When** the thumbnail is
   updated, **Then** it succeeds and the file passes the 135 comparison.
2. **Given** a path longer than 260 characters, **Then** the same.
3. **Given** the Exif information window is opened for such a file, **Then** it shows the data.

### User Story 2 - A failure says what failed, once for a selection (Priority: P2)

When the new thumbnail cannot be written for a file, the message offers Skip / Skip all /
Cancel like the other errors of this command, and does not guess "Disk full?" when the reason
is known to be another.

### User Story 3 - A read-only file stays read-only (Priority: P3)

After the user agreed to update a read-only file, the file has the new thumbnail and is
read-only again.

### Edge Cases

- An older `EXIF.DLL` next to a newer plug-in (a partly updated installation): the plug-in
  falls back to the old interface.
- A name that the old interface could reach (code page, or a short name exists): unchanged.

## Requirements

- **FR-001**: Update Thumbnail MUST work for any file name and folder name Windows can store,
  on any volume, and for long paths.
- **FR-002**: The Exif information window MUST read such files too.
- **FR-003**: A failed thumbnail write MUST be reported through the command's Skip / Skip all /
  Cancel dialog; "Skip all" MUST be honoured.
- **FR-004**: A read-only file updated with the user's consent MUST be read-only afterwards.
- **FR-005**: `PRIVACY.md` MUST name the temporary file Update Thumbnail writes.
- **FR-006**: No new texts for translation; the data-keeping rules of 132 / 135 are unchanged.

## Success Criteria

- **SC-001**: The probe of 132 with files named outside the code page (on a volume without
  short names, or with the short name removed) passes; before the fix it shows the OK-only box.
- **SC-002**: The 82 real camera files of feature 135 still compare "same".

## Assumptions

- The library's old entry points stay exported (nothing else in the tree or outside may depend
  on their absence).
