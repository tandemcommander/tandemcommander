# Feature Specification: checksum lists are read in the encoding they were written in

**Feature Branch**: `117-checksum-lists`
**Created**: 2026-10-05
**Status**: Implemented - GUI runs pending
**Input**: `specs/NEXT-WORK.md`, plug-in leftovers item 4 (left by feature 104): "checksum: a
checksum list written in the code page with accented names reports those files as missing (no
encoding detection of the list file)".

## Clarifications

### Session 2026-10-05

The maintainer asked for autonomy; the decisions are the author's recommended options. No GUI run
was possible (the installed program was in use, and another agent ran GUI probes of older
features): the measurements are scratch measurements of the tools and of the Windows primitives,
code reading and an offline model of the read path built on the product's helper
(`research.md`); the GUI evidence is the pending probe (`quickstart.md`).

- Q: What encodings do lists come in? -> A: Measured (`research.md` A): UTF-8 without a mark
  (coreutils, 7-Zip, Tandem 0.1.x), UTF-8 with a mark (Total Commander for Unicode names,
  PowerShell `Out-File -Encoding utf8`), UTF-16 LE with a mark (PowerShell 5.1 `>` / `Out-File`),
  the code page (Open Salamander, older tools, PowerShell `Set-Content` - with best fit). The
  plug-in read only the first correctly; a marked UTF-8 or UTF-16 md5/sha list was refused
  entirely.
- Q: How is the encoding decided? -> A: **Once per file**: a byte order mark; else UTF-16 by its
  NUL bytes; else UTF-8 when the whole file is (WTF-8); else the code page. Never per line.
- Q: OEM lists (DOS tools)? -> A: **Not guessed.** No signal tells OEM from the code page; trying
  OEM when the code-page name is missing is a per-line fallback that can name a different file.
  Their accented names are reported missing - recorded limit.
- Q: A name that cannot be converted? -> A: Reported missing, shown with U+FFFD, never looked up;
  the conversion is exact (no best fit, no look-alike).
- Q: Name matching against the disk? -> A: The file system's rule (feature 092) - the path is
  handed to it; but no pattern matching: the look-up took `?` `*` `<` `>` `"` as wildcards
  (`???.txt` - what `Set-Content` writes for a Cyrillic name - found `abc.txt`). Such names are
  reported missing; a folder named in a list is not a file.
- Q: `./name`, `..`, `//`? -> A: Resolved lexically, never above the drive or share - since 0.1.0
  every such line was "missing" (the extended-length path keeps them literally). Absolute names
  work **only on the list's own drive or share** (code review B1: a UNC name made Windows connect
  to the server and send the user's credentials); any other is missing without a look-up.
- Q: GNU coreutils' escaped lines (`\<hash> *sub\\x.txt`)? -> A: Unescaped (they were refused).
- Q: Writing - keep the format? -> A: **Not for md5/sha**: measured, GNU coreutils read none of
  the plug-in's lists (CRLF: the CR is taken as part of every name) and 7-Zip refuses any comment
  line. They are now written as `sha256sum` writes them: UTF-8, LF, no comment line. SFV is
  unchanged (CRLF and the `;` header are its convention).

## User Scenarios & Testing

### User Story 1 - A list from another tool verifies (Priority: P1)

A user verifies a `.md5` / `.sha1` / `.sha256` / `.sfv` list written by Open Salamander, Total
Commander, PowerShell or coreutils, with Czech, Cyrillic or Chinese names.

**Acceptance Scenarios**:

1. **Given** a code-page list naming `<c-caron>e<s-caron>tina.txt`, **When** verified, **Then**
   the file is found and checked (was "missing").
2. **Given** a UTF-8 list with a byte order mark or a UTF-16 list, **When** verified, **Then**
   every file is checked (was "not a checksum file").
3. **Given** `voil<U+00E0>.txt` and `voila.txt` with different content, **When** any list names
   one of them, **Then** that one is checked - never the other.

### User Story 2 - A broken or ambiguous name is reported, never matched elsewhere (P1)

1. **Given** a list line `???.txt` (a code-page writer's loss), **When** verified, **Then**
   "missing" - not `abc.txt`.
2. **Given** a marked UTF-8 list with a byte that is not UTF-8, **When** verified, **Then** that
   line is "missing" (shown with U+FFFD) and the others are checked.

### User Story 3 - Paths written by find-based scripts verify (P2)

1. **Given** lines `./sub/x.txt`, `sub/../x.txt`, `sub//x.txt`, **When** verified, **Then** the
   files are found (were "missing").

### User Story 4 - Lists written by Tandem are read by other tools (P2)

1. **Given** a `.sha256` list saved by Calculate, **When** `sha256sum -c` (Git for Windows) or
   `7z t -thash` checks it, **Then** every file is OK (both failed before).
2. **Given** that list, **When** Tandem verifies it, **Then** every file is OK.

### Edge Cases

- A list that is valid UTF-8 by accident while meant as the code page (every non-ASCII byte pair
  forms a UTF-8 character) is read as UTF-8 - recorded residual, as in Total Commander.
- A list of two concatenated marked lists (a mark at a line start) - read.
- UTF-32 lists - not supported (no measured tool writes them).
- A double-byte code page with a broken sequence - only that character is lost.
- A path longer than 3 x MAX_PATH bytes still aborts the Verify (pre-existing, recorded).

## Requirements

- **FR-001**: The list's encoding MUST be decided once for the whole file (mark, UTF-16 by NUL
  bytes, UTF-8 if the whole file is WTF-8, else the code page).
- **FR-002**: The conversion MUST be exact; an unconvertible byte or unit MUST make its name
  unusable (reported missing, shown with U+FFFD), never another name.
- **FR-003**: Names with control characters or `* ? < > " |` MUST be reported missing without a
  look-up; the look-up MUST NOT interpret patterns; a folder MUST be "missing".
- **FR-004**: `.` / `..` / empty components MUST be resolved without climbing above the root;
  an absolute name MUST be used only on the list's own drive or share - any other (every UNC,
  `\\?\`, `\\.\` spelling included) MUST be reported missing without any file-system call (no
  connection to a server a list names); trailing dots/spaces MUST be kept; a `:` other than a
  drive letter's makes a name unusable.
- **FR-008**: NUL bytes at the end of the file or of a line MUST NOT change the result; a NUL
  inside a line MUST make that name unusable, never cut it.
- **FR-005**: GNU-escaped hash lines MUST be unescaped.
- **FR-006**: md5/sha* lists MUST be written UTF-8, LF, without a comment line; SFV unchanged.
- **FR-007**: No plug-in interface change (107), no registry change, no new string.

## Success Criteria

- **SC-001**: The probe (`quickstart.md`) passes on this build and shows the old behaviour on
  the build before (pending - GUI).
- **SC-002**: saltests cover the detection, the conversion (all single bytes of 18 code pages),
  NUL bytes, the name and path rules incl. 16 foreign spellings - 14,441 -> 14,576 / 0.
- **SC-003**: The offline model over the 16 fixture lists agrees with every expected verdict
  (58 rows, 0 mismatches).
