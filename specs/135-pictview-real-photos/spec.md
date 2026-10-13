# Feature Specification: Update Thumbnail on real camera files keeps their Exif data

**Feature Branch**: `135-pictview-real-photos`
**Created**: 2026-10-13
**Status**: Implemented
**Input**: The maintainer: "fix what you can" - after the answer that named as the first
critical point: "PictView on real photos before the 0.1.10 tag. Update Thumbnail rewrites
users' files again; the picture and the other blocks are compared byte for byte, but the Exif
block itself is rewritten by the old library and is not compared. It was not measured whether
the makers' data (MakerNote of Canon, Nikon, Sony) survive - only synthetic files were used."

## User Scenarios & Testing

### User Story 1 - A photo from a camera keeps everything its Exif block holds (Priority: P1)

The user runs Update Thumbnail on photos straight from a camera or a phone. Afterwards every
piece of information the camera wrote - the standard tags, the maker's own block with lens,
focus and picture-style data, GPS position - reads the same as before; only the small preview
picture is new.

**Why this priority**: it is the one place of the 0.1.10 work where the new version can spoil
something 0.1.9 left alone, on files that cannot be made again.

**Independent Test**: a set of real camera files of several makers (a public sample
collection); for each: the command's library is run, and the Exif block before and after is
compared tag by tag, the maker's block byte by byte and by where its inner references point.

**Acceptance Scenarios**:

1. **Given** a photo with a maker's block whose inner references count from the start of the
   Exif data (Canon, Nikon type 1, Sony, Panasonic ...), **When** the thumbnail is updated,
   **Then** those references still point at the same data.
2. **Given** a photo with GPS and interoperability data, **Then** they read the same.
3. **Given** a file whose Exif block the command cannot rewrite without changing something
   else in it, **Then** the file is left untouched and the user is told (as for any other file
   the command refuses).

### Edge Cases

- Files of the sample set that are deliberately invalid: refused or untouched, never a crash.
- A photo that has no thumbnail yet, one with an uncompressed (TIFF) thumbnail.
- Big-endian and little-endian Exif data.

## Requirements

- **FR-001**: The effect of the command on real camera files MUST be measured before anything
  is changed: per file, which tags and bytes of the Exif block differ afterwards.
- **FR-002**: After the command, every Exif value other than the thumbnail and the tags that
  describe it MUST read the same; a maker's block MUST be usable as before (its bytes the same
  and, where its references count from the start of the Exif data, at the same place).
- **FR-003**: A file for which FR-002 cannot be kept MUST be refused (existing message), not
  rewritten.
- **FR-004**: The rule that decides "the new file may replace the original" (feature 132) MUST
  cover the Exif block too, independently of the library that wrote it.
- **FR-005**: No new texts for translation; no interface change; the sample files are not
  added to the repository (their licence and size) - the probe downloads or is pointed at them.

## Success Criteria

- **SC-001**: For every file of the sample set the outcome is one of: updated with FR-002 kept
  (checked by a reader independent of the library), or refused with the file byte for byte
  unchanged. No file is updated with a lost or damaged value.
- **SC-002**: The numbers are recorded per maker before and after the change.
- **SC-003**: The probes of feature 132 still pass; unit checks pass.

## Assumptions

- The public collection `ianare/exif-samples` (real files of about twenty camera models and
  phones, plus deliberately invalid ones) stands in for "real photos"; the maintainer's own
  files stay untouched.
- An independent reader is the Python library Pillow plus a small TIFF walker of the probe's
  own; `exiftool` is used as a second opinion when it is installed.
