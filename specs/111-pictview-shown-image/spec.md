# Feature Specification: PictView works on the image it shows

**Feature Branch**: `111-pictview-shown-image`
**Created**: 2026-10-05
**Status**: Draft
**Input**: the PictView entries of `specs/NEXT-WORK.md` found by features 103 and 105: *Rename* of
the shown image fails with error 32 (103 research row 14, fix-log "Recorded"); every PNG/TIFF/ICO
asks "the alpha channel will be lost" and "2 colors" is never offered; the wallpaper commands
cannot work; a second viewer window showing the same file blocks the save; the TIFF comment is
UTF-8 in an ASCII-typed tag and the JPEG comment ends with a NUL byte (105 review NITs); the reload
after a save resets mirror and zoom (105 NIT). Measured before the work (`research.md`); the
maintainer asked for autonomy.

## Clarifications

### Session 2026-10-05

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Are the premises right? -> A: Yes, all of them, measured on the build before
  (`Debug_x64_pre111`, `probe/shown_result_pre111.txt`): Rename of the shown image fails with 32
  for every name; **Delete** of the shown image fails too (the shell's "File in use" window, the
  file stays) - not in the backlog; a second window on the same file makes Save As, Rename and
  Delete fail; an opaque 32-bit PNG, TIFF or ICO asks the alpha question; a bilevel PNG or a CCITT
  G4 TIFF is offered 16 colors and up, never "2 colors" or CCITT; the title says 16777216 colors
  for every image; the TIFF comment is UTF-8 in tag 270 with no other copy and the JPEG COM segment
  ends with 00; after a failed Save As over the shown image the zoom and mirror are reset. The
  wallpaper commands were measured by reading the code only: their pre-111 path calls
  `SystemParametersInfo(SPI_SETDESKWALLPAPER, NULL)` even after its failed save, which must not run
  in the maintainer's session (`research.md` section 4).
- Q: How is the shown file let go? -> A: The 105 mechanism, extended: before Rename, Delete or
  the replace step of Save As, **every** PictView window showing that file (identity, 103's
  `salsamefile.h`) releases its WIC decoder (`WicDetachSource`; the image stays in memory and is
  still drawn). Afterwards each window takes the file back: the same content (renamed, or the
  operation failed or was declined) is **re-attached** without a reload - a new decoder on the
  file's current name, frame count and frame unchanged (`WicReattachSource`), so zoom, mirror and
  rotation stay; a rewritten file (Save As over it) is opened again at the same zoom; a deleted
  file keeps its image in memory, titled `<Deleted>`. Other windows are asked with
  `SendMessageTimeout` (each viewer runs in its own thread); a window that is loading or does not
  answer keeps the file - the operation then fails "in use" as before, nothing is lost. Not chosen:
  opening the file with `FILE_SHARE_DELETE` (a delete would leave a pending-delete name on FAT and
  SMB until the viewer closes, and other programs could rename the file under the viewer).
- Q: Which operations? -> A: Rename (103's guarded `RenameFileInternal` unchanged inside), Delete
  (recycle bin and permanent), Save As over the shown file. Copy To only reads (the decoder shares
  read) - unchanged. PictView has no Move To. A rename onto ANOTHER file shown in a second window
  still fails "in use" (that file is not the one operated on) - recorded.
- Q: Second window (backlog item 4)? -> A: Fixed by the same release - not just a better message.
- Q: The source's real format (item 2)? -> A: The engine keeps reporting its 32-bit rows in
  `PVImageInfo::Colors` (the pipette and the histogram read those rows), and gains
  `WicGetSourceFormat`: colors (2/16/256, 15/16-bit, 24-bit, 32-bit), color model (RGB, gray, CMYK),
  bits per pixel, whether the pixel format has an alpha channel and whether a pixel of the decoded
  frame is not opaque. A palette's size decides (a two-color GIF is 8bppIndexed with a 2-entry
  palette - measured). Used by Save As: the alpha question only when transparency is really used;
  the default depth and the mono type list from the source (so "2 colors" and the CCITT G3/G4 TIFF
  compressions appear for a bilevel image); and by the title and Image Information (the colors and
  bit depth of the file). A palette's transparent color (GIF, PNG tRNS) is no alpha channel - no
  question, as before.
