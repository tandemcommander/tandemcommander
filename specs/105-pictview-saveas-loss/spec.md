# Feature Specification: PictView Save As never loses the file it replaces

**Feature Branch**: `105-pictview-saveas-loss`
**Created**: 2026-10-04
**Status**: Draft
**Input**: found by feature 104 (`specs/104-plugin-unicode-names/research.md` section 0 item 4,
fix-log "Recorded, not changed"), `specs/NEXT-WORK.md` item 5, sub-item 5 queue, entry 1:
"PictView *Save As* onto an existing file deletes it and then fails ... Data loss in every
release since 006 - first." Measured before the work (`research.md`); the maintainer asked
for autonomy.

## Clarifications

### Session 2026-10-04

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Is the premise right? -> A: Yes, and wider. On the build before this feature (Debug_x64_pre105) **Save As cannot save anything**: every format the dialog offers (14 for a color image) ends with "Unable to save the image. Error: This operation is not supported by the built-in image engine." - for a new name nothing is created, and for an existing name "replace?" Yes **deletes the file first** (also a read-only one after its own question, and one in a folder that denies creating files). The engine of feature 006 stubs file output and reports every output combination as supported, so the dialog offered formats, depths and compressions it could never write (`research.md` sections 1-2).
- Q: Which order of fixes? -> A: (1) Never destroy before a complete write: the image is written into a temporary file in the target's folder, flushed, and only then takes the target's place (`ReplaceFileW`; on a file system without it `MoveFileExW(REPLACE_EXISTING)`; a new name `MoveFileExW` without replace). Every failure leaves the target byte-identical and deletes the temporary file; the one exception (the target vanished and the new file could not be moved into its place) keeps the temporary file and names it. (2) Make Save As work with the encoders Windows ships. (3) The same rule for the other PictView routes that write over an existing file.
- Q: Which formats? -> A: The Windows Imaging Component writes **BMP, PNG, JPEG, GIF, TIFF** (and JPEG XR/HEIF/DDS, which the dialog never offered - not added: no strings, no demand). The dialog's language list (`IDS_SAVEASFILTERCOLOR`/`MONO`, translated) is **filtered at run time** to those five; no string changes. CEL, IFF/LBM, PNM, SGI, Sun Raster, Targa, Utah RLE, SKA, PCX, Intergraph and WBMP are no longer offered. The stored "last type" (`Filter Color`/`Filter Mono`) keeps counting in the whole list (no registry change); a stored type that is gone falls back to Windows Bitmap, the old default. A format that cannot be written is refused before anything is touched (backstop).
- Q: Which options? -> A: Mapped where the encoder has a counterpart: **color depth** (BMP 16/256 colors, 256 gray levels, 15/16-bit HiColor, 24-bit; PNG and TIFF 16/256/gray/24-bit; JPEG gray/24-bit; GIF 16/256/gray), **compression** (BMP uncompressed; PNG deflate; JPEG; GIF LZW; TIFF uncompressed/LZW/Deflate/PackBits/Default=LZW, and CCITT G3/G4 for bilevel images), **JPEG quality and subsampling** (1:1:1 = 4:4:4, 2:1:1 = 4:2:2), **rotation/flip** (the dialog's, plus the viewer's mirror), **comment** (JPEG, PNG, GIF, TIFF; as UTF-8 text - the field is a Unicode control since 104). No counterpart, so the controls stay visible but disabled: GIF *Interlaced* and *GIF89a* (Windows always writes non-interlaced GIF89a), TIFF *Make strips*/*Strip size*. The dialog offers a combination only when the encoder writes exactly it (`PVIsOutCombSupported` is now real); 32-bit output is not offered (alpha is flattened over the background - the existing "alpha channel" question). "2 colors" (and so CCITT) is offered only for a bilevel source, as since Open Salamander - and the WIC engine reports every image as 32-bit, so they cannot be chosen; recorded, unchanged.
- Q: The image shown in the window? -> A: The WIC decoder keeps that file open without `FILE_SHARE_DELETE` (`ReplaceFileW` fails with 32 - measured). When the target is the shown file (file identity, `salsamefile.h`; "maybe" counts as yes), the decoder is released after the new image is complete and before the replace, and the window opens the file again afterwards (the saved image, or the untouched original after a failure). The build before refused this case ("in use") without a loss.
- Q: Other write routes? -> A: Swept (`research.md` section 3). *Regenerate thumbnail* deleted the image and then moved the rewritten copy into place unchecked, and PictView's *Rename* overwrite deleted the other file before renaming - both now replace in one step (`SalReplaceWithTempW` / `MoveFileExW(REPLACE_EXISTING)`); neither is reachable on either build (no scaled-JPEG encoder; the viewed file is held open, Rename fails with 32 first - recorded by 103). Wallpaper keeps failing before it writes anything (no file output in `PVSaveImage`, and its target `%WINDIR%` is not writable for a user) - recorded. Copy To uses the shell (its own overwrite handling); clipboard, print, rotation and mirror write no file; capture/scan/paste produce in-memory images saved through Save As.
- Q: Menu? -> A: The viewer's *File > Save As...* item (removed by 006 because nothing could be saved) is restored - its string is translated in every language. The toolbar button is not (the toolbar's button list is configuration).
- Q: Strings, interface, configuration? -> A: No new string (the messages use the existing *Unable to save the image* / *already exists* / *read-only* / *canceled* texts with the system's own error text); one English engine text for a failed write, like the other engine texts. Plug-in interface unchanged (107). No registry format change.
- Q: Found on the way? -> A: The suggested name copied the shown file's name into a 260-byte stack buffer unbounded (a CJK name over 86 characters overflowed it, every release) - fixed in the touched function. Others recorded in `fix-log.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Replacing an existing file never loses it (Priority: P1)
**Independent Test**: Save As onto an existing file; onto a read-only one; onto one another program holds open; into a folder that denies creating files; Esc during a long save.
**Acceptance**: either the file is replaced by a valid image, or it is byte-identical afterwards with an error that says why; no temporary file is left.

### User Story 2 - Save As saves (Priority: P1)
**Independent Test**: for each offered format a new name and an existing name; the options (depth, compression, quality, subsampling, comment, rotation, flip); names in Cyrillic, CJK, emoji.
**Acceptance**: the file is a valid image of the chosen format and options (decoded independently by GDI+, header read by hand), pixel-exact where the format is lossless.

### User Story 3 - Saving over the shown image (Priority: P2)
**Independent Test**: Save As onto the file the window shows, with rotation 90.
**Acceptance**: the file is replaced; the window shows the saved image afterwards.

### Edge Cases
- The target vanishes between the question and the replace: the new file takes its name.
- A folder of the target's name: never replaced ("already exists").
- A target that is another hard link of the shown file: only that name is replaced.
- The disk fills during the write: the target is untouched, the temporary file deleted, the system's text shown.

## Requirements *(mandatory)*
- **FR-001**: No PictView route may delete, truncate or overwrite an existing file before the complete new content exists in another file on the same volume.
- **FR-002**: Every failure after the user agreed to replace MUST leave the target byte-identical (attributes restored) and no temporary file behind - except when the target is already gone, where the new file is kept and named.
- **FR-003**: A format or combination the encoders cannot write MUST NOT be offered, and MUST be refused before anything is touched if it is reached anyway.
- **FR-004**: Save As MUST write BMP, PNG, JPEG, GIF and TIFF with the dialog's options that have an encoder counterpart.
- **FR-005**: No new string, no plug-in interface change, no registry format change.

## Success Criteria *(mandatory)*
- **SC-001**: `probe/saveas_probe.ps1` on this build: 0 FAIL, 0 files lost; on the build before it: the losses reproduced (every "replace" row) and every save failing.
- **SC-002**: saltests (13,487 before) pass with the new rule's checks; the strict encoding guard reports 0.
- **SC-003**: Debug + Release builds; the PictView rows of the 104 probe, the 088 viewers probe and the 103 samefile PictView rows give the same results as before.
