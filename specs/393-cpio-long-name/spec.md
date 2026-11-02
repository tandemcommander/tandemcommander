# Feature Specification: A cpio or rpm member whose name the panel cannot hold is refused alone

**Feature Branch**: `393-cpio-long-name`  
**Created**: 2026-11-02  
**Status**: Draft  
**Input**: Backlog item `a-cpio-or-rpm-archive-with-a-member-name-the-panel-cannot` - "A cpio or rpm archive with a member name the panel cannot hold fails as a whole". From backlog item a-cpio-or-rpm-archive-with-a-member-name-the-panel-cannot.

## Background (measured at af18dc21)

Debug x64 build of `main` (up to date); hidden-desktop probe
`specs/321-tar-long-component/probe/tar321_probe.ps1 -Only CPIO-TOOLONG` (a newc cpio with a member
named by 300 CJK letters + `.txt` - 904 bytes - and a member `ok.txt`): the program no longer
crashes (feature 321's core bound), but opening shows "TAR Plugin Error - Internal error: file data
structure corrupted." and the archive does not open; `ok.txt` is out of reach.

Since features 306 / 308 / 321 a PAX path or a GNU long name that the panel listing cannot hold is
refused alone: while the listing is built it is left out and the system's "(206) file name too
long" text with the whole path is shown once; an extraction refuses only a name no file system
takes (a component over 255 UTF-16 units) and fails when asked for such a member. Names read from a
cpio header (the cpio formats newc, crc, odc and binary, and the payload of an rpm, which is a cpio
read by the same reader) never get that check, so a name the listing refuses makes the listing fail
as a whole.

## Clarifications

### Session 2026-11-02

- Q: Which rule applies to a cpio member name? → A: exactly the rule a PAX path / GNU long name has since features 306 / 308 / 321: while the panel listing is built, a name the listing cannot hold (a component over 255 UTF-16 units, a folder part deeper than the listing holds, a folder name inside a folder over the listing's bound) is not listed and the "(206)" text with the whole path is shown once; in an extraction only a component over 255 UTF-16 units is refused, and an extraction asked for such a member reports it and fails (autonomous run: item - *Expected*, *Notes*)
- Q: Which cpio formats? → A: every cpio format the plug-in reads (newc, crc, odc, binary, byte-swapped binary) and therefore the rpm payload - they share one name reader (autonomous run: conservative - the item names "cpio / rpm" without a format; one rule for all names the reader produces)
- Q: Is a top-level folder name bounded by bytes while listing? → A: no - as for PAX / GNU names since feature 321 (0.1.10 behaviour); its contents' folder part is bounded (autonomous run: rule - feature 321)
- Q: Is the extraction behaviour changed for members the listing refuses only by depth? → A: no - an extraction takes every member a file system takes (feature 308); a deep cpio member is extracted by a whole-archive unpack (autonomous run: item - *Notes*, "keep the refusal out of extraction passes")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A cpio with an over-long member name opens (Priority: P1)

A user opens a cpio archive (or an rpm package) whose member has a name longer than any file system
takes. The archive opens, the user is told that member cannot be listed (the system's "file name
too long" text with the path), and every other member lists and extracts normally.

**Why this priority**: today the whole archive refuses to open; nothing in it can be reached.

**Independent Test**: probe row with a newc cpio holding CJK(300).txt and `ok.txt`; the same in an rpm.

**Acceptance Scenarios**:

1. **Given** a newc cpio with a member CJK(300).txt and a member `ok.txt`, **When** the user opens
   it in a panel, **Then** a message with "(206)" and the path is shown, the archive opens, and Copy
   of everything extracts `ok.txt` only.
2. **Given** the same members in an rpm package, **When** opened, **Then** the same.
3. **Given** the same members in an odc cpio, **When** opened, **Then** the same.

---

### User Story 2 - A cpio with a member deeper than the listing holds opens and unpacks whole (Priority: P1)

A user opens a cpio whose member lies in folders deeper than the panel listing holds (the folder
part over 255 bytes). The archive opens with the "(206)" message for that member; the other members
are listed; a whole-archive Unpack (Alt+F9) extracts every member including the deep one, so
"Delete archive after unpacking" deletes the archive only when everything was extracted.

**Why this priority**: the item's *Expected* names a deep-path row; such archives (deep source
trees) are more common than over-long names.

**Independent Test**: a cpio with `a.txt`, a member under ten 29-letter folders and `ok.txt`.

**Acceptance Scenarios**:

1. **Given** that cpio, **When** opened, **Then** a "(206)" message is shown and the archive opens.
2. **Given** that cpio, **When** unpacked whole with Alt+F9 (and "Delete archive after
   unpacking"), **Then** all members are extracted, nothing is asked, and the archive is deleted.
3. **Given** a cpio with CJK(300).txt and `ok.txt`, **When** unpacked whole with "Delete archive
   after unpacking", **Then** `ok.txt` is extracted, a "(206)" box names the member, and the archive
   is kept.

---

### User Story 3 - Names that fit keep working (Priority: P2)

Cpio names that the listing holds (a 255-UTF-16-unit name at the root, a long path whose folder part
fits, a 778-byte name, an empty top-level folder of 100 CJK letters) list and extract as before.

**Independent Test**: regression rows of the earlier probes (321's CPIO-778, 310's cpio rows) and a
boundary row.

**Acceptance Scenarios**:

1. **Given** a newc cpio with CJK(251).txt (255 UTF-16 units), **When** opened and copied,
   **Then** the file is listed and extracted with its content, no message.
2. **Given** feature 310's cpio / rpm probe, **When** run, **Then** all its rows still pass.

### Edge Cases

- Several refused members: only the first is named (once per listing / operation), as for tar.
- The refused member is a folder: its entry is not listed; members inside it are listed only when
  their own names fit (as for tar).
- A refused member that is a hard link group's data carrier in a newc cpio: extraction behaves as
  for any member the operation was asked for but cannot write (feature 310's report and failure).
- The cpio trailer `TRAILER!!!` is never refused.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: While the panel listing of a cpio or rpm archive is built, a member whose name the
  listing cannot hold MUST be left out, and the system's "(206)" text with the member's whole path
  MUST be shown once per listing; every other member MUST be listed.
- **FR-002**: An extraction (whole-archive Unpack, Copy from the opened archive, view of one file)
  MUST take every cpio member a file system takes (also members deeper than the listing holds).
- **FR-003**: An extraction asked for a cpio member no file system takes (a component over 255
  UTF-16 units) MUST report it ("(206)" and the path) and fail after the rest is extracted, so
  "Delete archive after unpacking" keeps the archive.
- **FR-004**: The rule MUST be the same as for PAX paths and GNU long names (one shared decision),
  never a cut or a replaced name.
- **FR-005**: Tar members (ustar, PAX, GNU) and cpio names that fit MUST behave as before.

### Key Entities

- **Cpio member name**: the UTF-8, normalized path of a cpio header (up to 10000 bytes on disk).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A cpio, an odc cpio and an rpm each holding CJK(300).txt and `ok.txt` open; Copy of
  everything extracts `ok.txt` (before: the archive did not open).
- **SC-002**: A cpio with a deep member opens with one "(206)" message and its whole Unpack
  extracts all members and deletes the archive when asked (before: the archive did not open).
- **SC-003**: A whole Unpack of a cpio with CJK(300).txt keeps the archive and names the member.
- **SC-004**: The probes of features 306, 308, 309, 310 and 321 keep their results.

## Assumptions

- Assumption (autonomous run): the shared decision `SalPaxNameUsableU8` (`salpaxheader.h`, saltests)
  already encodes the rule; no new pure rule is needed - the feature applies it to cpio names.
- Assumption (autonomous run): no UI string changes - the "(206)" text is the system's error text
  already used by features 306 / 308 / 321.
- Out of scope: cpio links (feature 310), the listing's size for hard-linked names, tar formats.
