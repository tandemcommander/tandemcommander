# Feature Specification: The plug-ins use the names you give them

**Feature Branch**: `104-plugin-unicode-names`
**Created**: 2026-10-04
**Status**: Draft
**Input**: `specs/NEXT-WORK.md` item 5, sub-item 5 ("Same class as 102 in other plug-ins"), found
by the 102 research and not examined: code-page window subclasses on text controls in ftp (3),
zip (4), 7zip (1); `CreateFileA` fallbacks in checksum, peviewer, renamer; `DragQueryFile` in
dbviewer and pictview; PictView's `salpvenv.exe`. The coordinator asked for a sweep of all
enabled plug-ins for the same patterns; disabled plug-ins are listed only.

## Clarifications

### Session 2026-10-04

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: What is wrong? → A: Measured in the product (`research.md`, the probe on the build before):
  wherever a plug-in takes a file or folder name through a code-page ("ANSI") call - a window
  subclass, a code-page message loop, a code-page read of a field, or the plug-in services
  `SafeGetOpenFileName`/`SafeGetSaveFileName`/`GetTargetDirectory` - a character outside the
  system code page becomes `?` or, worse, a **best-fit look-alike** (`voilà` → `voila`,
  fullwidth `ＡＢ` → `AB`). Then **another existing file or folder is used**: the Renamer renamed
  `src.txt` to `voila.txt` (asking to overwrite the existing one) when told `voilà.txt`, and a
  mask `Ж*.txt` selected every 4-letter name; the Database Viewer opened `voila.csv` for
  `voilà.csv`; PictView copied into the folder `voila` for `voilà`, and its Save As asked to
  replace `voila.bmp`; the CAB plug-in took the next volumes from `...\voila`; Undelete opened
  the image `voila.ima`; the FTP plug-in's save dialogs overwrote a look-alike file and failed for
  every accented name. Other names were shown garbled (ZIP's dialog labels, the Renamer's manual
  list and history).
- Q: Were the backlog's counts right? → A: No (research 0): the eight subclasses it counted are
  on non-text windows or carry no names (except ZIP's path label: display); the `DragQueryFile`
  calls only count; the `CreateFileA` fallbacks are unreachable or correct; `salpvenv.exe` is
  not built, not shipped and not reachable. The real defects were elsewhere - the Renamer above
  all, and the plug-in-facing code-page file and folder pickers.
- Q: Scope? → A: Every reachable route in the **enabled** plug-ins where a name passes such a
  call (research 2: Renamer, PictView, Database Viewer, FTP, ZIP, CAB, Undelete, Registry
  Editor, SFTP, and the shared dialog library `winliblt`). Disabled plug-ins: listed, unchanged
  (research 3). Not names (archive comments, search texts, passwords) and unreachable code (the
  ZIP self-extractor) are recorded, not changed.
- Q: The plug-in services are code page by contract - widen them? → A: No (that would be plug-in
  interface 108). Two header-only helpers in the plug-ins' shared code call the Unicode dialogs
  inside the plug-in (`splfiledlg.h`: an open/save dialog for an `OPENFILENAME` whose names are
  UTF-8; the old-style folder picker), as feature 102 did for the File Comparator's Browse.
- Q: A name whose UTF-8 form does not fit the plug-in's buffer? → A: **Refused** with the
  system's own "The filename or extension is too long." (Windows translates it: no new string),
  never cut and never converted to the code page. This also applies to winliblt's field reader
  (`EditLine`), which re-read such a field through the code page (best fit). The core cuts at a
  whole character (093); plug-in buffers are mostly 260 bytes for names and paths, where a cut
  names another file. A live preview (the Renamer's) refuses silently and shows its "transfer
  error".
- Q: What keeps working as before? → A: ASCII names byte for byte; code-page text that is not
  UTF-8 is still shown and taken as code-page text; the Renamer's external editor file and
  filter pipe still carry the names' UTF-8 bytes (what they carried before, by accident); the
  menu bars still get code-page characters.
- Q: PictView's Save As deletes an existing file and then fails to save (found by the probe)? →
  A: Not an encoding defect: recorded in NEXT-WORK as a serious defect for its own feature. Only
  the name part (the look-alike) is fixed here.
- Q: User-visible text? → A: No new strings, no registry format change, plug-in interface stays
  107.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The Renamer renames to the name typed (Priority: P1)
**Independent Test**: New name `Жаба.txt`, `日本語.txt`, an emoji, `voilà.txt` (decoy
`voila.txt`), `ＡＢ.txt` (decoy `AB.txt`), a lone surrogate - typed and set; the mask `Ж*.txt`;
manual mode with `článek.txt` and a CJK name; the history afterwards; a 604-byte new name.
**Acceptance**: the file has exactly the typed name, the decoy is untouched, the mask selects
only the matching file, the manual list shows the names exactly, an over-long name is refused.

### User Story 2 - Picked files and folders are the picked ones (Priority: P1)
**Independent Test**: Database Viewer *Open*, PictView *Copy To* Browse and *Save As*, the CAB
next-volume folder, Undelete's image file - each with a `voilà` name and a `voila` decoy.
**Acceptance**: the named file or folder is used; the decoy is never opened, overwritten,
deleted or copied into.

### User Story 3 - Names are shown as they are (Priority: P2)
**Independent Test**: the ZIP password dialog for an item named in Cyrillic; Undelete's image
field prefilled from a focused file named in Cyrillic.
**Acceptance**: the name is shown exactly.

### Edge Cases
- A name or path whose UTF-8 form does not fit the plug-in's buffer (about 87 CJK characters in
  260 bytes): refused with a message.
- A lone surrogate (legal on NTFS): carried as WTF-8.
- Text that is not UTF-8 (older configuration, a code-page tool's output): taken as code page.

## Requirements *(mandatory)*
- **FR-001**: No route of an enabled plug-in may convert a file or folder name with best fit or
  to `?` between the user and the file operation.
- **FR-002**: A name that does not fit is refused with a message - never cut, never converted.
- **FR-003**: Names in plug-in dialogs (labels, fields, lists) are shown exactly.
- **FR-004**: ASCII names behave byte for byte as before.
- **FR-005**: No plug-in interface change (107), no new string, no registry format change.

## Success Criteria *(mandatory)*
- **SC-001**: The probe (`probe/plugnames_probe.ps1`) shows every route exact on this build and
  the predicted defect on the build before.
- **SC-002**: 0 decoys used on any driven route.
- **SC-003**: Debug and Release builds, unit tests, guard, and the probes of 093, 094, 099, 102,
  103 pass.
