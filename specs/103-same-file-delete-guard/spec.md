# Feature Specification: Never delete the source as "the existing target"

**Feature Branch**: `103-same-file-delete-guard`
**Created**: 2026-10-03
**Status**: Draft
**Input**: recorded by feature 092's S3 review (`specs/092-name-identity-unicode/fix-log.md`, "Recorded, not changed" item 1) and `specs/NEXT-WORK.md` item 5 ("Delete-then-retry trusts a name rule alone - the first thing to do here"); researched before the work (`research.md`); the maintainer asked for thoroughness and is away.

## Clarifications

### Session 2026-10-03

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Is the defect real, and can it be shown without a macOS server? -> A: Yes. A small WebDAV server that folds names like a macOS server (`probe/davnorm.py`) makes Windows answer a rename onto another spelling of the same file with "already exists". On the build before this feature **four routes deleted the file**: Quick Rename and F6 to another spelling (after an overwrite question with two identical lines), the same F6 with *Confirm file overwrite* off (no question), and F6 between two names of one server (`\\localhost@port` / `\\127.0.0.1@port`): the move copied the file onto itself and then deleted the source (`research.md` sections 0 and 4).
- Q: Which operations? -> A: Every site where the program deletes or overwrites an existing target that can be the source under another name or path: the core rename/move (`DoMoveFile`, also *Change Case* and directory moves), Quick Rename (`RenameFileInternal`), the core copy (`DoCopyFile`, which also carries every move between two roots), and two plug-in renames found by the sweep - Renamer and PictView's rename of the viewed file. The 8.3-name tidy-ups, directory creation, viewer *Save selection*, archive unpack and the FTP/SFTP plug-ins have no user-named source to lose or restore what they rename (`research.md` section 1); the ZIP plug-in's "new archive overwrites a selected source" is another defect class - recorded.
- Q: How is "the target is the source" recognised? -> A: By the file system's identity - volume serial + file id (128-bit where available), read with an attribute-only open. Where a server reports no ids (WebDAV: 0), equal size and times mean "possibly the same", never "another file".
- Q: What happens then? -> A: A **rename or move** goes through a temporary name in the source's folder (source -> `salXXX` -> target). It checks itself: if the target name disappears with the source out of the way, it was the source and the rename is done; if it is still there, it is another file or another hard link, the source is renamed back and the old handling (overwrite question, then delete and retry) follows unchanged. A **copy** - and a move between two roots, which is copy + delete - onto the source itself is **refused** with the existing message "Cannot copy (move) a file to itself." (Skip / Skip All / Cancel / Retry), and the source is not deleted.
- Q: Hard links? -> A: Unchanged. NTFS itself renames a link onto another link of the same file (measured); a copy onto another hard link keeps the old handling (NTFS removes that link and writes an independent copy - the source's name and data stay).
- Q: False positives? -> A: Only for a **copy** on a file system without ids: a different file with the same size and the same last-write and creation seconds is refused as "to itself" (nothing lost; documented, probe dav-twcp). A rename/move tells such files apart (dav-twin).
- Q: Strings, interface? -> A: No new string (the two "to itself" texts and the *Copy Error* / *Move Error* captions exist), no plug-in interface change (stays 107), no configuration change. The rule is header-only (`src/common/salsamefile.h`) so the core, saltests and the two plug-ins share it.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Renaming a file to another spelling of its name never deletes it (Priority: P1)
**Independent Test**: on the folding WebDAV server, `cafe`+U+0301`.txt` (NFD) renamed to `Caf`+U+00E9`.txt` by Quick Rename, by F6 with the new name, and by F6 with *Confirm file overwrite* off.
**Acceptance**: the file exists afterwards under the new name with its content; no overwrite question; no deletion request reaches the server.

### User Story 2 - Copying or moving a file onto another path of itself never destroys it (Priority: P1)
**Independent Test**: F5 and F6 of a file onto an alias of its own folder: a SUBST letter, `\\localhost\C$`, a junction, the second server name of the WebDAV server.
**Acceptance**: the file and its content are unchanged; the user sees "Cannot copy a file to itself." / "Cannot move a file to itself." instead of an overwrite question and a sharing error; a move does not delete the source.

### User Story 3 - Ordinary overwrites, hard links and case changes behave as before (Priority: P1)
**Independent Test**: F5/F6/Quick Rename onto an existing different file (NTFS and WebDAV, also twins with equal size and times), a plain case change, a case-sensitive folder with `a.txt` and `A.txt`, hard links, the 8.3 name of the file.
**Acceptance**: the same questions and results as the build before this feature (except the documented WebDAV-twin copy refusal).

### Edge Cases
- The temporary rename fails half-way and the way back fails too: the error names the temporary path (never silent).
- Every temporary name is taken; the source cannot be renamed (locked); the identity cannot be read (target unopenable): a rename/move takes the self-checking route, a copy the old handling.
- Directories (rename/move route), symbolic links as the final component (a rename compares the link itself, a copy the data through it).

## Requirements *(mandatory)*
- **FR-001**: No route may delete, truncate or open for overwriting an existing target that is the source, or that cannot be shown not to be the source, when doing so can destroy the source's only copy.
- **FR-002**: A rename/move onto another spelling of itself MUST complete (through a temporary name) instead of failing or deleting.
- **FR-003**: A copy (and a move between two roots) onto the source itself MUST be refused with the existing "Cannot copy/move a file to itself." texts, and the move MUST NOT delete the source.
- **FR-004**: Every case where the target is another file MUST behave exactly as before (questions, results), including hard links, case-only renames and case-sensitive folders.
- **FR-005**: The identity check MUST run only on the "already exists" path (no cost for operations without a collision).
- **FR-006**: No new string, no plug-in interface change, no configuration change.

## Success Criteria *(mandatory)*
- **SC-001**: `probe/samefile_probe.ps1`: 0 cases lose data on this build (4 on the build before it), every case shows the windows this feature expects (`-Expect103`).
- **SC-002**: saltests (13,326 before) pass with the new rule's checks; the strict encoding guard reports 0.
- **SC-003**: Debug + Release builds; the probes of 092 (case_only, focus), 095, 096, 098, 099 and 101 give the same results as on the build before this feature.
