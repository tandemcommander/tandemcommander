# Feature Specification: Hard-linked names of a tar are listed and copied

**Feature Branch**: `325-tar-listed-hard-links`
**Created**: 2026-10-23
**Status**: Draft
**Input**: User description: "Backlog item tar-copy-of-listed-files-leaves-hard-links-out - Copying the files of a tar folder leaves hard-linked names out silently." From backlog item tar-copy-of-listed-files-leaves-hard-links-out.

## Background

A tar archive written by GNU tar or Python's `tarfile` stores the second (third, ...) name of a
hard-linked file as a *link member*: a header of type `1` without data that names the earlier member
holding the data. A symbolic link is a member of type `2`. The TAR plug-in never lists link members in
the panel. Feature 309 made an extraction that is *asked* for a link member (a whole Unpack, a Copy
of a folder holding it) extract a hard link as a copy of its target when the target was written in
the same operation, and report every other link (the operation then fails and the archive is kept).

A user who opens an archive folder and copies the files shown there never asks for the link members,
because the panel does not show them - the hard-linked names are missing from the target without a
word.

Measured at 0991f43c (Debug build, hidden-desktop probe `link325_probe.ps1`, fixtures by Python's
`tarfile`: `a.txt`, `sub/c.txt`, hard links `sub/b.txt -> a.txt` and `./sub/d.txt -> ./a.txt`):
opening `t.tar\sub`, Select All + Copy writes 1 of 3 files (`c.txt`), no message - also for a
gzip-compressed tar and for a link to a link; a link to a member the archive does not hold is not
listed, so nothing is reported; End + Copy copies `c.txt` (the link is not in the panel); F3 views
`c.txt`; a Copy of the archive root (`a.txt` and `sub`) writes all 4 files (feature 309). 11 PASS /
7 FAIL - the 7 FAIL rows are the defect.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Copying the files shown in an archive folder brings every hard-linked name (Priority: P1)

A user opens a folder inside a tar archive, selects all files shown there and copies them to a folder
on disk. Some of the files are second names of a file stored elsewhere in the archive (outside the
folder).

**Why this priority**: the item's defect - names missing from the target without a word.

**Independent Test**: probe row COPY-INSIDE (and its gzip, chain and big-file variants): Select All +
Copy inside `t.tar\sub` gives every name with the content of the file it names, nothing asked.

**Acceptance Scenarios**:

1. **Given** a tar with `a.txt` and `sub/c.txt` and hard links `sub/b.txt -> a.txt`,
   `./sub/d.txt -> ./a.txt`, **When** the user opens `t.tar\sub`, **Then** the panel shows `b.txt`,
   `c.txt` and `d.txt`; `b.txt` and `d.txt` with the size of `a.txt`.
2. **Given** that panel, **When** the user selects all and copies to an empty folder, **Then** the
   folder holds `b.txt` and `d.txt` with the content of `a.txt` and `c.txt`, and no message is shown.
3. **Given** the same archive compressed with gzip, **When** the same copy runs, **Then** the result
   is the same.
4. **Given** a link to a link (`sub/e.txt -> sub/b.txt -> a.txt`, the target 128 KiB), **When** the
   files of `sub` are copied, **Then** `e.txt` and `b.txt` both hold the 128 KiB of `a.txt`.

---

### User Story 2 - One hard-linked name can be copied or viewed on its own (Priority: P2)

A user copies or views (F3) just one listed hard-linked name.

**Why this priority**: once listed, every panel operation on the name must work - a listed name that
copies as nothing would be a new silent loss.

**Independent Test**: probe rows COPY-FOCUSED, COPY-EXIST and VIEW-LINK.

**Acceptance Scenarios**:

1. **Given** the panel of `t.tar\sub` with `d.txt` focused and nothing selected, **When** the user
   copies, **Then** only `d.txt` is written, with the content of `a.txt`.
2. **Given** the target folder already holds `e.txt`, **When** the user copies the listed `e.txt`,
   **Then** the usual overwrite question names `e.txt`; Yes writes the content of its target.
3. **Given** `d.txt` focused, **When** the user presses F3, **Then** the viewer shows `d.txt` with
   the content of `a.txt` and no message is shown.

---

### User Story 3 - A hard link that cannot be reproduced is reported, not dropped (Priority: P3)

A listed hard link names a member the archive does not hold (or one that holds no data).

**Why this priority**: the item's alternative - an operation that leaves a name out says so.

**Independent Test**: probe row COPY-MISSING.

**Acceptance Scenarios**:

