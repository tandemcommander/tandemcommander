# Feature Specification: PictView's leftovers of 105 and 111

**Feature Branch**: `120-pictview-leftovers`
**Created**: 2026-10-06
**Status**: Draft (code complete; GUI runs pending)
**Input**: the PictView entries of `specs/NEXT-WORK.md` found by feature 111 ("Found by 111, not
fixed": (a) the pipette and the histogram read the engine's 32-bit rows as 3 bytes per pixel;
(b) a Rename onto another file that a second PictView window shows still fails "in use"; (c) the
GIF comment extension gets UTF-8 although GIF89a defines 7-bit ASCII), and the small PictView
leftovers recorded by 105 and 111 where contained. Measured before the work (`research.md`); the
maintainer asked for autonomy.

## Clarifications

### Session 2026-10-06

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Are the premises right? -> A: Yes. (a) Measured by a harness that compiles the plug-in's own
  engine and reader (`probe/pixharness/`, the build before from git): on 9 fixtures (24-bit,
  32-bit opaque and with alpha, 8-bit GIF, 16-color PNG, bilevel, gray, one color, a UTF-8 name)
  the pipette returned the wrong color for 3/4 of the pixels of every 32-bit row (all but every
  fourth pixel; 180 of 185 in a 37 x 5 image) and all five histogram channels were wrong for every
  fixture; Pillow is the reference. (b) Code reading: only the windows showing the RENAMED file let
  go (111); the replacing `MoveFileExW` meets the target's decoder, which does not share delete -
  error 5 (access denied - measured by the GUI run; the backlog said 32), nothing lost. (c) Measured: the Windows GIF encoder writes the given bytes in
  sub-blocks of at most 255, no NUL; it refuses XMP (`/xmp/...` answers
  `WINCODEC_ERR_PROPERTYNOTSUPPORTED`), so GIF has no Unicode alternative.
- Q: Which consumers of the engine's pixel buffer read it? -> A: Only the pipette (status bar and
  tooltip, `GetRGBAtCursor`) and the histogram (`CalculateHistogram`). The clipboard copy and
  printing draw through `PVDrawImage` (GDI), the panel thumbnails take the rows through
  `PVSaveImage` (32-bit, stride width x 4 - correct), Save As and the wallpaper encode from the
  image in memory (`IWICBitmapSource`), Image Information shows `BytesPerLine x Height` (the
  memory size - correct). There is no other "get pixel" interface.
- Q: How are the rows read? -> A: By their format: one pure reader (`src/common/salpvpixel.h`)
  for the pipette and the histogram - 4 bytes per pixel for 32-bit rows, 3 for 24-bit, 2 for
  15/16-bit, palette index, nibble or bit for palette rows - never past the rows the engine holds
  (`WicGetRowsSize`), whatever the viewer's image information says meanwhile. The histogram's own
  15/16-bit decoding (red and blue swapped) and its counting of the padding of palette rows go
  with it (not reachable with the WIC engine - recorded).
- Q: Which pixel does the pipette show for a mirrored image? -> A: The one under the cursor. The
  viewer mirrors when it draws; the rows are never mirrored, so the pipette showed the pixel
  opposite the cursor (code reading, every release). The coordinates shown stay those of the
  shown image (as the selection's), the color is read at the mirrored row position. The mapping
  from the window to the image is computed in 64 bits (a large image zoomed in overflowed 32 -
  20,000 pixels at 1600 %).
- Q: What does a window that showed the RENAME TARGET show after the replace? -> A: What its name
  holds now - the renamed file's content, opened again at the same zoom (the 111 rule "a window
  shows the file at its name": a Save As over a shown file reopens it, and 111's take-back opens
  a name that holds other content). A window that shows the target under another path (a hard
  link) keeps its file and re-attaches it. Not chosen: `<Deleted>` - the name still exists; the
  viewer would lose its place in the folder for a file that is there. The target's windows are
  asked only after the answer Yes to the overwrite question and only for the replace; a window
  that is loading, encoding or printing keeps the file and the replace fails "in use" as before
  (nothing changes). 111's operation ids keep the source's and the target's releases apart.
