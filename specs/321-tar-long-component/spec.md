# Feature Specification: An archive member whose name the panel cannot hold never crashes the program

**Feature Branch**: `321-tar-long-component`  
**Created**: 2026-10-23  
**Status**: Draft  
**Input**: Backlog item `opening-a-tar-whose-member-name-has-a-300-letter-component` - "Opening a tar whose member name has a 300-letter component crashes the program". From backlog item opening-a-tar-whose-member-name-has-a-300-letter-component.

## Background (measured at 26c31a9d)

Debug x64 build of `main`; hidden-desktop probe `specs/306-tar-pax-headers/probe/pax306_probe.ps1
-Only GNU-TOOLONG` (archive made by Python `tarfile`, GNU format): the program closes - "A problem
has occurred, forcing Tandem Commander to close", bug report "Error Number: 2 / Description: Stack
memory corruption" under `CFilesWindow::CommonRefresh`.

Root cause (feature 307's research, still valid at HEAD): the member lies at the archive root, so
the tar reader hands it to the panel listing with no folder part. The listing's "name too long"
bound (feature 222: refuse a name of 780 bytes or more, or a file name over 255 UTF-16 units) is
applied only when a folder part is given, so the 904-byte name enters the listing, and the panel
formats every name into fixed 780-byte buffers - a stack overflow. Names of 604 bytes (200
letters) and 769 bytes (255 letters) fit and list fine. Every file-system plug-in (FTP, SFTP,
registry editor, network, undelete, folders, portable devices) lists with no folder part too.

A stopped run (feature 307, `origin/307-tar-long-component`) fixed both layers; its second
review rejected one part: its GNU refusal applied the listing's depth bound also while
extracting the whole archive, so deep members NTFS takes were silently skipped and "Delete archive
after unpacking" could delete the archive. Feature 308 has since made the PAX refusal
pass-dependent (the depth bound only while listing; an extraction refuses only a component over
255 UTF-16 units, reports a refused member it was asked for and fails). This feature carries over
307's work and gives the GNU refusal that same pass-dependent rule.

## Clarifications

### Session 2026-10-23

- Q: Fix the panel buffers for names of any length, or keep every listed name within the length those buffers are sized for? → A: keep every listed name under the existing bound: the listing refuses a name of 780 bytes or more also when no folder part is given; dozens of panel buffers are sized for that bound, and the listing already enforces it for archive members inside folders (autonomous run: conservative - the item allows "and/or"; the least change that makes the crash impossible for every plug-in; feature 307's answer, unchanged by its reviews)
- Q: For a name given with no folder part, is the 255-UTF-16-unit file-name rule also applied? → A: no - only the 780-byte buffer bound; file-system plug-ins list such names today and must keep doing so (autonomous run: conservative - keeps the existing behaviour for every case the item does not name)
- Q: How does the tar plug-in treat a GNU long name the listing cannot hold? → A: exactly as a PAX path is treated since feature 308: while listing, the member is not listed and the system's "(206)" text with the whole path is shown once; in an extraction only a component over 255 UTF-16 units is refused, and an extraction asked for a refused member reports it and fails (autonomous run: item - *Expected*, *Notes* and *Log* 2026-10-22 / 2026-10-23)
- Q: Are classic ustar names and the other formats of the tar plug-in changed? → A: no; a classic ustar name (at most 100 + 155 bytes) cannot exceed the bounds, and other formats keep their behaviour (autonomous run: conservative - scope)
- Q: Does feature 307's review-1 change of the folder-name rule (a top-level folder name is not bounded by bytes while listing) stay? → A: yes - it restores 0.1.10 behaviour for a top-level folder of 86-255 CJK letters given by a GNU long name, and review 2 verified it (autonomous run: conservative - keeps existing behaviour)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A tar with an over-long GNU member name opens (Priority: P1)

A user opens a tar archive (crafted or damaged, or written by a tool that allows it) whose member
has a GNU long name with a component longer than any file system takes. The archive opens, the
user is told that member cannot be listed (the system's "file name too long" text with the path),
and every other member lists and extracts normally.

**Why this priority**: today the program closes on opening, before the user can do anything.

**Independent Test**: probe row GNU-TOOLONG (the 300-letter component, then a normal member).

**Acceptance Scenarios**:

1. **Given** a tar with a GNU long name of 300 CJK letters + `.txt` and a member `ok.txt`,
   **When** the user opens it in a panel, **Then** the program keeps running, a message with
   "(206)" and the path is shown, and Copy of everything extracts `ok.txt` only.
2. **Given** a tar with a GNU long name whose folder part is longer than the listing holds
   (e.g. 12 components of 200 letters) and other members, **When** opened, **Then** that member
   alone is refused with the same message and the others list and extract.
3. **Given** a tar with a GNU long name of 302 bytes in three normal components, **When** opened
   and copied out, **Then** it is listed and extracted whole (unchanged).

---

### User Story 2 - Unpacking a deep GNU tree keeps every member (Priority: P1)

A user unpacks a whole tar (Unpack, or Unpack with "Delete archive after unpacking") whose GNU long
names are deeper than a panel listing holds but every component of which a file system takes.

**Why this priority**: review 2 of feature 307 measured data loss here - members silently skipped,
the archive then deleted.

**Independent Test**: probe rows with a deep GNU tree (30 files under 10 folders of 29 letters +
`ok.txt`): whole-archive Unpack extracts all 31; with a member whose component is over 255 units,
the Unpack reports it, fails, and the archive is not deleted.

**Acceptance Scenarios**:

1. **Given** a GNU tar with 30 files whose folder part is 299 bytes and `ok.txt`, **When** the user
   unpacks the whole archive, **Then** all 31 files are written (as 0.1.10 does).
2. **Given** the same with "Delete archive after unpacking", **When** unpacked, **Then** all 31
   files are written before the archive is deleted.
3. **Given** a GNU tar with the 300-letter component and `ok.txt`, **When** unpacked whole with
   "Delete archive after unpacking", **Then** `ok.txt` is written, the "(206)" text with the path
   is shown, the operation fails and the archive is kept.

---

### User Story 3 - No plug-in listing can overflow the panel (Priority: P2)

Whatever plug-in lists a name of 780 bytes or more with no folder part, the program refuses that
entry through the plug-in's existing "could not add" path instead of corrupting memory.

**Why this priority**: the same crash is reachable from every file-system plug-in and from any
archive plug-in that lists a root member with no folder part.

**Independent Test**: unit checks of the listing's name rule (no folder part: 779 bytes accepted,
780 refused; a 300-letter ASCII name accepted); the tar row with the plug-in's own refusal
disabled (negative control) no longer crashes.

**Acceptance Scenarios**:

1. **Given** a plug-in adds a 904-byte name with no folder part, **When** the listing receives it,
   **Then** the addition fails (as it already does for the same name inside a folder) and the
   program does not crash.
2. **Given** a file-system plug-in adds a 300-letter ASCII name or a 600-byte name with no folder
   part, **When** the listing receives it, **Then** it is accepted as today.

---

### User Story 4 - ZIP and 7-Zip archives with the same name (Priority: P3)

**Independent Test**: probe rows ZIP-TOOLONG (Python `zipfile`) and 7Z-TOOLONG (7-Zip), each with
the 904-byte name and `ok.txt`: the program does not crash.

**Acceptance Scenarios**:

1. **Given** that ZIP or 7-Zip archive, **When** opened, **Then** the program keeps running;
   whether `ok.txt` is listed depends on the plug-in's existing handling of a refused entry and
   is recorded, not changed by this feature.

### Edge Cases

- A GNU long name with a component of exactly 255 UTF-16 units: listed (the boundary).
- A GNU long name followed by a PAX path for the same member: the PAX path wins (feature 306);
  the rule applies to the effective name.
- A GNU long name inside a .deb's `data.tar`: the listing prefix `data\` is counted (feature 306's
  rule).
- A top-level folder of 100 CJK letters given by a GNU long name: listed and extracted as in
  0.1.10; its contents whose folder part the listing cannot hold are refused while listing.
- Several refused members: only the first is named, once per listing (as in 306 / 308).
- A name of 780+ bytes in a folder of a plug-in's listing: already refused (unchanged).
- "Simple icons in archives" and a name of 777-779 bytes ending in a long extension: no overflow.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The panel listing MUST refuse an entry whose name is 780 bytes or longer also when
  the plug-in gives no folder part, for files and for folders.
- **FR-002**: For an entry with no folder part, the listing MUST keep accepting every name shorter
  than 780 bytes, including names over 255 UTF-16 units and folder names over 255 bytes.
- **FR-003**: The rules for entries with a folder part MUST stay exactly as they are (feature 222).
- **FR-004**: While the panel listing is built, the tar plug-in MUST apply the listing rule of
  features 306 / 308 to a member whose effective name comes from a GNU long name: a component over
  255 UTF-16 units, or a folder part / a folder's name inside a folder part over the listing's
  limit (counting the .deb prefix), refuses that member alone. A top-level folder (no folder part,
  no prefix) is not limited by its name's bytes.
- **FR-005**: In every extraction pass (one file, selection, whole archive) the tar plug-in MUST
  refuse a GNU-named member only for a component over 255 UTF-16 units - never for its depth; an
  extraction asked for a refused member reports it (the "(206)" text with the whole path) and
  fails, so "Delete archive after unpacking" never fires.
- **FR-006**: A refused GNU member MUST be reported like a refused PAX member: the system's "(206)"
  text and the whole path; never cut, never renamed, never silently dropped.
- **FR-007**: Members named by a classic ustar header and members whose names already pass the
  rule MUST be listed and extracted exactly as before.
- **FR-008**: The name rules of FR-001 / FR-002 and FR-004 / FR-005 MUST be pure, unit-tested rules.
- **FR-009**: The panel code that looks up an entry's association from its extension MUST NOT
  write past its 780-byte buffer for any name the listing accepts; an extension that does not fit
  has no association (never looked up cut).

### Key Entities

- **Listing entry**: a name (UTF-8, its byte length), an optional folder part, file or folder.
- **Tar member name source**: classic header, GNU long name, PAX path (the effective one).
- **Pass over the archive**: listing, or an extraction (one file, selection, whole archive).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Opening the GNU-TOOLONG archive: 0 crashes (before: the program closed every time);
  the other member extracts.
- **SC-002**: Whole-archive Unpack of a deep GNU tree writes every member (31 of 31); with a
  refused member and "Delete archive after unpacking", the archive still exists afterwards.
- **SC-003**: The 306 and 308 probes' existing rows still pass.
- **SC-004**: The unit checks of the name rules pass, with the 779 / 780-byte boundary covered.
- **SC-005**: With the tar plug-in's GNU refusal disabled (negative control), opening GNU-TOOLONG
  no longer crashes (the listing refuses the entry).

## Assumptions

- Assumption (autonomous run): the 780-byte bound is the one the panel's buffers are sized for
  (feature 222 already enforces it inside folders); names below it are safe in the listing.
- Assumption (autonomous run): a plug-in that receives a failed addition already handles it; no
  plug-in interface header changes.
- Assumption (autonomous run): the 7-Zip row's archive is made with the installed 7-Zip; without
  it the row is NOT DRIVEN.
- No UI strings are added: the refusal message is the system's error text and an existing title.
