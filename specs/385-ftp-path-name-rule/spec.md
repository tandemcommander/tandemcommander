# Feature Specification: FTP server folder names compared by the file system's name rule

**Feature Branch**: `385-ftp-path-name-rule`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item ftp-server-path-compare-code-page-fold - implement exactly what it describes (FTP: server folder names compared by the code-page case rule on UTF-8 bytes)." From backlog item ftp-server-path-compare-code-page-fold.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - An upload into one folder never trusts another folder's listing (Priority: P1)

A user connected to a case-insensitive FTP server (a Windows, NetWare, OS/2, VMS, MVS, z/VM,
Tandem or AS/400 server) uploads files into two different folders whose names contain letters
outside ASCII (for example `/Č` and `/Ĝ`). While the first upload is still open, the second one
targets a folder that already holds a file of the same name. Today the plug-in can decide the
two folders are "the same" (the code-page case table folds `Č` and `Ĝ` together on code page
1250) and take the first folder's listing: the file in the second folder is overwritten without
the overwrite question.

**Why this priority**: it is the one consequence that can replace a user's file on the server.

**Independent Test**: a hidden-desktop probe with a local FTP server that announces itself as
Windows: upload 1 into `/Č` kept open at its overwrite question, upload 2 of `x.txt` into `/Ĝ`
where `x.txt` exists. PASS = the overwrite question for `x.txt`, no `STOR x.txt`, the server's
file unchanged.

**Acceptance Scenarios**:

1. **Given** an open upload into `/Č` on a Windows-type server, **When** the user uploads `x.txt`
   into `/Ĝ` which already holds `x.txt`, **Then** the overwrite question for `x.txt` appears and
   the server's `x.txt` keeps its content.
2. **Given** the same setup with ASCII folder names (`/a`, `/b`), **When** the same upload runs,
   **Then** the behaviour is the one of the build before the change (the question appears).

---

### User Story 2 - One folder spelled in two cases is one folder (Priority: P2)

On a case-insensitive server, the same folder reached as `/Čaj` and as `/čaj` is recognised as
one folder by every "same folder" / "inside this folder" decision of the plug-in (the upload
listing cache, the opened-file lock, the listing cache and its invalidation, the panel's path and
history, the refresh after a created folder, the change-on-path notification).

**Why this priority**: a missed match costs an extra listing or a stale cached listing, and for
the opened-file lock two operations on one server file; less direct than story 1.

**Independent Test**: saltests checks of the path rule on every case-insensitive path type.

**Acceptance Scenarios**:

1. **Given** a Windows-type server path `/Čaj/a`, **When** it is compared with `/čaj/A`, **Then**
   they are the same path, and `/čaj` is a prefix of `/ČAJ/a/b`.
2. **Given** a Unix-type (case-sensitive) server, **When** `/Čaj` is compared with `/čaj`, **Then**
   they are different paths (unchanged).

---

### User Story 3 - ASCII paths behave exactly as before (Priority: P1)

Every comparison of server paths made only of ASCII characters gives the same answer as the
build before the change, on every path type, for the "same path" and the "prefix" test.

**Independent Test**: saltests compares the new rule with a copy of the old one over an
exhaustive set of short ASCII paths per path type; the existing FTP probes (215, 224, 233, 277)
pass as before.

**Acceptance Scenarios**:

1. **Given** any two ASCII server paths of any path type, **When** they are compared, **Then** the
   answer equals the old answer.

### Edge Cases

- Case pairs whose UTF-8 forms differ in length (`ɐ` U+0250, 2 bytes, and `Ɐ` U+2C6F, 3 bytes, are
  one letter for Windows): the same path, and the prefix test finds the right boundary.
- Bytes that are not valid UTF-8 / WTF-8 inside a folder name (a legacy server's undecoded
  bytes): compared by the 092 rule for such text (the legacy byte fold, never equal to valid text).
- VMS escaped separators (`^.`, `^[`, `^]`) are part of a name, not separators.
- Empty paths, root paths (`/`, `[000000]`, `'`), trailing separators: unchanged answers.
- The explore's cycle check ("the server put us into a parent folder"): it must stay
  conservative - every real cycle the old rule detected is still detected; the byte-exact
  list of explored paths stays the backstop.
- Fold collisions that are not one letter for Windows (`Č` / `Ĝ`, `ĥ` / `Ĺ` on code page 1250)
  are different folders.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: On the case-insensitive path types (Windows, NetWare, OS/2, VMS, MVS, IBM z/VM,
  Tandem, AS/400) the plug-in MUST decide "the same server path" and "a prefix of the server
  path" by comparing the paths separator by separator and folder name by folder name, each name
  by the file system's name rule of feature 092 (header-only rule for plug-ins).
- **FR-002**: The separators and their roles MUST stay those of each path type (Windows / NetWare
  / OS/2: `/` and `\` are one separator; VMS: unescaped `.`, `[`, `]`; MVS: `.` and `'`; z/VM and
  Tandem: `.`; AS/400: `/`), including the trailing-separator, root and VMS `[000000` rules.
- **FR-003**: For paths made only of ASCII characters the answer MUST equal the old one on every
  path type, for the same-path and the prefix test.
- **FR-004**: The Unix (case-sensitive) and unknown path types MUST stay byte-exact (unchanged).
- **FR-005**: The rule MUST be a pure, header-only function under `src/common/` with saltests
  checks: ASCII equivalence with the old rule, non-ASCII case pairs, fold collisions, different
  UTF-8 lengths, invalid UTF-8, VMS escapes, prefix and same-path tests on every path type.
- **FR-006**: Every existing caller of the server-path comparison MUST receive the new answers
  without change of its own logic; the explore's cycle check MUST keep detecting every cycle the
  old rule detected for real (same or case-equal folder names).
- **FR-007**: No path or name may be cut, and no fixed buffer may be added for the comparison
  (a long name compares whole).

### Key Entities

- **Server path**: the path on the FTP server as the plug-in holds it (UTF-8 / WTF-8 text), with
  a path type that defines its separators and whether case matters.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The upload probe's cross-folder row: before the change `STOR x.txt` without the
  question (the server file replaced); after: the question, no `STOR`, the file intact.
- **SC-002**: saltests: every new check passes; the ASCII equivalence check covers every pair of
  a set of short ASCII paths per path type with 0 differences; a negative control (the old rule)
  fails the non-ASCII checks.
- **SC-003**: The existing FTP probes 215, 224, 233 and 277 give their recorded results.

## Assumptions

- Assumption (autonomous run): AS/400 is included - it is case-insensitive (`FTPIsCaseSensitive`
  is TRUE only for Unix) and used the same per-byte code-page fold; the item's *Expected* names
  "case-insensitive server types".
- Assumption (autonomous run): the server's own case rule is taken to be the Windows one (092),
  as the plug-in already does for names (277, 303); a server whose rule differs is not detected.
- Assumption (autonomous run): the opened-file lock, the listing caches and the other callers
  keep their logic; only the comparison under them changes.
- The upload listing cache's *name* lookup (sorted by the code-page fold, with 303's case-only
  fallback) is out of scope.
