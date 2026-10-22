# Feature Specification: The tar plug-in applies PAX extended headers

**Feature Branch**: `306-tar-pax-headers`  
**Created**: 2026-10-22  
**Status**: Draft  
**Input**: Backlog item `tar-plug-in-ignores-pax-extended-headers` - "tar plug-in ignores PAX extended headers: long or non-ASCII names listed under the ustar fallback name". From backlog item tar-plug-in-ignores-pax-extended-headers.

## Background (measured at 8c6f4d68)

A PAX tar (POSIX.1-2001; Python's `tarfile` default, GNU tar `--format=posix`, bsdtar / Windows
`tar.exe` for long or non-ASCII names) puts a member's real path, size and time into an extended
header (type `x`, for the next member) or a global one (type `g`, for all following members) and
leaves only a fallback in the classic header: the name cut at 100 bytes, non-ASCII letters as `?`,
a size of 0 for members of 8 GiB or more, the time rounded or 0. The tar plug-in skips both header
types as "entries it cannot handle", so it lists and extracts the fallback.

Measured on the Debug x64 build with a hidden-desktop probe (archives made by Python 3.14
`tarfile`; the archive opened in the left panel, Select All, Copy into an empty folder):

| Row | Archive | Result before |
|---|---|---|
| PAX-LONG | `d*100/e*100/f*96.txt` (302 bytes) | only a folder `d*100` (the cut) |
| PAX-CJK | a 200-letter CJK name | error "(123) invalid name" (the fallback is 100 `?`), nothing extracted |
| PAX-TWINS | two 200-letter CJK names (same fallback) | the same error, nothing extracted |
| PAX-DEEP | `sub/<200 CJK>.txt` | the same error |
| PAX-MTIME | PAX `mtime=1600000000.25`, classic 1000000000 | extracted with 1000000000 |
| PAX-SIZE | classic size 0, PAX `size=5`, then another member | the data read as a header: "Archive format not recognised" |
| PAX-GLOBAL | `g` `mtime=1500000000`; a member with its own `x` `mtime=1400000000` | both 1000000000 |
| GIT-COMMENT | `g` `comment=<hash>` (what `git archive` writes) | correct (regression row) |
| GNU-LONG | the 302-byte path as a GNU long name | correct (regression row) |

Side finding: a GNU long name with a 300-letter CJK component (900 bytes, more than any file
system takes) crashes the program when the archive is opened ("Stack memory corruption" under
`CFilesWindow::CommonRefresh`). A PAX path of that length would do the same once PAX paths are
applied - this feature therefore refuses such PAX paths; the GNU route and the crash itself are
recorded as an Inbox item (outside this item).

## Clarifications

### Session 2026-10-22

- Q: When a PAX path has a component no file system takes, is the whole archive refused or only that member? → A: only that member: it is not listed or extracted, a message names it, the rest of the archive stays usable (autonomous run: conservative - loses no other member, never silent, nothing cut)
- Q: What happens with a malformed extended header (bad record length, no `=`, invalid `size`)? → A: the archive is refused with the plug-in's existing header error; an invalid `mtime` alone is ignored (autonomous run: conservative - refuses rather than reading on under a guessed layout; a time does not shift the data)
- Q: Is the fraction of a PAX `mtime` kept? → A: yes, to 100 ns (the precision of a Windows file time) (autonomous run: item - "with the header's time")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Members are listed and extracted under their real names (Priority: P1)

A user opens a tar made on Linux, with Python or with Windows `tar.exe` whose members have long
paths (over 100 bytes) or non-ASCII names. The panel shows the real names and Copy / Unpack / F3
create the files under those names.

**Why this priority**: today such members are extracted under a cut path (into a wrong folder)
or not at all; two members collide under one fallback name.

**Independent Test**: probe rows PAX-LONG, PAX-CJK, PAX-TWINS, PAX-DEEP.

**Acceptance Scenarios**:

1. **Given** a PAX tar with a member `d*100/e*100/f*96.txt`, **When** the user copies everything
   out, **Then** the file is created at that whole path with its content.
2. **Given** a PAX tar with a 200-letter CJK name, **When** copied out, **Then** the file has
   exactly that name.
3. **Given** two members whose fallback names are equal, **When** copied out, **Then** both
   files exist under their own names with their own contents.

### User Story 2 - Size and time of the extended header are used (Priority: P2)

**Why this priority**: a wrong size desynchronises the whole archive (the rest is unreadable);
a wrong time is visible after extraction.

**Independent Test**: probe rows PAX-MTIME, PAX-SIZE, PAX-GLOBAL.

**Acceptance Scenarios**:

