# Feature Specification: Undelete's leftovers - Restore Encrypted Files of any depth, true duplicates, one name for Windows

**Feature Branch**: `115-undelete-leftovers`
**Created**: 2026-10-05
**Status**: Implemented - GUI runs pending
**Input**: `specs/NEXT-WORK.md`, the 114 entry "Found by 114, not fixed": (a) Restore Encrypted
Files ignores `SalPathAppend` failures - a source path over 519 / 259 bytes recurses into the same
folder until the stack overflows and restores the parent's files into the target (`restore.cpp`);
(b) `RemoveDuplicateFiles` compares DSSize bytes of a 44-byte structure (over-read; the
duplicates of {All Deleted Files} are never removed); (c) name identity in the restore list / FAT
numbering is `_stricmp` (ASCII only - 092's rule would apply). Also sweep the restore and
encrypted code for other unchecked path appends and fixed buffers.

## Clarifications

### Session 2026-10-05

The maintainer asked for autonomy; the decisions are the author's recommended options. No GUI run
was possible today (the installed program was in use - it shares the registry key with every
probe): the measurements are by code reading (`research.md`) and the GUI evidence is the pending
probe (`quickstart.md`).

- Q: Restore Encrypted Files with a path that does not fit - refuse or make it work? -> A: Make it
  work. The walk's source and target paths live in heap buffers of `SAL_MAX_PATH_UTF8` bytes (the
  program's limit), the source panel's path is read whole, and the walk has no recursion (a heap
  stack of open searches) - a depth of thousands of folders cannot overflow the thread's stack.
  What still cannot be done (a name that does not fit even that buffer; a path the file system
  refuses) is reported - Skip / Skip all / Cancel with the system's text - and never entered:
  the walk never stays in the parent's path.
- Q: A folder the walk is already in? -> A: A directory link (junction / symbolic link) leading
  back to a folder of the walk, the target folder, or a folder this restore created in the target
  (the target lies inside the selection) is reported with the system's text for
  `ERROR_CANT_RESOLVE_FILENAME` and skipped; identity = 103's file identity of the folder the
  path leads to (usable 128/64-bit ids only) or its normalised final path; neither readable = no
  claim (review SF1). Other links are followed as before. Rejected: not following links at all
  (would silently drop data behind a link that the build before restored).
- Q: Which duplicates leave {All Deleted Files}? -> A: Items of the same name (the file system's
  rule) whose data is the same: equal size and equal data runs (every block: first / last VCN,
  run bytes). Every kept item of a run of equal names is compared (the sort orders by name only).
  A zero-size file (no runs) is never a duplicate (as before). Before: true duplicates were never
  removed, and two different files of up to 20 bytes with one name were "duplicates" - one
  vanished from {All Deleted Files}.
- Q: The name rule? -> A: 092's: `CompareStringOrdinal(..., TRUE)` on UTF-16 for valid WTF-8, a
  total order over all byte strings; header-only `src/common/salnameorder.h` (a port of
  `SalNameCompareOrdinalCI` / `SalNameEqualOrdinalCI`, checked against them by saltests) because
  the plug-in cannot compile a shared .cpp. Used by the restore list's numbering, the FAT
  listing's numbering of deleted files, the duplicate removal and the plug-in's path lookup.
- Q: The sweep? -> A: Fixed: F3 on a deleted file with a long name (the disk-cache copy's name was
  cut at MAX_PATH bytes - the copy was written elsewhere and the viewer opened nothing); a failed
  restore of an encrypted file in backup form deleted `<name>` instead of the `<name>.bak` it
  created (the user's own file); `UndeleteGetResolvedRootPath` copied a path of up to 2 x MAX_PATH
  bytes or more unbounded into MAX_PATH; the target path of the main restore was silently cut
  (refused now); `CloseEncryptedFileRaw` on an uninitialised context; a `.bak` too short for the
  backup signature counted as a real backup; the source left open when the target could not be
  created; progress labels lost the end (the name) of a long path. Recorded, not changed:
  `research.md` 4.
- Q: Interface, strings, configuration? -> A: No plug-in interface change (107), no new string, no
  registry change.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Restore Encrypted Files restores a deep folder (Priority: P1)

A user restores backups from a folder tree deeper than 259 bytes (or with the source panel in
such a folder). Every file arrives in its own folder; nothing crashes; no folder's files land in
another folder.

**Acceptance Scenarios**:

1. **Given** a selected folder 16 levels deep (about 650 bytes), **When** the user runs Restore
   Encrypted Files from Backup, **Then** every file is restored under the same relative path and no
   message appears (before: a crash).
2. **Given** the source panel in a folder of 260+ bytes, **When** the user restores the selection,
   **Then** its files and subfolders are restored (before: an error and an empty subfolder).
3. **Given** a folder holding a junction to itself, **When** the user restores it, **Then** its
   files are restored once and the junction is reported once (before: a crash).

### User Story 2 - {All Deleted Files} lists each file once and every file (Priority: P2)

1. **Given** a deleted directory cluster reached from two deleted directory entries, **When** the
   user opens {All Deleted Files}, **Then** its file is listed once (before: twice).
2. **Given** two different deleted files of one name and up to 20 bytes in two folders, **Then**
   both are listed (before: one).

### User Story 3 - Names that are one name for Windows are numbered (Priority: P2)

1. **Given** deleted `<C-caron>.txt` and `<c-caron>.txt` of one folder, **When** the user restores
   both, **Then** they are restored as `<C-caron> (k).txt` and `<c-caron> (k).txt` without an
   overwrite prompt (before: the second asked to overwrite the first).

### User Story 4 - F3 on a deleted file with a long name (Priority: P3)

1. **Given** a deleted file with a 334-byte name, **When** the user views it, **Then** the viewer
   shows that file (before: the copy was written under a cut name).

### Edge Cases

- A target folder inside the selection: the walk refuses to enter it (no endless nesting).
- A file restored onto itself (target = source folder): the source is open without write sharing,
  the target cannot be created - reported, nothing lost (unchanged).
- Real EFS backups (`.bak` with the ROBS signature) and encrypted deleted files on NTFS: code
  only, not driven (need a user EFS certificate / a raw NTFS volume).

## Requirements *(mandatory)*

- **FR-001**: The Restore Encrypted Files walk MUST never continue with a path that did not
  receive the name it was meant to receive; a name or folder it cannot handle MUST be reported.
- **FR-002**: The walk MUST work for paths up to the program's limit and for any depth the file
  system holds, without recursion on the thread's stack.
- **FR-003**: The walk MUST NOT enter a folder it is already in or the target folder.
- **FR-004**: The source panel's path MUST be read whole or the command refused.
- **FR-005**: {All Deleted Files} MUST remove exactly the items with the same name and the same
  data, and keep every other item.
- **FR-006**: Name identity in the plug-in's numbering, duplicate removal and lookup MUST follow
  feature 092's rule.
- **FR-007**: The view of a deleted file MUST write its disk-cache copy under the full name it
  was given.
- **FR-008**: A failed restore MUST delete only the file it created.
- **FR-009**: No plug-in interface, string or configuration change.

## Success Criteria *(mandatory)*

- **SC-001**: Probe `undelleft_probe.ps1` on this build: every row PASS (2 NOT DRIVEN routes); on
  the build before (`-Expect before`): every defect row shows the defect.
- **SC-002**: saltests 14,383 -> 14,401 / 0; strict encoding guard TOTAL 0; Debug and full Release
  builds succeed.
- **SC-003**: Regression: 114's `undelnames_probe.ps1` unchanged on this build.
