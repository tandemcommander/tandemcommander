# Feature Specification: A folder is never copied or moved onto another path of itself

**Feature Branch**: `107-folder-alias-move`
**Created**: 2026-10-04
**Status**: Draft
**Input**: the two leftovers of feature 103's second review (`specs/103-same-file-delete-guard/fix-log.md`,
NIT 4 and NIT 5; `specs/NEXT-WORK.md` item 5): (1) moving a FOLDER onto an alias of itself between two
roots (`C:\x\F` -> `\\localhost\C$\x\`) still deletes its empty subfolders; (2) a hard link reached
through an alias gets "overwrite x with x?" and then error 32. Measured before the work
(`research.md`, `probe/folderalias_result_pre107.txt`); the maintainer asked for autonomy.

## Clarifications

### Session 2026-10-04

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Is the premise right? -> A: Yes, and wider than recorded (`research.md` section 0). On the build
  before this feature a folder moved "into the same place" through ANY alias that is another root -
  `\\localhost\C$`, `\\127.0.0.1\C$`, a mapped drive, a SUBST letter - or through an alias on the same
  drive that Windows does not see as the same path - a junction, the 8.3 spelling of a folder above it -
  lost its empty subfolders. A folder moved INTO ITSELF or into one of its own subfolders through
  such an alias had its whole content moved one level down (`F\a.txt` -> `F\F\a.txt`) and the
  emptied folders deleted. No file content was lost in any measured case (103 refuses the files), but
  the source tree was changed or partly deleted, after dialogs that never said why.
- Q: Which operations? -> A: Every route that builds a copy/move script for a folder: F5 / F6
  (`BuildScriptMain`), paste and drag & drop (`DropCopyMove` -> `BuildScriptMain2`), and the plug-ins'
  "move from a temporary folder" service (`MoveFiles`) - all through `BuildScriptDir`. Quick Rename
  cannot name another folder (the core refuses `\` and `:` in the new name); the command line has
  no copy/move of its own (it runs `cmd.exe`).
- Q: How is "the target is the source" recognised? -> A: By the file system's identity (103's
  `CSalFileIdentity`: volume serial + file id, read with an attribute-only open, following links);
  where a server gives no ids (WebDAV), equal kind and times **and the same path below the server
  name up to case and Unicode normalization** - both paths resolved first (a mapped drive letter
  becomes its UNC path) and the redirector's `DavWWWRoot` component dropped; a side that cannot be
  resolved falls back to the folder names - mean "maybe", which counts as yes (an alias - a
  second server name, a mapped drive, the `DavWWWRoot` form, another Unicode spelling - keeps that
  path; the re-check REJECTED a first version that compared the typed text); a backup folder elsewhere on the
  server does not, however equal its times; independent review SF2 - the first version compared only
  the folder's own name, which a merge always shares). A folder with an id and one without are on
  two file systems: not the same (otherwise re-uploading a folder to a WebDAV server that reports no
  creation time would be refused whenever "preserve directory time" kept the times equal). A folder
  in a **snapshot** (a shadow-copy device, an `@GMT-` path component of Previous Versions) is never
  the live folder (or another snapshot's), although it keeps the volume serial and the ids - restoring
  from it must merge; on **FAT/FAT32/exFAT** an equal id counts only with equal times (the id follows
  the directory entry) - review SF1. No blanket time check on NTFS/SMB (the SMB client may report
  folder times seconds stale - aliases would be missed). For a folder:
  - the folder the source would become (`T\name`) exists and IS the source -> refused (copy and move);
  - a move whose target folder `T`, or a folder above it, IS the source -> refused (a move into
    itself). The folders above `T` are read once per operation, by the path as written and by the
    path it resolves to (a junction in the middle of the path).
- Q: Which messages? -> A: The existing ones, no new string: a move "Cannot move a directory to
  itself." (`IDS_CANNOTMOVEDIRTOITSELF`, the by-name check's text), a copy "Cannot copy a file to
  itself." (`IDS_CANNOTCOPYFILETOITSELF` - the text the by-name route shows for a folder copied onto
  itself; there is no "directory" variant for a copy). Shown while the script is built, before any
  question and before anything is touched; the operation ends (as the by-name check does).
- Q: A copy of a folder INTO itself (or into its subfolder)? -> A: Unchanged. The build before this
  feature makes a snapshot copy (`F\F\...`, `F\sub\F\...`) by name and through every alias alike - it
  deletes nothing, the script is built before anything is written, so it never recurses. Refusing it
  would change a by-name behaviour nobody reported; recorded.
- Q: Below the top level? -> A: A second check where the worker meets an existing target folder
  (`DoCreateDir`, the "directory overwrite" path, before its question): if that folder is the source
  folder (e.g. a junction inside the target pointing back into the source), the merge is refused with
  the same texts (Retry / Skip / Skip All / Cancel; Skip leaves the subtree and its deletions out). A
  move refuses also when one side cannot be read (fail-closed, the 098/099 lesson).
- Q: The hard link reached through an alias? -> A: Refused like 103's other same-file cases ("Cannot
  copy/move a file to itself.") when it is the SAME directory entry: 103 exempted every source with
  more than one link because the target can be ANOTHER link, where the old handling (delete that name,
  write an independent copy) keeps the data. Now the two entries are told apart: the identities of the
  two holding folders plus the two names as the folders store them (`FindFirstFile`). Same folder and
  same stored name -> the same entry -> refused; another folder or another stored name -> another link
  -> the old handling, unchanged (overwriting `b`, a hard link of `a`, with `a` asks "overwrite?" and
  then leaves `b` an independent copy - nothing lost, it is what was asked); cannot tell -> refused
  (fail-closed).
- Q: Interface, strings, configuration? -> A: No plug-in interface change (stays 107), no new string,
  no registry change. The rules are header-only (`src/common/salsamefile.h`); the plug-ins keep
  `SalDecideExistingTarget` (103's rule) unchanged.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Moving a folder "into the same place" never touches it (Priority: P1)
**Independent Test**: F6 of `C:\...\parentlong\F` to `\\localhost\C$\...\parentlong\`, `\\127.0.0.1\C$\...`,
a mapped drive, a SUBST letter on `parentlong`, a junction to it, its 8.3 spelling, another case, the
second WebDAV server name, the NFC spelling of an NFD-stored WebDAV folder.
**Acceptance**: "Cannot move a directory to itself."; no other question; the source tree (every file
and every folder, empty ones included) identical afterwards.

### User Story 2 - Moving a folder into itself or into its own subfolder is refused (Priority: P1)
**Independent Test**: F6 of F to `<alias>\F\` and `<alias>\F\sub\` for every alias above, and by name.
**Acceptance**: "Cannot move a directory to itself."; the source tree identical.

### User Story 3 - A copy onto itself is refused, a copy into itself works as before (Priority: P2)
**Independent Test**: F5 of F to `<alias>\` (the same place) and to `<alias>\F\`, `<alias>\F\sub\`.
**Acceptance**: the same place: "Cannot copy a file to itself.", nothing changed; into itself: the
snapshot copy of the build before (by name and through an alias alike), the source entries intact.

### User Story 4 - One hard link through an alias is "the same file" (Priority: P2)
**Independent Test**: F5 / F6 of `a.txt` (with a hard link `b.txt`) to `\\localhost\C$\...\` (the same
entry), SUBST, junction, 8.3, mapped drive; F5 of `a.txt` onto `b.txt` (another link).
**Acceptance**: the same entry: "Cannot copy/move a file to itself.", nothing changed; another link:
"overwrite?" as before, `b.txt` becomes an independent copy, `a.txt` intact.

### User Story 5 - Ordinary folder copies and moves work as before (Priority: P1)
**Independent Test**: F5 / F6 of a folder between two different folders (ASCII and Cyrillic names),
also to `\\localhost\C$\...` of another folder (two roots) and into an existing folder of the same
name (merge).
**Acceptance**: copied / moved as before; the merge asks "Confirm Directory Overwrite" as before.

### Edge Cases
- A junction / symbolic link to a folder as the source: compared as the link itself for "the same
  place" (moving the link onto itself deleted the link); its content is only copied, so "into itself"
  is not checked for it (a snapshot).
- A folder above the target that cannot be read is left out of the comparison; the target itself and
  the worker's check still apply.
- WebDAV without ids: two different folders count as one only when their times fall in the same
  seconds AND their paths below the server name agree (e.g. two different WebDAV servers mirroring
  one share with kept folder times) - a false refusal, nothing is lost. A backup folder elsewhere on
  the server merges (probe rows `dav-bak-*`, `dav-twin-merge`).
- A snapshot (shadow copy, Previous Versions) is never the live folder; FAT ids need equal times too.
- A folder reachable through two shares of a NAS that gives each share its own volume serial is not
  recognised as one (the old behaviour; review NIT 3).
- A move by name onto another case of itself keeps 092's case-only rename.

## Requirements *(mandatory)*
- **FR-001**: A copy or move MUST NOT merge a folder into itself, whatever path names the target.
- **FR-002**: A move MUST NOT move a folder into itself or into one of its subfolders, whatever path
  names the target.
- **FR-003**: Nothing of the source tree (files or folders, empty ones included) may be deleted or
  changed when the target is the source itself; a move that cannot tell refuses.
- **FR-004**: A copy of a hard-linked file onto the same directory entry through an alias MUST be
  refused with "Cannot copy/move a file to itself."; onto another link it MUST behave as before.
- **FR-005**: Every case where the target is another folder or file MUST behave exactly as before.
- **FR-006**: No new string, no plug-in interface change, no configuration change; the cost is a
  handful of attribute reads per operation (not per file).

## Success Criteria *(mandatory)*
- **SC-001**: `probe/folderalias_probe.ps1 -Expect107`: 0 FAIL; on `Debug_x64_pre107` the moves through
  an alias change or delete parts of the source tree.
- **SC-002**: saltests (13,588 before) pass with the new checks; the strict encoding guard reports 0.
- **SC-003**: Debug + Release builds; the probes of 103, 098, 099, 106 give the same results as on the
  build before this feature.
