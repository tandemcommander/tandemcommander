# Feature Specification: Unpack reports a file whose only name normalizes to empty

**Feature Branch**: `395-cpio-solo-empty-name`
**Created**: 2026-11-02
**Status**: Draft
**Input**: User description: "Backlog item unpack-silently-drops-a-cpio-file-whose-only-name-normalizes - Unpack silently drops a cpio file whose only name normalizes to empty"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A whole Unpack never deletes an archive whose file data stayed inside (Priority: P1)

A user unpacks a whole cpio archive (newc, crc, odc, binary, also the payload of an rpm) or a tar
archive with Alt+F9, mask "*.*", and "Delete archive after unpacking" checked. The archive holds a
regular file whose data is stored under a name that normalizes to nothing (`.`, `./`, an empty
name) and the data reaches no other name: a single-name file, or a hard-linked file (newc / crc)
whose other names are missing from the archive. Today the plug-in extracts the rest, shows
nothing, reports success, and the archive - the only copy of that data - is deleted. Now the
member is reported with the system's "invalid name" text and its raw name, the rest is still
extracted, and the operation fails, so the archive is kept.

**Why this priority**: it is the item's whole point: silent data loss through a success report.

**Independent Test**: the probe `cpiosolo_probe.ps1` - one row per format and layout, a whole Unpack
with "Delete archive after unpacking"; the row passes when `ok.txt` is extracted, a "(123)" box
names the member, and the archive still exists.

**Acceptance Scenarios**:

1. **Given** a newc cpio with a regular member `.` (nlink 1, data `AAA`) and `ok.txt`, **When** the
   user unpacks it whole with "Delete archive after unpacking", **Then** `ok.txt` is extracted, a
   box with the "(123)" text and the name `"."` is shown, and the archive is kept.
2. **Given** the same with the name `./` or an empty name, or in the crc, odc or rpm form, **When**
   unpacked the same way, **Then** the same result.
3. **Given** a newc / crc cpio whose `.` member carries the data of a hard-linked file (nlink 2) and
   no other name of that file is in the archive, **When** unpacked the same way, **Then** the same
   result.
4. **Given** a ustar archive with a regular member `.` holding data and `ok.txt`, **When** unpacked
   the same way, **Then** the same result.

---

### User Story 2 - Harmless empty-named members stay silent (Priority: P2)

Archives written by common tools contain a `.` folder member (GNU cpio's `find . | cpio -o`, GNU
tar's `./`), and crafted archives may contain an empty-named member without data. These must keep
extracting silently with success - the archive is deleted when the user asked for it.

**Why this priority**: the fix must not turn every `find . | cpio -o` archive into a failure.

**Independent Test**: the control rows of the probe.

**Acceptance Scenarios**:

1. **Given** a cpio with the folder member `.` and `ok.txt` (or a tar with `./`), **When** unpacked
   whole with "Delete archive after unpacking", **Then** `ok.txt` is extracted, nothing is shown,
   the archive is deleted.
2. **Given** a regular `.` member of size 0 (single name or orphan group), **When** unpacked the
   same way, **Then** the same.
3. **Given** feature 394's layout (a waiting `a.txt` and the `.` carrier of its data), **When**
   unpacked the same way, **Then** `a.txt` holds `AAA`, nothing is shown, the archive is deleted.
4. **Given** a mask that does not match the raw name (`*.txt`), **When** unpacked, **Then** the
   member is not asked: nothing is shown, the operation succeeds.
5. **Given** the archive opened in the panel, **When** everything listed is copied out, **Then** the
   member (never listed) is not asked: only `ok.txt` is copied, no error box.

### Edge Cases

- The data-first layout of feature 394 (the `.` carrier first, then an asked `a.txt`): it stays
  reported by 394's "(2)" box at `a.txt`; no second box for the same loss.
- A data-first group whose later name is not asked (the mask excludes it) while the raw `.` is
  asked: the data reaches no extracted name - reported at the end of the archive.
- A group whose data was already written by an earlier member (data stored again with `.`): the
  data reached a name - silent.
- Several such members in one operation: the box is shown once per operation; the operation fails.
- A crc member with a wrong checksum under such a name: reported as an empty-name member (its
  data is not written, so the checksum is never computed) - the archive is kept either way.
- A cpio symlink, device or FIFO named `.`: not a regular file - silent as before.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A whole Unpack (and every extraction through the same routine) MUST report a member
  that is a regular file, holds data (size above 0), has a name that normalizes to nothing, is
  matched by the operation's names (the mask) under its raw name, and whose data reaches no name
  the operation extracts.
- **FR-002**: The report MUST use an existing system text - "(123)" (the file name syntax is
  incorrect) - followed by the member's raw name in quotes, once per operation; no new UI string.
- **FR-003**: Such a report MUST make the operation fail after the rest of the archive is
  extracted, so the core neither reports success nor deletes the archive.
- **FR-004**: For a newc / crc member of a hard-link group, "reaches no extracted name" MUST be
  decided by the group: data given to a waiting name or already written - silent; data passed with
  a later asked name of the group reported by feature 394's rule - no second report; otherwise
  reported at the end of the archive.
- **FR-005**: A folder member, a member of size 0, a non-regular member and a member the
  operation's names do not match MUST stay silent with the behaviour they have today.
- **FR-006**: The same rule MUST apply to a tar member (measured the same: silent drop, archive
  deleted).
- **FR-007**: Listing, the panel's Copy of selected items, F3 and every other behaviour of feature
  394 MUST stay unchanged.

### Key Entities

- **Empty-named data member**: an archive member that is a regular file with data whose name
  normalizes to nothing; attributes: raw name, format, hard-link group (newc / crc).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 9 of 9 data-loss rows of the probe (newc `.` / `./` / empty, crc, odc, rpm, newc and
  crc orphan group, tar) keep the archive and show the report; before the fix 0 of 9 did.
- **SC-002**: 7 of 7 control rows (size 0 single / orphan, cpio folder, tar folder, 394's waiting
  name, mask `*.txt`, Copy of the listing) stay silent with success, as before.
- **SC-003**: The probes of features 306, 308, 309, 310, 321, 393 and 394 give the results recorded
  by feature 394.

## Assumptions

- Assumption (autonomous run): the tar member gets the same rule - the item's Notes put it in scope
  when measured the same, and it was (probe row `UNP-TAR-SOLO-DOT-DEL`, before: archive deleted).
- Assumption (autonomous run): "asked" means the operation's names match the member's raw name (the
  rule every other member follows); only a whole Unpack can match it - the member is never listed,
  so a selection, Copy or F3 cannot ask for it.
- Assumption (autonomous run): the text is the system's `ERROR_INVALID_NAME` "(123)", one of the two
  the item proposes; "(206)" says "too long", which is wrong for an empty name.
- Assumption (autonomous run): the raw name is shown in quotes (`"."`, `"./"`, `""`) so that an
  empty name is visible in the box.
- Crafted archives only; no common writer stores a file's data under an empty name.
