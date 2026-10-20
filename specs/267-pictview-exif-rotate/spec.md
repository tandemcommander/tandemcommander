# Feature Specification: PictView - the Exif dialog and Exif auto-rotation with the built-in engine

**Feature Branch**: `267-pictview-exif-rotate`  
**Created**: 2026-10-20  
**Status**: Draft  
**Input**: User description: "Backlog item pictview-exif-dialog-and-auto-rotation - implement exactly what it describes." From backlog item pictview-exif-dialog-and-auto-rotation.

## Clarifications

### Session 2026-10-20

- Q: Which files does the feature switch on - JPEG only, or also TIFF and camera raw files? →
  A: JPEG files with an Exif block, as the item's *Expected* says. TIFF and raw files keep their
  present behaviour (no Exif command, no automatic turn); recorded as a leftover. (autonomous
  run: item)
- Q: Which turn belongs to which orientation value? → A: The Exif standard's meaning of all
  eight values (2 mirrored left-right, 3 turned half round, 4 mirrored top-bottom, 5 and 7 a
  quarter turn plus a mirror, 6 a quarter turn clockwise, 8 a quarter turn counter-clockwise) -
  the result is what other viewers show for the same file. (autonomous run: item - "turned by
  its orientation tag")
- Q: PictView's old rule "the picture was changed after the camera wrote the block (the
  pixel size recorded in the block differs from the picture's, or the recorded size is
  portrait) - do not turn" - keep it? → A: No - the picture is turned by its tag alone, as the
  item's *Expected* says and as the panel thumbnails already do (feature 064). Measured on the
  real set: the rule would leave 7 of the 14 standard orientation samples (`landscape_5..8`,
  `portrait_2..4`, recorded size portrait) shown wrong; it was a workaround for one camera
  model (Konica Minolta DiMAGE Z3) and for tools that turned the pixels but kept the tag. The
  rule was dead code since feature 006 - no present behaviour changes. (autonomous run: item)
- Q: Update Thumbnail decides "has the file an Exif block?" by feature 132's own file check;
  should it now follow the new engine report instead? → A: No - its decision stays exactly as
  132 made it. (autonomous run: conservative)
- Q: Must detecting the Exif block avoid reading the picture file a second time (it runs for
  every JPEG the engine opens, panel thumbnails included)? → A: Yes - it uses only what the
  system image reader already holds for the opened picture; no second pass over the file and
  nothing for non-JPEG files. (autonomous run: recommended)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A photo is shown the right way up (Priority: P1)

A person opens a photo taken with the camera held upright (the camera stored the picture
sideways and wrote an orientation tag) in PictView. With the setting "auto-rotate" on (the
default) the picture is shown the right way up, as every other viewer shows it.

**Why this priority**: most phone and camera photos taken upright depend on it; today they all
appear lying on their side.

**Independent Test**: open JPEG files with orientation 1..8 and read back what the viewer shows
(its size in the title and a saved copy of the shown image); compare with the file turned by the
standard meaning of the tag.

**Acceptance Scenarios**:

1. **Given** a JPEG with orientation 6 and auto-rotate on, **When** it is opened, **Then** it is
   shown turned a quarter clockwise (a 64 x 48 picture shows as 48 x 64).
2. **Given** JPEGs with orientation 2, 3, 4, 5, 7, 8, **When** each is opened, **Then** each is
   shown as the standard meaning of its tag says.
3. **Given** a JPEG with orientation 1, or without an Exif block, or with an XMP block only,
   **When** it is opened, **Then** it is shown as stored.
4. **Given** auto-rotate off, **When** a JPEG with orientation 6 is opened, **Then** it is shown
   as stored.
5. **Given** a JPEG with orientation 6 whose name holds letters outside the system code page
   (Czech, Japanese), **When** it is opened, **Then** it is turned like any other.

---

### User Story 2 - The Exif command shows the photo's tags (Priority: P2)

A person viewing a JPEG with an Exif block uses File > Exif information (the File menu item, also in
the context menu; the command has no toolbar button). The command is available and its window lists the tags of the file (camera,
date, orientation, ...). For a picture without an Exif block the command stays unavailable.

**Why this priority**: the window exists and works, it is only never offered.

**Independent Test**: give the viewer the Exif command for files with and without an Exif block;
the window opens and lists the tags (among them "Orientation") only for the files with one.

**Acceptance Scenarios**:

1. **Given** a JPEG with an Exif block, **When** the Exif command is given, **Then** the Exif
   window opens and lists the file's tags.
2. **Given** a JPEG without an Exif block (none, or XMP only), **When** the Exif command is
   given, **Then** nothing opens and the command is shown unavailable.