1. **Given** a tar with `sub/c.txt` and `sub/b.txt -> missing.txt`, **When** the user copies the
   files of `sub`, **Then** `c.txt` is written and exactly one message names `b.txt -> missing.txt`;
   the operation ends as failed (feature 309's report).

### Edge Cases

- The target of a selected link is selected too (Copy of the archive root, a whole Unpack): handled as
  feature 309 does (a copy of the written file) - unchanged.
- The target was selected but not written (the user chose Skip at its overwrite question, or its
  name is refused): reported as in feature 309 - unchanged.
- Several selected links name one unselected target: the target's data is written once, under the
  first link's name; the other names are copies of that file. If that first name was skipped by the
  user, the other names are reported (the data is read once per pass).
- A link whose target name holds a `..` component: never matched (feature 309), so it is listed with
  size 0 and reported when copied.
- A chain of links (a link naming a link) is followed to the member holding the data; a cycle or a
  chain that ends in no data member is reported.
- A hard link named like a folder (trailing separator), a hard link whose own name is refused (too
  long, feature 306 / 321): not listed, as before.
- Symbolic links: stay unlisted (as now) - see Assumptions.
- cpio / rpm archives: their links are handled by feature 310 - unchanged.
- The archive is a `.deb`: its `data` and `control` tars behave like any tar.
- Cancel in the progress dialog stops the operation, also while the target's data is read again.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The panel listing of a tar MUST show every hard-link member as a file (not a folder),
  unless its own name is refused or names a folder; its size MUST be the size of the data member it
  names (following a chain of links), or 0 when there is none.
- **FR-002**: An extraction asked for a hard-link member whose target it did not write and was not
  asked for (or whose target is itself such a link) MUST write the target's data under the link's
  name, also when the target lies outside the selection or outside the opened folder.
- **FR-003**: When FR-002 needs data that the single pass over the archive has already passed, the
  extraction MUST read the archive again from its start for that data (compressed archives
  included), within the same operation and progress dialog; Cancel MUST stop it.
- **FR-004**: Several asked links naming one target MUST each be written with the target's content
  (the data written once, the other names copied from that file - feature 309's identity-safe copy).
- **FR-005**: A hard link that cannot be reproduced (no data member of that name, a `..` link name, a
  cycle, the first name of its group skipped) MUST be reported with feature 309's message
  (`name -> link name`, once per operation) and fail the operation after the rest is extracted.
- **FR-006**: Viewing (or otherwise unpacking one) listed hard-link member MUST extract the content of
  the data member it names under the link's file name.
- **FR-007**: Every case feature 309 already handles (the target written in the same operation, the
  target asked but not written, symbolic links, refused names) MUST behave as before.
- **FR-008**: Names stay UTF-8 / WTF-8 and are never cut; the overwrite question for a link written
  from its target's data names the link.
- **FR-009**: The pure decisions (what an extraction does with an asked link, how a chain of links
  resolves to a data member and the size to list) MUST live in `src/common/saltarlink.h` with
  `saltests` checks.

### Key Entities

- **Data member**: a regular file member of the tar that carries the bytes.
- **Hard-link member**: a type-`1` member without data naming an earlier member (data member or
  another link).
- **Deferred link**: a link asked for whose target's data is not available in the current pass; it is
  written in the second pass.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `link325_probe.ps1`: every row PASS after the change (7 rows FAIL before).
- **SC-002**: Feature 309's probe (16 rows), 308's (12) and 306's (30) keep passing - updated only
  where a row encoded the unlisted links.
- **SC-003**: `saltests` reports 0 failed, with new checks for the link decision and the chain
  resolution.
- **SC-004**: Copying the files of a folder never leaves a hard-linked name out without a message.

## Assumptions

- Assumption (autonomous run): the item's first alternative (list hard links, extract them from their
  target's data) is taken - it fixes the defect for every panel operation, while the second (report
  the left-out links) would still leave the names missing.
- Assumption (autonomous run): symbolic links stay unlisted, as now (the item leaves it to the run):
  the plug-in never creates a symbolic link (feature 309), so a listed symbolic link could only ever
  fail; listing it would turn every Copy of a Linux tarball folder that holds one into a failed
  operation. Recorded as a limit.
- Assumption (autonomous run): reading the archive a second time (only when a deferred link exists)
  is acceptable - the stream cannot seek back; a pre-scan of every Copy would cost the second read
  every time.
- Assumption (autonomous run): no new UI strings; the existing report text of feature 309 is reused.
