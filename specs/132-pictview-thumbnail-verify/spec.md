# Feature Specification: PictView's Update Thumbnail keeps the picture

**Feature Branch**: `132-pictview-thumbnail-verify`
**Created**: 2026-10-13
**Status**: Implemented
**Input**: The maintainer: "do all four, one after another" - point 1 of the recommendation
after feature 131: "PictView and a damaged JPEG: the library for Exif writes only the part of a
malformed file it parsed, reports success, and Update Thumbnail replaces the original by it.
Not measured, only read; reproduce first."

## What the measurement found (before any fix)

1. **The library does lose data and calls it success** (`probe/exifdll_result_before_v019.txt`,
   EXIF.DLL of 0.1.9 called directly): the XMP block of every file is replaced by an empty Exif
   block (three shapes of file); a file with more fill bytes than the library reads is written
   as its first 1,036 bytes; an Exif block that no longer fits 64 KB is written with a wrapped
   length (the file does not decode); a file whose data behind the picture end with `FF 00`
   loses its last two bytes.
2. **None of it can happen in the program today**: Update Thumbnail has not worked in any
   release since feature 006 - the built-in engine refuses to make the small JPEG picture
   ("Unable to save the image. This operation is not supported by the built-in image engine."),
   so the library is never called (`specs/NEXT-WORK.md`, functional item 7; probe, first run).
   The premise "far more files reach that stage since 131" was wrong.

So the feature is: make the command work (it is in the menu and does nothing), and make it
unable to lose anything - the second is the condition for the first.

## User Scenarios & Testing

### User Story 1 - Update Thumbnail works (Priority: P1)

The user selects JPEG files and runs Plugins > PictView > Update Thumbnail. Each file gets a
fresh thumbnail in its Exif block (or a JFXX thumbnail when it has no Exif and the user agrees).

**Independent Test**: probe row CTRL / EXIF / ACCENT - the file is another file afterwards, ends
with all the original's bytes from the picture data on, and a 160 x 120 thumbnail is inside.

**Acceptance Scenarios**:

1. **Given** a JPEG file with Exif, **When** Update Thumbnail runs, **Then** the file has a new
   Exif thumbnail and the question about a missing Exif block is not asked.
2. **Given** a JPEG file without Exif, **When** the user answers Yes to the JFXX question,
   **Then** the file has a JFXX thumbnail.
3. **Given** a file in a folder with accented letters, **Then** the same (row owed by 131).

### User Story 2 - Nothing but the thumbnail changes (Priority: P1)

Whatever the file holds besides the thumbnail - the picture, the XMP block, colour profile,
comments, data behind the picture (motion photo, depth map) - is there afterwards byte for byte.

**Independent Test**: rows XMP, XMPONLY, TRAILER: the planted marks are in the file afterwards.

### User Story 3 - A file the command cannot update safely is left alone (Priority: P1)

When the new file would not be the original with a new thumbnail, the original stays untouched,
the temporary file is removed and the user is told.

**Independent Test**: rows FILL8 and BIGEXIF: the file is byte for byte the original and the
message "Unable to create a file with the new thumbnail ... remains unmodified" is shown; the
same rows with the EXIF.DLL of 0.1.9 beside the new plug-in (the plug-in's own check alone).

### Edge Cases

- A file cut inside the picture data (no end marker): updated, all its bytes kept.
- A file that is not understood at all (no start marker, no picture data): refused.
- More than one APP1 block, XMP before Exif.
- Low memory while reading the two files for the check: refused (not everything checked = no).

## Requirements

- **FR-001**: Update Thumbnail MUST produce the thumbnail picture and reach the library.
- **FR-002**: The original file MUST be replaced only when the new file equals it except for
  the thumbnail's own blocks (Exif APP1, JFXX APP0); the check is independent of the library
  that wrote the file and fails closed.
- **FR-003**: The library MUST keep every APP1 block that is not Exif, MUST refuse to save data
  it did not read whole or a block that does not fit a segment, and MUST keep the last bytes of
  the file.
- **FR-004**: The question "this file does not contain EXIF data" MUST be asked only for a file
  without an Exif block.
- **FR-005**: No new texts for translation; no change of the plug-in interface.

## Success Criteria

- **SC-001**: Probe on the new build: every row passes; no row ends with a changed picture, a
  lost block or a leftover temporary file.
- **SC-002**: The same probe with the old library beside the new plug-in: the files the old
  library spoils stay byte for byte the originals.
- **SC-003**: The library measurement reports no loss as success.
- **SC-004**: Unit checks of the rule pass; regression probes of PictView (105, 111, 120) and
  of 130 pass.

## Assumptions

- The Exif tags themselves are rewritten by the library (as before feature 006); their content
  is not compared (the rule compares everything else).
- A dedicated sentence for "not updated: the file would lose data" needs a new string; the
  existing "Unable to create a file with the new thumbnail ..." is used.