3. **Given** a JPEG with an Exif block under a name outside the system code page, **When** the
   Exif command is given, **Then** the window lists its tags.

---

### Edge Cases

- A JPEG whose orientation tag holds a value outside 1..8, or whose Exif block cannot be read:
  shown as stored; the Exif command follows whether the block was found.
- The recorded pixel size in the block differs from the picture's, is portrait, or is absent:
  turned by the tag all the same (the size is not consulted).
- The shown picture is turned and the person turns or mirrors it further, crops it, saves it:
  the commands work on what is shown, as for a picture turned by hand.
- A picture opened from the clipboard or a scanner (no file): no automatic turn, no Exif command.
- Another window renames or saves onto the file a window shows, and the window reopens it keeping
  its view (feature 111): only the mirror the user set is kept; the reopened picture is turned by
  its own tag (review 1 of 267 found the automatic mirror kept as the user's and turned again).
- Update Thumbnail's question "this file has no Exif, create a JFXX thumbnail?" is asked for
  exactly the same files as before.
- Panel thumbnails (already turned by their orientation since feature 064) do not change.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The viewer MUST know, for every JPEG it opens from a file, whether the file has an
  Exif block, and keep knowing it after the picture is turned, mirrored or cropped.
- **FR-002**: The Exif command (File menu and context menu item) MUST be available exactly when the
  shown picture is a JPEG with an Exif block (and the shown file was not deleted); the command
  MUST open the Exif window listing the file's tags.
- **FR-003**: With auto-rotate on, a JPEG with an Exif orientation tag MUST be shown turned and
  mirrored as the standard meaning of the tag says (values 2..8; 1 = as stored).
- **FR-004**: The orientation MUST be read without passing the file name through the system
  code page (any name, long paths).
- **FR-005**: The pixel size recorded in the block MUST NOT change the decision (PictView's old
  "changed after the camera" exception is not applied - the panel thumbnails do not apply it
  either).
- **FR-006**: The decision "orientation value -> which turn and which mirror" MUST be a pure
  rule with automated checks for all eight values and invalid values.
- **FR-007**: With auto-rotate off, or for files without an Exif block, or for pictures not
  from a file, nothing MUST be turned (the present behaviour).
- **FR-008**: Update Thumbnail's decision whether a file has an Exif block MUST stay feature
  132's file check, unchanged by the new engine report.
- **FR-009**: Files other than JPEG MUST keep their present behaviour.
- **FR-010**: Detecting the Exif block MUST NOT read the file a second time: it asks the image
  reader of the opened picture for its metadata (the reader parses the header segments itself),
  once per opened picture, and only for JPEG files - no own pass over the file.

### Key Entities

- **Exif block of a JPEG**: the APP1 "Exif" segment; holds the orientation (tag 274 of IFD0).
- **Orientation decision**: orientation value -> a quarter turn (none / clockwise /
  counter-clockwise) followed by mirrors (left-right, top-bottom).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The hidden-desktop probe of the feature passes all its rows (before the change:
  33 of 65 fail; the reopen rows
  added by review 1: 3 of 15): orientations 1..8 shown as the standard says, the "recorded size differs"
  and "no recorded size" rows turned, no Exif / XMP-only rows, a name outside the code page, auto-rotate
  off; the Exif window opens with the tags exactly for files with an Exif block.
- **SC-002**: The automated checks of the orientation rule cover all eight values and invalid
  values, and pass.
- **SC-003**: On real camera files (feature 135's public set): every file with an orientation
  tag is classified (turn / as stored) and the files whose Exif block the system reader finds
  are the files that have one; recorded in the fix-log.
- **SC-004**: Earlier PictView probes (feature 120, 132's Update Thumbnail) show no new failure.

## Assumptions

- Assumption (autonomous run): the built-in engine is the only engine of the viewer (WIC); the
  engine reports the Exif block - the way the old engine did - so every place that asks it
  (menu items, command, auto-rotation) agrees.
- Assumption (autonomous run): the Exif window keeps reading the tags through the plug-in's
  Exif library as today; a block that the system reader finds and the library cannot read
  shows an empty list (a limit, not changed here).
- Assumption (autonomous run): the visual state of the menu item (enabled /
  grayed) cannot be read on the hidden desktop; it follows the same condition as the command
  and is owed to a person to look at once.
- Assumption (autonomous run): EXIF.DLL's code-page export for the orientation stays exported
  (plug-in library exports are append-only) but the viewer no longer calls it; point (4) of the
  related item pictview-update-thumbnail-142-leftovers loses its only caller.
