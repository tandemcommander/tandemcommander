# Feature Specification: Moving into an archive never deletes files behind a link

**Feature Branch**: `099-move-into-archive-links`
**Created**: 2026-10-03
**Status**: Draft
**Input**: found by feature 098 (`specs/098-long-path-overruns/fix-log.md`, second review) and confirmed by driving on the builds before and after 098: moving (F6) a folder that contains a junction - or the junction itself - into an existing ZIP or 7z archive packs the files *behind* the junction and **deletes them**, with no warning. Those files lie outside the selection. Every release. The maintainer's standing instruction: serious defects found on the way are fixed one by one.

## Clarifications

### Session 2026-10-03

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Why does the Pack dialog's *Move* not have this defect? → A: Since Open Salamander, *Pack* with "delete files after packing" first scans the selection for links (junctions, symbolic links to folders) and, if it finds one, warns and switches the deletion off. Feature 098 made that scan fail closed. **The other routes that move files into an archive - F6 into an archive panel, drag and drop with Move onto an archive panel - never had the scan.**
- Q: What should happen on those routes when a link is found? → A: **No file is deleted that is not itself in the selection.** The same scan runs before the operation; if it finds a link - or cannot check everything (098's rule) - the user is shown the existing link warning and the operation does **not** move: it is cancelled before anything is packed. Chosen over "copy instead of move": silently turning a Move into a Copy leaves the user with duplicates they did not ask for; with the warning they can choose Copy (F5) themselves. No new strings: the existing warning is used; if its wording promises "the files will be copied", the route copies instead - the spec follows the existing text so that what the user reads is what happens.
- Q: Which routes? → A: Every route that moves files from a disk panel into an archive: F6 (and Shift+F6 if it moves), drag and drop with the Move effect onto an archive panel or onto an archive file, the Move of the *Pack* dialog (already scanned), and moves into a plug-in file system (FTP, SFTP, ...) **if** the core deletes the sources after the plug-in has copied them through the same kind of walk - established by reading.
- Q: Links inside the archive's own folder tree, or a link that points into the selection? → A: Any link in the selection triggers the warning, as in the Pack dialog (the scan does not judge where the link points).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - F6 of a folder with a junction into an archive deletes nothing outside the selection (Priority: P1)

**Independent Test**: folder S\B holds a junction J pointing to X (outside S) with x.txt; F6 of B into an open ZIP / 7z archive; X\x.txt must still exist afterwards; the warning was shown; nothing was packed or deleted (or, if the existing warning promises a copy, the archive holds the copy and nothing was deleted).

**Acceptance Scenarios**:
1. **Given** a selection containing a junction (or being one), **When** it is moved into an archive by F6 or by drag and drop, **Then** the link warning is shown and no file outside the selection is deleted.
2. **Given** a selection without links, **Then** F6 into an archive behaves exactly as before (packed, sources deleted).
3. **Given** a selection the scan cannot fully check (an unreadable folder, too deep), **Then** the same as a link (098's rule).

### Edge Cases

- A symbolic link to a folder, a symbolic link to a file (a file link is packed as the file it points to? established by reading: if the source *link* is deleted, not the target, that is fine).
- Selection of many items where one is a junction.
- Moving into a nested folder of the archive.

## Requirements *(mandatory)*

- **FR-001**: Before any operation that packs files into an archive and then deletes the sources, the selection MUST be scanned for links with 098's fail-closed scan.
- **FR-002**: When the scan finds a link or cannot check everything, no file MUST be deleted; the user MUST be told with the existing link warning, and the operation MUST behave as that warning's text says.
- **FR-003**: Without links, behaviour MUST be unchanged.
- **FR-004**: No new strings; no plug-in interface change.

## Success Criteria *(mandatory)*

- **SC-001**: In every probe case with a junction (F6 of a folder holding one, F6 of the junction itself; ZIP and 7z; drag and drop by reading if it cannot be driven), the file behind the junction survives; the build before the fix deletes it.
- **SC-002**: F6 of a selection without links into ZIP and 7z: identical results on both builds.
- **SC-003**: Debug and Release builds, unit tests, the strict guard, and the probes of 095-098 pass.