1. **Given** a member whose extended header says `mtime=1600000000.25`, **When** extracted,
   **Then** the file's write time is 2020-09-13 12:26:40.25 UTC.
2. **Given** a member whose classic size is 0 and whose extended header says `size=5`, followed
   by another member, **When** copied out, **Then** both members are extracted whole.
3. **Given** a global header `mtime=1500000000`, a member without its own value and a member with
   its own `x` `mtime=1400000000`, **When** extracted, **Then** the times are 1500000000 and
   1400000000.

### User Story 3 - A path no file system takes is refused, never cut (Priority: P3)

**Independent Test**: probe row PAX-TOOLONG.

**Acceptance Scenarios**:

1. **Given** a PAX tar whose member path has a component of 300 CJK letters, **When** the archive
   is opened, **Then** a message says the name is too long, the member is not listed, nothing is
   created under a cut or substitute name, and the program does not crash.

### Edge Cases

- `git archive` writes a `g` header with only a `comment`: unchanged, the members are listed as
  before (GIT-COMMENT).
- A record whose value is empty (`path=`) cancels the value for that member (falls back to the
  classic header / no global value), as POSIX defines.
- The same keyword twice in one header: the last one wins.
- A malformed extended header (a record length that does not match, no `=`, an invalid `size`,
  more data than a reasonable bound): the archive is refused with the plug-in's existing
  "header" error, never read on under a guessed layout.
- An invalid or out-of-range `mtime` is ignored (the classic time stays), as Python and GNU tar
  do.
- Data of an extended header padded with NUL bytes after the last record is accepted.
- An extended header followed directly by the end of the archive ends the listing normally.
- GNU long names (`L`) keep working; when both are present the PAX `path` wins (as in GNU tar and
  Python).
- `linkpath` is not applied: the plug-in does not extract links at all (unchanged).
- GNU sparse files written in PAX form (`GNU.sparse.*`) are not reconstructed (unchanged,
  out of scope).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The reader MUST parse the records (`<length> <keyword>=<value>\n`) of `x` and `g`
  headers instead of skipping them.
- **FR-002**: A `path` value MUST replace the member's name (classic or GNU long name); a member
  `x` value takes precedence over a `g` value; an empty value cancels it.
- **FR-003**: A `size` value MUST replace the member's data size (for members whose data is read:
  not for directories and links, which keep size 0).
- **FR-004**: An `mtime` value (decimal seconds, optional sign and fraction) MUST replace the
  member's write time, to 100-ns precision; invalid or unrepresentable values are ignored.
- **FR-005**: Values of a `g` header MUST apply to every following member of the same pass until
  replaced by a later `g` header; each listing / extraction pass starts without global values.
- **FR-006**: A PAX path with a component of more than 255 UTF-16 units MUST NOT be listed or
  extracted; opening the archive (and unpacking the whole archive) MUST show the system's "file
  name too long" text with the member's path, at most once per operation; no shortened or
  substitute name is used.
- **FR-007**: A malformed extended header MUST refuse the archive with the existing header error;
  an extended header over 1 MiB MUST be refused the same way.
- **FR-008**: Archives without PAX headers (ustar, GNU, V7, cpio, compressed) MUST behave exactly
  as before.
- **FR-009**: The record parsing and value rules MUST live in a header-only file under
  `src/common/` with `saltests` checks.
- **FR-010**: No new UI strings (existing error texts only).

### Key Entities

- **PAX values**: per member (`x`) and global (`g`) - path, size, mtime, each unset / cancelled /
  set.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe goes from 9 FAIL / 13 PASS to 0 FAIL; the PAX-* rows PASS and GIT-COMMENT,
  GNU-LONG still PASS.
- **SC-002**: No archive of the regression probes of features 252, 273 and 275 changes its
  result.
- **SC-003**: `saltests` passes with the new checks; a negative control (the reader's PAX branch
  disabled) makes the probe fail again.

## Assumptions

- Assumption (autonomous run): the refusal of FR-006 skips the member and keeps the rest of the
  archive available (the gzip refusal of feature 260 refuses its single member the same way);
  the message is shown when the archive is listed and when the whole archive is unpacked
  without a listing, not on every F3 / Copy of other members (conservative: no repeated boxes,
  never silent).
- Assumption (autonomous run): the FR-006 refusal applies to PAX paths only; GNU long names
  keep their behaviour (the crash is a separate Inbox item - scope rule).
- Assumption (autonomous run): keywords other than `path`, `size`, `mtime` are ignored
  (`linkpath`: links are not extracted; `hdrcharset=BINARY`: the name goes through the plug-in's
  existing UTF-8 / ANSI decision like every other name).
