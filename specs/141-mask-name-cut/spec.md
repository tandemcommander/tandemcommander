# Feature Specification: A name built from a mask is never cut

**Feature Branch**: `141-mask-name-cut`
**Created**: 2026-10-14
**Status**: Draft
**Input**: The maintainer: "queue the medium and critical problems you meet and fix them through
the Spec Kit flow." The final cross-feature review (2026-10-13) found:

- **medium**: renaming a file in place in a disk panel cuts the new name at 519 bytes without a
  word (feature 137 widened the edit line's buffer; the buffer the name is then built in is
  still `2 * MAX_PATH`). A Windows name may be 255 characters = up to 765 bytes of UTF-8.
- **medium**: the FTP client's automatic rename on **upload** still shortens a name at a byte
  position (137 repaired the download direction only; `specs/NEXT-WORK.md` struck the item
  wrongly).

Reading the code for this feature found the same buffer rule in the routine that builds the
target names of Copy and Move on disks (`2 * MAX_PATH + 200` = 719 bytes): to be measured -
a file whose name has 240 to 255 three-byte letters would be copied under a cut name.

## User Scenarios & Testing

### User Story 1 - Copy, Move and Rename keep the whole name (Priority: P1)

A file or directory whose name is long in UTF-8 (up to the 255 characters Windows allows, in
any script) is copied, moved and renamed under exactly the name the user sees or types. If a
name cannot be used, the operation says so; it never proceeds with a shortened name.

**Why this priority**: a silently shortened name is another file: it can collide with an
existing one, and a name cut inside a letter is not the name of anything.

**Independent Test**: a file named with 250 CJK letters (750 bytes): F5 to another folder -
the copy has the same name; F6 likewise; Quick Rename and the in-place rename line to a name
of 250 CJK letters - the file has exactly that name; a name of 256 letters is refused with the
"name too long" message and the file keeps its name.

**Acceptance Scenarios**:

1. **Given** a file with a 250-letter CJK name, **When** it is copied with the default mask,
   **Then** the target has the identical name.
2. **Given** a mask that makes the name longer than the file system allows, **Then** the
   operation reports the name as too long (the existing message) and does not create a file
   under another name.
3. **Given** the in-place rename line and a typed name of 200 CJK letters, **Then** the file
   has exactly that name.

### User Story 2 - FTP: an automatically renamed upload is shortened at a whole letter (Priority: P2)

When the FTP client renames an uploaded file automatically ("name (2)") and must shorten the
name to fit the server's limit, it cuts at a whole character; if nothing of the name would be
left, the upload of that file fails with the existing "name too long" error.

**Independent Test**: unit checks of the shortening rule for every server type the routine
knows; the AUTOREN row of the FTP probe for the upload direction where the test server allows.

### Edge Cases

- A mask with `?` and literal characters applied to a name of multi-byte letters (the mask
  works on bytes today - recorded, not changed here unless it produces invalid text).
- Plug-ins calling the core's `MaskName` service with their own buffers (FTP, PictView,
  the demo plug-in).
- A directory name; a name ending exactly at the buffer's edge.

## Requirements

- **FR-001**: No route of Copy, Move, Quick Rename or in-place rename in a disk panel MUST use
  a name that is a cut form of the name the mask produces; a name that does not fit MUST be
  refused with the existing message.
- **FR-002**: Every name Windows can store (255 UTF-16 units) MUST pass these routes unchanged
  with the default mask.
- **FR-003**: The FTP client's automatic rename on upload MUST shorten at a whole character or
  fail the item.
- **FR-004**: The plug-in interface is unchanged (`MaskName` keeps its signature and its
  behaviour for callers that pass a sufficient buffer); no new texts for translation.

## Success Criteria

- **SC-001**: The probe rows (copy, move, both renames with 250-letter names; a refused
  256-letter name) pass on the fixed build; the 0.1.9 build shows what it did.
- **SC-002**: `saltests` covers the rule that tells a complete mask result from a cut one.

## Assumptions

- Measure first: a route that turns out not to cut (a guard elsewhere) is recorded as such and
  left alone.
