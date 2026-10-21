# Feature Specification: Adding into a ZIP that holds names differing only in case replaces only the named member

**Feature Branch**: `290-zip-add-case-twins`
**Created**: 2026-10-21
**Status**: Draft
**Input**: Backlog item `adding-a-file-into-a-zip-that-holds-names-differing-only-in` - "Adding a file
into a ZIP that holds names differing only in case can replace the other twin". From backlog item adding-a-file-into-a-zip-that-holds-names-differing-only-in.

## Background (measured at 1e402ea2)

Since feature 271 a ZIP that holds, in some folder, two names that differ only in case ("case
twins": `A.txt` and `a.txt`, folders `D` and `d`) is listed case-sensitively: the panel shows `D` and
`d` apart, and copying out or deleting acts only on the selected twin. Adding files INTO such an
archive (Copy or Move from a disk panel into the archive panel) still matches the files being added
against the archive's members ignoring case, and asks to overwrite - and replaces - a member the
user did not name.

Probe `zip290_probe.ps1` on the build of HEAD (hidden desktop; Copy, OK, Yes to every overwrite
question): **6 FAIL, 12 PASS**.

1. ZIP-ADDDIR - archive `D/x.txt`, `d/y.txt`; the user is in `t.zip\d` (which lists only `y.txt`)
   and adds `x.txt`: one question naming `t.zip\D\x.txt`, Yes -> `D/x.txt` is gone.
2. ZIP-ADDFILE - archive `A.txt`, `a.txt`, `z.txt`; adding `a.txt` asks twice, Yes to both ->
   only `a.txt` (new) is left, `A.txt` is lost.
3. ZIP-ADDFOLDER - archive `D/x.txt`, `d/y.txt`; adding the disk folder `d` (holding `x.txt`) into the
   archive's root: `D/x.txt` is replaced - the part of the name below the panel's folder is compared
   ignoring case too.
4. In a Unix-made twin ZIP (UNIX-ADDFILE, UNIX-ADDFOLDER) adding `a.txt` replaced **`A.txt`** (the
   first case-insensitive match) and kept the old `a.txt`; adding folder `d` replaced `D/x.txt`. The
   item's premise that a Unix-made ZIP already matches by exact name is not true: only the panel's
   folder is compared exactly there (UNIX-ADDDIR passes), the rest ignoring case.
5. ZIP-NEWNAME - archive `A.txt`, `a.txt`, `b.txt`; adding `B.txt` asks to overwrite `b.txt`
   (today's case-insensitive behaviour, changed by this feature - see Edge Cases).
6. Controls without twins (ZIP-CONTROL, UNIX-CONTROL: `README.txt`, add `readme.txt`): one question,
   the member replaced - kept as they are.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Adding a file into a twin ZIP replaces only the file of that exact name (Priority: P1)

A user copies (or moves) a file from a disk folder into a ZIP that holds `A.txt` and `a.txt`, or into
the folder `d` of a ZIP that holds folders `D` and `d`.

**Why this priority**: today the member the user did not name is deleted - data loss, and since 271
the deleted member is not even in the folder the user is looking at.

**Independent Test**: hidden-desktop probe with .NET-written ZIPs (host MS-DOS / Windows, and the
same patched to Unix): add `x.txt` into `t.zip\d`, add `a.txt` into the root, add the folder `d` into
the root; answer Yes; read the archive back.

**Acceptance Scenarios**:

1. **Given** a ZIP holding `D/x.txt` and `d/y.txt`, **When** `x.txt` is added into `t.zip\d`,
   **Then** no overwrite question is asked and the archive holds `D/x.txt` (old content), `d/x.txt`
   (new) and `d/y.txt`.
2. **Given** a ZIP holding `A.txt`, `a.txt` and `z.txt`, **When** `a.txt` is added and the one
   overwrite question (naming `a.txt`) is answered Yes, **Then** `a.txt` holds the new content and
   `A.txt` keeps its own.
3. **Given** a ZIP holding `D/x.txt` and `d/y.txt`, **When** the disk folder `d` holding `x.txt` is
   added into the root, **Then** `D/x.txt` keeps its content and `d/x.txt` is added.
4. **Given** any of these archives made on Unix, **When** the same is done, **Then** the result is
   the same.

### User Story 2 - Ordinary ZIPs behave as before (Priority: P1)

**Independent Test**: a ZIP without twins holding `README.txt` (Windows-made and Unix-made): adding
`readme.txt` asks once and replaces the member, exactly as before.

**Acceptance Scenarios**:

1. **Given** a Windows-made ZIP whose names never differ only in case, **When** a file is added whose
   name differs from a member's only in case, **Then** the overwrite question is asked and Yes
   replaces the member (stored under the added file's name, as before).
2. **Given** a Unix-made ZIP without twins, **When** the same is done, **Then** the question is asked
   and Yes replaces the member under the member's own spelling (as before).

### Edge Cases

- A twin ZIP and an added file whose name differs only in case from a member that has no twin
  (`b.txt` in the archive, `B.txt` added): matched by exact name, so `B.txt` is added beside `b.txt`
  without a question and `b.txt` keeps its content (known change; nothing is replaced that the user
  did not name - ZIP-NEWNAME row).
- Twins anywhere in the archive make the whole archive exact for adding (the same per-archive
  decision the listing makes since 271), also for folders that hold no twins themselves.
- A file and a folder of one folder whose names differ only in case are twins; names equal only by
  the legacy byte fold or only by the Unicode rule are twins (252's rule).
- Moving a folder into the archive: the check "does the archive already hold this folder or
  something in it" follows the same exact rule in a twin ZIP.
- Not enough memory to collect the archive's names for the check: the operation is refused with the
  existing low-memory error and the archive is not changed.
- An exact duplicate member (the same name stored twice) is still matched and asked about as before.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When files are added into a ZIP that holds, in any folder, two names that differ only
  in case (252's rule, the one 271's listing uses), the plug-in MUST match each added item against
  the members by its exact name - the panel's folder and every part below it - whatever system made
  the archive.
- **FR-002**: In such an archive an overwrite question MUST be asked, and a member replaced, only
  for a member whose name is exactly the added item's name.
- **FR-003**: A ZIP without twins MUST behave exactly as before - a Windows-made one matches ignoring
  case, a Unix-made one compares the panel's folder exactly and the rest ignoring case, with the same
  questions and the same stored names.
- **FR-004**: The check MUST NOT read the archive more often than before; it uses the central
  directory the add already holds in memory.
- **FR-005**: If the check cannot be made (low memory), the add MUST be refused without changing the
  archive.
- **FR-006**: No plug-in interface change; the twin rule is a header-only, unit-tested rule under
  `src/common/` (252's, extended to full paths).

### Key Entities

- **Case twins**: two byte-different names in one folder that the program's case-insensitive
  comparison (the legacy byte fold or the file system's ordinal rule) takes for the same name.
- **Path prefix**: a member's path up to the end of one of its parts; two byte-different paths are
  equal ignoring case exactly when some folder holds twins, so twins exist in the archive exactly when
  two byte-different prefixes are equal ignoring case.

## Success Criteria *(mandatory)*

- **SC-001**: In the probe, the rows ZIP-ADDDIR, ZIP-ADDFILE, ZIP-ADDFOLDER, ZIP-NEWNAME,
  UNIX-ADDFILE and UNIX-ADDFOLDER fail before and pass after; ZIP-CONTROL, UNIX-CONTROL and
  UNIX-ADDDIR pass before and after.
- **SC-002**: The new rule's unit checks pass, the build and the existing ZIP probes of 110 and 271
  stay green.
- **SC-003**: Adding into an archive reads its central directory no more often than before.

## Clarifications

### Session 2026-10-21

- Q: The item says a Unix-made ZIP "already" matches by exact name; measured, it does not (UNIX-ADDFILE
  replaced `A.txt` when `a.txt` was added). Do Unix-made twin ZIPs get the exact rule too? → A: yes -
  the item's *Expected* is "Adding into a ZIP that holds case twins matches existing entries by exact
  name ... so `a.txt` replaces `a.txt` and `A.txt` is untouched", for any ZIP holding twins; a
  Unix-made ZIP without twins keeps its rule. (autonomous run: item)
- Q: In a twin ZIP, should an added name that has only a case-insensitive match (`B.txt` vs `b.txt`)
  still be asked about? → A: no - matched by exact name as the item's *Expected* says; nothing is
  lost (the member stays, the file is added). (autonomous run: item)
- Q: Low memory while collecting the names → A: refuse the add with the existing low-memory error
  (the conservative choice: neither a guess "no twins" that could replace the other twin nor a guess
  "twins" that would change an ordinary archive). (autonomous run: conservative)

## Assumptions

- Assumption (autonomous run): the decision is made by the add from the archive itself (the core
  hands `PackToArchive` no listing data, 271 contract point 4); it uses the same rule as the listing,
  so the panel and the add agree.
- Assumption (autonomous run): the overwrite question's text and buttons do not change; no new UI
  string.
- The core, the 7-Zip, TAR and SFTP plug-ins are not changed.
