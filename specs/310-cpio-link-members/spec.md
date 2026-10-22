# Feature Specification: Links in a cpio or rpm are extracted or reported, never dropped silently

**Feature Branch**: `310-cpio-link-members`
**Created**: 2026-10-22
**Status**: Draft
**Input**: Backlog item `cpio-unpack-drops-links-and-may-delete-archive` - "Unpacking a cpio or rpm leaves links out silently and may delete the archive". From backlog item cpio-unpack-drops-links-and-may-delete-archive.

## Measured before the feature (47eb6b83, `main`, Debug x64)

Probe `probe/cpio310_probe.ps1` (fixtures `probe/mkcpio310.py`, Python 3.14; newc `070701`, crc
`070702` and odc `070707` cpio laid out as GNU cpio and rpm write them; Windows' libarchive `tar.exe`
lists them as intended), run on the hidden desktop -> `probe/result_before.txt`: PASS 13 / FAIL 7.

- CPIO-HARD-DEL (newc; `c.txt`, `sub`, then one file with three names: `a.txt` and `sub/b.txt` stored
  with size 0, `sub/d.txt` with the data `AAA`; Alt+F9 with "Delete archive after unpacking"): 4 files,
  `a.txt` and `sub/b.txt` **empty**, no message, `t.cpio` **deleted**.
- CPIO-CRC-HARD-DEL: the same in the crc format - the same result.
- CPIO-HARD-FIRST-DEL (the data with the first name, the second name size 0): `b.txt` empty, deleted.
- CPIO-HARD-DEV-DEL (one inode number on two devices): `a.txt` empty.
- CPIO-SYM-DEL (`a.txt`, symbolic links `s.txt`, `t.txt` -> `a.txt`): no message, `t.cpio` **deleted**.
- COPY-CPIO-ALL (Select All + Copy from the opened cpio): `a.txt`, `sub/b.txt` empty.
- COPY-CPIO-ONE (Copy of the focused `a.txt` only; its data is stored with `sub/b.txt`): `a.txt` empty.
- Passing controls: CPIO-HARD-EMPTY-DEL (an empty file with two names), CPIO-ODC-HARD-DEL (odc repeats
  the data with every name), CPIO-FIFO-DEL (a named pipe is skipped silently, as tar does with devices
  and FIFOs).

Reachability: Alt+F9 Unpack and F5 Copy from the panel-opened archive, default configuration (cpio and
rpm are TAR plug-in panel archivers). An rpm reaches the same reader: its payload is a cpio archive read
through a decompressing stream.

## Clarifications

### Session 2026-10-22

- Q: Is a hard-linked name extracted as a copy of the file or as an NTFS hard link? → A: A copy, as feature 309 decided for tar - it works on every target file system and never ties two of the user's files together (autonomous run: rule - feature 309)
- Q: Are symbolic links created? → A: No - one left out is reported and fails the operation, as for tar since feature 309 (autonomous run: item)
- Q: Which members count - every one in the archive, or only those the operation was asked to extract? → A: Only those asked for (mask / selection), the rule of features 308 / 309 (autonomous run: item)
- Q: How is a left-out link reported, given that no new UI text may be added in this run? → A: The feature 309 box: a system error text, the member's name and the name it links to, once per operation (autonomous run: rule - new strings need the maintainer's .slt refresh)
- Q: What happens to devices, named pipes and sockets in a cpio? → A: Unchanged - skipped silently, as tar does with the same member types; they carry no file content (autonomous run: conservative)
- Q: Does the panel listing change (size of the names stored with size 0, symbolic links listed)? → A: No - the listing is unchanged; the item asks about extraction (autonomous run: conservative)
- Q: What happens to the names waiting for a file's data when the data is not written (the user answered Skip, or writing it failed)? → A: They are reported (system "file not found" text, the first waiting name and the name holding the data) and the operation fails after the rest is extracted - feature 309's rule for a hard link whose target was not written (autonomous run: rule - feature 309)
- Q: Does viewing or opening one name stored with size 0 (a single-file extraction) also get the content? → A: Yes - the single-file extraction reads on to the member holding the file's data; it is the same defect seen from F3 / Enter (autonomous run: item - "hard-linked names arrive with their content")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Every name of a hard-linked file arrives with its content (Priority: P1)

A user unpacks a cpio archive or an rpm package in the "new" (newc) or crc format in which one file has
several names. The archive stores the file's data with one of the names only; the other names are
stored with size 0. Every name arrives with the file's content.

**Why this priority**: today the other names arrive as empty files without a word; with "Delete archive
after unpacking" the archive is then deleted and the content of those names is lost.

**Independent Test**: probe rows CPIO-HARD-DEL, CPIO-CRC-HARD-DEL, CPIO-HARD-FIRST-DEL,
CPIO-HARD-DEV-DEL, COPY-CPIO-ALL, COPY-CPIO-ONE.

**Acceptance Scenarios**:

1. **Given** a newc cpio in which `a.txt`, `sub/b.txt` (size 0) and `sub/d.txt` (data) are one file,
   **When** the user unpacks the whole archive with "Delete archive after unpacking", **Then** all three
   names hold the content, nothing is asked, and the archive is deleted.
2. **Given** the same layout in the crc format, **Then** the same result.
3. **Given** the data stored with the first name and size 0 with the later one, **Then** both names
   hold the content.
4. **Given** two members with the same inode number on different devices, **Then** each name gets the
   content of its own file.
5. **Given** the opened archive, **When** the user copies only the name stored with size 0, **Then**
   it arrives with the content stored under another name of the file.

---

### User Story 2 - A symbolic link that is left out keeps the archive (Priority: P1)

