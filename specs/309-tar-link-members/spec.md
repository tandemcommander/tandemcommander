# Feature Specification: Link members of a tar are extracted or reported, never dropped silently

**Feature Branch**: `309-tar-link-members`
**Created**: 2026-10-22
**Status**: Draft
**Input**: Backlog item `tar-unpack-drops-hard-links-and-deletes-archive` - "Unpacking a tar leaves hard-linked files out silently and Delete archive after unpacking then deletes the archive". From backlog item tar-unpack-drops-hard-links-and-deletes-archive.

## Measured before the feature (f0187403, `main`, Debug x64)

Probe `probe/link309_probe.ps1` (fixture `probe/mklink309.py`, Python 3.14 `tarfile`), run on the hidden
desktop -> `probe/result_before.txt`: PASS 8 (7 END rows + UNP-HARD-TWIN-DEL) / FAIL 6.

- UNP-HARD-DEL (`a.txt`, `sub/c.txt`, hard links `sub/b.txt -> a.txt` and `./sub/d.txt -> ./a.txt`,
  Alt+F9 with "Delete archive after unpacking"): 2 of 4 files, no message, `t.tar` **deleted**.
- UNP-HARD-PAX-DEL (a hard link whose target name is in a PAX `linkpath` record): 1 of 2, deleted.
- UNP-HARD-GNU-DEL (a hard link whose target name is a GNU long link name): 1 of 2, deleted.
- UNP-HARD-MISSING-DEL (a hard link to a name that is not in the archive): silent, deleted.
- UNP-SYM-DEL (a symbolic link `s.txt -> a.txt`): silent, deleted.
- COPY-HARD (Select All + Copy from the opened tar): 2 of 4 files, no message.
- UNP-HARD-TWIN-DEL (hard link `A.TXT -> a.txt`, one file on Windows): passes (the link is dropped).

## Clarifications

### Session 2026-10-22