- Q: Wallpaper (item 3)? -> A: Implemented safely, not removed: a 24-bit BMP of what the window
  shows into `%LOCALAPPDATA%\Tandem Commander\PictView_Wallpaper.bmp` (105's temporary file +
  replace), `WallpaperStyle`/`TileWallpaper` and the backup of the previous wallpaper (`Prev*`,
  the value names of before) in `HKCU\Control Panel\Desktop` through the wide API, then
  `SPI_SETDESKWALLPAPER` with that file's path (`SPIF_UPDATEINIFILE | SPIF_SENDCHANGE`); Restore
  swaps with the backup, None sets `""`. **Never NULL** (documented as "reverts to the default
  wallpaper"). A failed save changes nothing in the registry or on the desktop. Test seam: the
  environment variable `TC_PICTVIEW_WALLPAPER_DRYRUN` (a log file) turns every registry write and
  the SPI call into a logged line - the probe never changes the real wallpaper (the hidden desktop
  shares it). `PRIVACY.md` updated (a new file, the registry values).
- Q: Comments (item 5)? -> A: TIFF: an ASCII comment stays ASCII in tag 270 only; any other goes
  into tag 270 as UTF-8 - what Windows itself writes there (its `System.Title` policy) and reads
  back as UTF-8 (measured), the Metadata Working Group's recommendation, exiftool's pass-through -
  **and** into XMP `dc:description` (`x-default`), Unicode by definition, so no reader has to guess.
  A reader that decodes tag 270 strictly as Latin-1 (Pillow) still shows its UTF-8 bytes there, but
  finds the text in XMP; omitting tag 270 would hide the comment from tag-only readers - recorded
  trade-off. JPEG: the COM segment without the trailing NUL (taken out of the finished file).
  GIF (7-bit ASCII by its spec) unchanged - recorded.
- Q: Mirror and zoom after a save (105 NIT)? -> A: A failed replace no longer reloads (re-attach:
  zoom and mirror stay); a successful one keeps the zoom; the mirror is reset on purpose - a
  mirrored view is saved mirrored, so the file now holds what was shown.
- Q: Strings, interface, configuration? -> A: No new string, no plug-in interface change (107), no
  registry format change of the product (the wallpaper values are Windows' own, the `Prev*` names
  those PictView always used).

### Session 2026-10-05 (independent review: REJECT)

- Q: A window that moved to another file during the operation? -> A: It is never touched: opening
  another image drops the released state, and a retake acts only on the released image while it is
  still detached; a request handled after its operation ended is a no-op; a window whose retake never
  came takes the file back itself once the operation is over (timer). Re-attach only for the same file
  with the same size and last write time, else reopen. `<Deleted>` and a new name apply only to windows
  showing the operation's own path (a hard link survives a delete). (B1, NITs)
- Q: A window encoding or printing the image? -> A: It refuses to let the file go (the other window's
  operation fails "in use", nothing lost) - its encoder or print dialog keeps using the image. (S1)
- Q: Restore Previous with nothing backed up; None twice? -> A: Restore does nothing without a backup;
  the backup is written only after Windows accepted the new wallpaper and never empty; Set as
  Wallpaper and None never back up our own file, Restore backs up the one it replaces (a second
  Restore swaps back); style values are put back when Windows refuses. (S2)
- Q: Multi-page images? -> A: The title names the colors of the page whose information is shown. (S3)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Rename and delete the image being viewed (Priority: P1)
**Independent Test**: Rename the shown image to ASCII, Cyrillic and CJK names; with the file held
by another program; onto an existing file held by another program; onto a read-only file; Delete
it (Yes / No).
**Acceptance**: renamed / deleted as asked, or nothing changes with the system's reason; the viewer
keeps showing the image, holds the file again under its current name, keeps its zoom.

### User Story 2 - Two windows on one file (Priority: P2)
**Independent Test**: two viewer windows on one file; Save As over it, Rename, Delete from one.
**Acceptance**: the operation succeeds; the other window shows the saved image / the new name /
`<Deleted>`.

### User Story 3 - Save As offers what the image is (Priority: P2)
**Independent Test**: opaque and transparent 32-bit PNG/TIFF/ICO; bilevel PNG and CCITT TIFF; gray;
16-color palette.
**Acceptance**: the alpha question only for real transparency; "2 colors" and CCITT for bilevel
sources, saved bit-exact; default depth = the source's; the title names the source's colors.

### User Story 4 - Wallpaper (Priority: P3)
**Independent Test** (dry run): Center, Tile, Stretch, Restore, None.
**Acceptance**: the BMP is written and valid; the registry values and the SPI path that would be
used are right; never NULL; the real wallpaper is unchanged by the test.

### Edge Cases
- A window that is loading the image when another window asks it to let the file go: it keeps the
  file, the operation fails "in use" (nothing lost).
- The renamed/re-attached file is no longer the same image (replaced by a third party meanwhile):
  the image stays in memory, detached.
- A rename that leaves the file at 103's temporary name: the viewer keeps the image in memory.
- A viewer window that does not answer within 5 s: its message data is never freed (no dangling
  pointer), it keeps the file.

## Requirements *(mandatory)*
- **FR-001**: Rename, Delete and Save As over the shown file MUST work while PictView windows show it;
  on any failure the file MUST be unchanged and every window MUST still show its image.
- **FR-002**: After an operation that leaves the content unchanged, a window MUST NOT reload (zoom,
  mirror, rotation stay).
- **FR-003**: Save As MUST offer depths from the source's real format and ask about alpha only when
  transparency is used.
- **FR-004**: The wallpaper commands MUST NOT call `SPI_SETDESKWALLPAPER` with NULL and MUST NOT change
  anything when the image could not be written.
- **FR-005**: TIFF comments outside ASCII MUST also be stored in XMP `dc:description`; the JPEG COM
  segment MUST hold the comment's bytes only.
- **FR-006**: No new string, no plug-in interface change, no registry format change.

## Success Criteria *(mandatory)*
- **SC-001**: `probe/shown_probe.ps1` on this build: 0 FAIL; on the build before: the defects reproduced.
- **SC-002**: saltests (14,140 before) pass with the new checks; the strict encoding guard reports 0.
- **SC-003**: Debug + Release builds; regressions 105 saveas, 103 samefile, 104 plugnames (PictView rows),
  088 viewers (PictView rows) as before.
- **SC-004**: the real wallpaper (registry + `SPI_GETDESKWALLPAPER`) identical before and after every run.