A symbolic link in a cpio or rpm is not reproduced on Windows. The user is told (one box naming the
member and the name it links to), everything else is extracted, and the operation counts as failed, so
"Delete archive after unpacking" keeps the archive.

**Why this priority**: today the link disappears silently and the archive is deleted.

**Independent Test**: probe row CPIO-SYM-DEL.

**Acceptance Scenarios**:

1. **Given** a newc cpio with `a.txt` and symbolic links `s.txt`, `t.txt` -> `a.txt`, **When** the
   user unpacks the whole archive with "Delete archive after unpacking", **Then** `a.txt` is extracted,
   exactly one box names `s.txt -> a.txt`, and the archive is kept.

---

### User Story 3 - What worked keeps working (Priority: P2)

Archives without links, odc / binary cpio (which repeat the data with every name), an empty file with
several names, and devices or named pipes behave as before.

**Independent Test**: probe rows CPIO-HARD-EMPTY-DEL, CPIO-ODC-HARD-DEL, CPIO-FIFO-DEL; the probes of
features 306, 308 and 309 (tar) unchanged.

**Acceptance Scenarios**:

1. **Given** an empty file with two names (both size 0), **Then** both names arrive empty, nothing is
   asked, and the archive is deleted as before.
2. **Given** an odc cpio with the data repeated for both names, **Then** both arrive with it.
3. **Given** a named pipe and a file, **Then** the file arrives, nothing is asked, the archive is deleted.

### Edge Cases

- The name holding the data is not asked for (outside the mask / selection) but a name stored with
  size 0 is: the asked name gets the data; the other name is not written.
- The data name comes before the names stored with size 0: those names are copied from it.
- No member of the file carries data (a genuinely empty file): every asked name is written empty at
  the end of the operation.
- The user answers Skip for a waiting name at the overwrite question: that name is not written (the
  user's choice, as for any member); the other names still get the content.
- The user answers Skip for the name that receives the data (or writing it fails): the names waiting
  for it are reported once and the operation fails (feature 309's rule), so the archive is kept.
- Two names that are one file on Windows (differing only in case): the existing file is never
  truncated (feature 309's identity check).
- A symbolic link whose target text is long or not valid text: the box still names the member; the
  target is shown as read (or empty when it cannot be read whole).
- The archive ends (or is cancelled) before the data of a file arrives: the names waiting for it are
  not written as empty files when the operation fails; when the archive simply ends, they are written
  empty (no member carried data).
- An rpm package: the same rules (its payload is a newc cpio).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: In a newc or crc cpio, the members that are names of one file (a regular file with more
  than one link, the same inode number and the same device) MUST all be extracted with the content
  stored with any one of them, when the operation was asked to extract them.
- **FR-002**: A name stored with size 0 MUST NOT be written before the operation knows whether the
  file's data is stored with another name; if no name of the file carries data by the end of the
  archive, the asked names MUST be written as empty files.
- **FR-003**: When the name holding the data was not asked for but another name of the file was, the
  asked name MUST receive the data.
- **FR-004**: The extra names MUST be written as copies through the same safe-create path as every
  extracted file (overwrite question, Skip, Cancel) and MUST never truncate the file they are copied
  from (identity check of feature 309).
- **FR-005**: A cpio symbolic link the operation was asked for MUST be reported once per operation
  (system "not supported" text, the member's name and the name it links to) and MUST make the
  operation fail after the rest is extracted, so the core keeps the archive.
- **FR-005a**: When the data of a group is not written (Skip, an error), every asked name waiting
  for it or coming after it MUST be reported once per operation ("file not found" text, the name and
  the name holding the data) and MUST make the operation fail after the rest is extracted.
- **FR-006**: odc and binary cpio, devices, named pipes, sockets, tar archives, and the panel listing
  MUST behave as before.
- **FR-007**: Opening a single name stored with size 0 (view / open of one file) MUST give the file's
  content when the archive stores it with a later name (the layout of GNU cpio, rpm, libarchive);
  when the data is stored with an earlier name (already passed - a single-file extraction reads the
  archive once), the name MUST be reported and the operation MUST fail - never an empty file.
- **FR-008**: Names stay UTF-8 / whole (CLAUDE.md standing rules); no message text is cut.

### Key Entities

- **Hard-link group**: the members of a newc / crc cpio with the same device (major, minor) and inode
  number and a link count above one; one of them (or none, for an empty file) carries the data.
- **Waiting name**: an asked member of a group stored with size 0, waiting for the group's data.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe passes every row (before: 13 PASS / 7 FAIL): all hard-linked names hold the
  content, the symbolic-link row keeps the archive with exactly one box.
- **SC-002**: No archive whose link was left out is deleted by "Delete archive after unpacking".
- **SC-003**: The probes of features 306, 308 and 309 give the same results as before; saltests 0
  failed.

## Assumptions

- Assumption (autonomous run): the device of a newc member is its `c_devmajor` / `c_devminor` pair and
  its identity the `c_ino` field, as GNU cpio and libarchive read them; members with a link count of 1
  are never grouped.
- Assumption (autonomous run): a symbolic link's target is the member's data; a target longer than
  4096 bytes is not read (the box then shows an empty target) - Linux limits targets to 4095 bytes.
- Assumption (autonomous run): no new UI strings (the 309 box and its system texts are reused).
- Out of scope: creating symbolic links; listing link members or correcting the size shown for names
  stored with size 0; viewing a name whose data is stored with an earlier name (reported instead,
  FR-007); long cpio names (item `a-cpio-or-rpm-archive-with-a-member-name-the-panel-cannot`).