- Q: Is a hard-link member extracted as a copy of its target or as an NTFS hard link to it? → A: A copy - it works on every target file system (FAT, exFAT, network shares) and never ties two of the user's files together; the item allows either (autonomous run: item + conservative)
- Q: Are symbolic links created? → A: No - leaving one out is reported and fails the operation; creating them is a separate question (autonomous run: item, Notes)
- Q: Which link members count - every one in the archive, or only those the operation was asked to extract? → A: Only those asked for (mask / selection), the rule feature 308 applied to refused names (autonomous run: item)
- Q: How is a left-out link reported, given that no new UI text may be added in this run? → A: Like feature 306/308's refused names: one error box per operation with a system error text, the member's name and the name it links to; the first member left out is named (autonomous run: rule - new strings need the maintainer's .slt refresh)
- Q: Are link members now shown in the panel listing? → A: No - the listing is unchanged; the item asks about extraction only (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A hard-linked file arrives under every name (Priority: P1)

A user unpacks a tar made by GNU tar or Python (a backup, a package tree) in which one file has two
names. The tar stores the second name as a link to the first. Both names arrive with the file's content.

**Why this priority**: today the second name is silently missing; with "Delete archive after unpacking"
the archive is deleted and the name is lost.

**Independent Test**: probe rows UNP-HARD-DEL, UNP-HARD-PAX-DEL, UNP-HARD-GNU-DEL, COPY-HARD.

**Acceptance Scenarios**:

1. **Given** a tar with `a.txt` and hard links `sub/b.txt -> a.txt`, `./sub/d.txt -> ./a.txt`, **When**
   the user unpacks the whole archive with "Delete archive after unpacking", **Then** `sub/b.txt` and
   `sub/d.txt` hold `a.txt`'s content, nothing is asked, and only then the archive is deleted.
2. **Given** a hard link whose target name is longer than the tar header holds (a PAX `linkpath`
   record, a GNU long link name), **When** it is unpacked, **Then** it is extracted the same way.
3. **Given** the opened archive, **When** the user selects all and copies, **Then** the link members
   inside a copied folder are extracted as copies too.

---

### User Story 2 - A link that cannot be reproduced keeps the archive (Priority: P1)

A symbolic link, or a hard link to a file that was not extracted in this operation (not in the archive,
outside the mask or selection, or skipped), cannot be reproduced. The user is told (a box naming the
member and the name it links to), everything else is extracted, and the operation counts as failed, so
"Delete archive after unpacking" keeps the archive.

**Why this priority**: the archive is the only remaining copy of what was left out.

**Independent Test**: probe rows UNP-SYM-DEL, UNP-HARD-MISSING-DEL.

**Acceptance Scenarios**:

1. **Given** a tar with `a.txt` and a symbolic link `s.txt -> a.txt`, **When** it is unpacked whole with
   "Delete archive after unpacking", **Then** `a.txt` is extracted, a box names `s.txt`, the archive is kept.
2. **Given** a hard link `b.txt -> missing.txt` (no such member) and `ok.txt`, **When** unpacked with
   Delete, **Then** `ok.txt` is extracted, a box names `b.txt`, the archive is kept.

---

### User Story 3 - A link never damages the file it names (Priority: P2)

On Windows two archive names that differ only in case are one file. A hard link `A.TXT -> a.txt` must
not truncate or rewrite `a.txt`.

**Independent Test**: probe row UNP-HARD-TWIN-DEL.

**Acceptance Scenarios**:

1. **Given** `a.txt` and a hard link `A.TXT -> a.txt`, **When** unpacked with Delete, **Then** the one
   file holds `a.txt`'s content, nothing is asked, and the archive is deleted (both names are there).

### Edge Cases

- Several link members cannot be reproduced: one box per operation (the first one is named), the
  operation fails once.
- The target of a hard link was skipped by the user at an overwrite question: it was not extracted in
  this operation, so the link is reported and the operation fails (safe side).
- The destination of a hard link already exists: the usual overwrite question of the plug-in applies; a
  Skip there is the user's choice and does not fail the operation (as for any member).
- The destination is the target itself (names differing only in case): nothing is written, the link
  counts as extracted.
- A hard link member that names a folder: reported (only files are reproduced).
- A link member with a name feature 306/308 refuses: reported by that rule as today.
- Character / block devices and FIFOs: unchanged (no content; outside the item).
- A `.deb`: each part is a tar and follows the same rules.
- Unpacking a single member from the panel (F3 / one file): link members are not listed, so they cannot
  be asked for; if asked for anyway, the operation reports it and fails instead of succeeding empty.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: An extraction (whole Unpack, Copy of a selection) MUST extract a hard-link member it was
  asked for as a copy of the file it names, when that file was written by this operation.
- **FR-002**: The name a link member refers to MUST be read from the PAX `linkpath` record, a GNU long
  link name, or the tar header, in that order of precedence (as for member names), and compared with
  member names after the same normalization (`./`, `..`, slashes).
- **FR-003**: A link member asked for that is not reproduced - a symbolic link, a hard link to a file not
  written by this operation or to a folder - MUST be reported with its name and the name it links to,
  and MUST make the operation fail after the rest is extracted, so the core keeps the archive.
- **FR-004**: The copy MUST go through the plug-in's usual file creation (overwrite question, Skip,
  Cancel), carry the member's time and attributes, and never open the named file for writing; when the
  destination is the named file itself, nothing is written.
- **FR-005**: Link members the operation was not asked for MUST stay without effect; the panel listing,
  files, folders, devices and the behaviour of features 306 / 308 MUST stay unchanged.
- **FR-006**: No new UI text; the report uses system error texts.

### Key Entities

- **Link member**: a tar member of type hard link ('1') or symbolic link ('2'); its name and the name it
  links to.
- **Written member**: a file member (or reproduced hard link) this operation wrote, by its archive name.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe passes every row (UNP-HARD-DEL, UNP-HARD-PAX-DEL, UNP-HARD-GNU-DEL,
  UNP-HARD-MISSING-DEL, UNP-SYM-DEL, UNP-HARD-TWIN-DEL, COPY-HARD); before: 6 FAIL.
- **SC-002**: No unpack that left a link member out deletes the archive (rows UNP-SYM-DEL,
  UNP-HARD-MISSING-DEL).
- **SC-003**: The 308 probe stays 12 / 0 and the 306 probe 28 / 0.
- **SC-004**: saltests pass with checks for the link-name rules (normalization equal to member names,
  PAX `linkpath` precedence, the decision copy / report).

## Assumptions

- Assumption (autonomous run): cpio archives (also read by the tar plug-in) keep their behaviour; the
  item names tar link members.
- Assumption (autonomous run): a hard link whose target was overwritten later in the same operation by
  another member of the same name copies what is on disk then (the same as a real hard link would show).
- Assumption (autonomous run): the copy of a large target has no progress of its own; the operation's
  progress continues after it.