- Q: GIF comments outside ASCII? -> A: (a) keep the UTF-8 bytes; an ASCII comment is exactly
  what GIF89a defines. Refusing or stripping would lose the user's text with no message (no new
  string), GIF has no Unicode alternative (measured: XMP refused), Windows itself shows no GIF
  comment at all (measured: `System.Comment`/`Title`/`Subject` empty), and JPEG/TIFF already
  keep UTF-8 the same way. A reader that decodes the bytes as Latin-1 shows them garbled; nothing
  is lost. No code change; the decision is recorded in `wicengine.cpp`.
- Q: Which other leftovers are contained? -> A: 105's record "an in-viewer rotation is lost when
  the background color changes": the engine decoded the frame again from the file and the viewer
  kept the turned size (image drawn squeezed, saved unturned; measured by the harness: 37 x 5 after
  a turn instead of 5 x 37). The engine now counts its turns and turns a frame it decodes again.
  Not contained, recorded: the print preview is empty (`PVSaveImage` with scaling is refused by
  the WIC engine since 006).
- Q: How is it verified without running the program? -> A: saltests for the pure reader and the
  mapping; the harness for the real engine and reader against Pillow (old build as control); the
  GUI probe `probe/pv120_probe.ps1` is written and owed (another agent drives the hidden desktop
  now). The pipette rows need the real mouse cursor - a hidden desktop has none - so they run only
  on the visible desktop with the maintainer's agreement (`-VisiblePipette`).

## User Scenarios & Testing

### User Story 1 - The pipette and the histogram tell the truth (Priority: P1)

A user points the pipette at a pixel and reads its color; opens the histogram to judge exposure.

**Acceptance Scenarios**:

1. **Given** any image (24-bit, 32-bit, palette, gray, bilevel, with transparency), **When** the
   pipette is over a pixel, **Then** the status bar shows that pixel's color (transparent parts:
   over the viewer's background, as shown).
2. **Given** a mirrored image, **When** the pipette is over a pixel, **Then** the color is the one
   shown under the cursor.
3. **Given** a one-color image, **When** the histogram opens, **Then** each channel has exactly
   one level (luminosity: the weighted level; "RGB": the three channel levels).

### User Story 2 - Rename onto a file another window shows (Priority: P2)

**Acceptance Scenarios**:

1. **Given** window A shows x.png and window B shows z.png, **When** A renames x.png onto z.png and
   the user answers Yes, **Then** the rename succeeds, B shows z.png's new content, A shows z.png.
2. **Given** the same, **When** the user answers No, **Then** nothing changes, both windows hold
   their files again.
3. **Given** B prints z.png, **When** A renames onto it, Yes, **Then** the rename fails "in use",
   both files unchanged.

### User Story 3 - Rotation kept (Priority: P3)

**Given** a rotated image and a different full-screen background color, **When** the user goes to
full screen and back, **Then** the image stays rotated (drawn and saved).

### Edge Cases

- A window showing the target through a hard link keeps its file.
- A pipette position outside the rows the engine holds reads nothing (status bar empty).
- A GIF comment of ASCII text is exactly its bytes; other text its UTF-8 bytes.

## Requirements

- **FR-001**: The pipette and the histogram MUST read the engine's rows by their format.
- **FR-002**: The pipette MUST read the pixel shown under the cursor (mirror) and never outside
  the rows the engine holds.
- **FR-003**: A Rename onto a file other PictView windows show MUST let those windows release it
  for the replace and then show what their name holds (hard links: their own file).
- **FR-004**: A rotation MUST survive a new background color.
- **FR-005**: GIF comments: ASCII as is, other text as UTF-8 (decided; unchanged).
- **FR-006**: No plug-in interface change (107), no registry change, no new string.

## Success Criteria

- **SC-001**: Harness: 0 mismatches against Pillow on every fixture (the build before: > 0).
- **SC-002**: Probe rows `tgt-*`, `hist-*`, `bk-rot`, `cmt-gif-*` PASS on this build; `tgt-shown`,
  `tgt-shown-hl`, `hist-*`, `bk-rot` FAIL on the build before.
- **SC-003**: 111's probe and 105's Save As probe unchanged on this build.
