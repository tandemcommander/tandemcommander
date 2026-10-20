# Feature Specification: Change Attributes on a file symbolic link changes the link, not its target file

**Feature Branch**: `272-attrs-file-link`
**Created**: 2026-10-21
**Status**: Draft
**Input**: Backlog item `change-attributes-on-a-file-symbolic-link-compresses-re` - "Change
Attributes on a file symbolic link compresses / re-times the target file". From backlog item change-attributes-on-a-file-symbolic-link-compresses-re.

## Background (measured at 8b08f1da)

Feature 253 made Change Attributes on a junction / directory symbolic link change the link's own
compression and times and refuse its encryption. A **file** symbolic link was left as it was: three
parts of its change still land on the TARGET file:

1. **Compression** (the Compressed box, the Compress / Uncompress commands): the target file is
   compressed or uncompressed; the link keeps its state. Probe `attrs_flink272_probe.ps1`: rows
   COMP, UNCOMP and SUBC (a folder holding a file link, with "Include subdirectories") FAIL.
2. **Times** (Modified / Created / Accessed): the target file gets the new times; the link keeps
   its own. Row TIME FAIL.
3. **Encryption** (the Encrypted box, the Encrypt / Decrypt commands): by reading, the link's path
   is handed to the system's encrypt / decrypt service, which follows the link - the target file
   would be encrypted or decrypted. Not driven: no file-encryption certificate may be created on
   the build machine.

Read-only / Hidden / System / Archive already change the link only (measured outside the program).
A measurement outside the program showed compression and times can be applied to the file link
itself. A file whose reparse point is not a link (a third-party tag, as cloud placeholders and
deduplicated files have) is today opened the ordinary way (row NONLINK: "Error Changing
Compression", nothing compressed) - this must stay.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Compressing a file link compresses the link only (Priority: P1)

A user focuses (or selects) a file symbolic link and sets or clears Compressed in Change
Attributes (or uses Compress / Uncompress). The link's own entry takes the new state; the file it
points to keeps its compression.

**Why this priority**: today the user changes a file outside the selection without knowing it.

**Independent Test**: probe rows COMP, UNCOMP, SUBC: the link compressed / uncompressed, the target
file unchanged.

**Acceptance Scenarios**:

1. **Given** a file link to an uncompressed file, **When** Compressed is set on the link, **Then**
   the link is compressed and the target file is not.
2. **Given** a compressed file link to a compressed file, **When** Compressed is cleared on the
   link, **Then** the link is uncompressed and the target file stays compressed.
3. **Given** a folder holding a file and a file link to a file outside it, **When** Compressed is
   set with "Include subdirectories", **Then** the folder, its file and the link are compressed,
   the link's target file is not.

---

### User Story 2 - Setting times on a file link sets the link's times only (Priority: P1)

**Why this priority**: the target file's times are user data (sorting, backups, sync tools).

**Independent Test**: probe row TIME.

**Acceptance Scenarios**:

1. **Given** a file link to a file modified in 2010, **When** the Modified date 2001-02-03 is set
   on the link, **Then** the link shows 2001 and the target file still shows 2010.

---

### User Story 3 - Encrypting or decrypting a file link is refused (Priority: P2)

A user sets or clears Encrypted on a file link (or uses Encrypt / Decrypt). A link cannot be
encrypted on its own, so the program refuses this entry with its existing encryption error (Retry /
Skip / Skip all / Cancel) - as 253 does for a directory link; the target file's encryption never
changes. Entries that are not links are encrypted as before, also in the same operation.

**Why this priority**: the same defect, rarer, not drivable on the build machine.

**Independent Test**: unit checks of the decision and code reading; a person check on a machine
with a file-encryption certificate.

**Acceptance Scenarios**:

1. **Given** an unencrypted file link, **When** Encrypted is set on it, **Then** the encryption
   error is shown for the link and the target file stays unencrypted.
2. **Given** a file link whose encryption state already matches the request, **When** the
   operation runs, **Then** no error is shown (nothing to change).

---

### User Story 4 - Ordinary files and non-link reparse files behave as before (Priority: P1)

**Independent Test**: probe rows PLAIN (a plain file compressed and re-timed) and NONLINK (a file
with a third-party reparse tag: the same "Error Changing Compression" as before, not compressed)
pass before and after; feature 253's probe stays 10 / 0.

**Acceptance Scenarios**:

1. **Given** a plain file, a plain folder or a directory link, **When** any Change Attributes is
   applied, **Then** the result is exactly as before (253's behaviour for directory links).
2. **Given** a file whose reparse point is readable and not a name surrogate (cloud placeholder,
   deduplicated file, third-party tag), **When** Change Attributes is applied, **Then** it is
   opened exactly as before.

### Edge Cases

- A file link whose kind cannot be determined (its reparse tag cannot be read): treated as a link
  (fail closed, the rule of Delete / 213 / 253) - changes stay on the entry itself, encryption
  refused.
- The refusal of a file link's encryption skips the whole entry when the user picks Skip / Skip
  all (see Clarifications); Encrypt / Decrypt over a tree shows one refusal per file link that
  would change.
- A dangling file link (target missing): compression and times apply to the link itself (they
  failed with "file not found" before).
- A read-only file link: the read-only bit is lifted and restored on the link itself, as for any
  entry.
- The file system does not support compression: the existing "not supported" handling applies.
- Copy / Move with compression or encryption of created target files: unchanged (the program
  created those files; they are not links).
- A hard link is not a reparse point: unchanged (it is the file itself).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Change Attributes on a file entry that is a link (listed with the reparse-point bit
  and taken for a link by the program's existing fail-closed link rule) MUST set or clear
  compression on the link's own entry, never on its target file.
- **FR-002**: Setting Modified / Created / Accessed times on such an entry MUST change the link's
  own times, never the target file's.
- **FR-003**: Setting or clearing encryption on such an entry, when its state differs from the
  request, MUST be refused for that entry with the existing encryption error; the target file's
  encryption MUST NOT change; other entries of the operation MUST keep being encrypted / decrypted.
- **FR-004**: Entries that are not links - plain files and folders, and reparse files whose tag is
  readable and not a name surrogate - MUST behave exactly as before; directory links keep 253's
  behaviour.
- **FR-005**: Copy and Move MUST keep their compression / encryption behaviour of created files and
  folders.
- **FR-006**: No new UI text, no plug-in interface change, no change of what is stored.
- **FR-007**: The decision (is the entry a link; the open flags for its compression and times; is
  its encryption refused) MUST be a pure, unit-tested rule.

### Key Entities

- **Link entry**: a file or folder entry listed with the reparse-point bit that the program takes
  for a link (symbolic link, junction, volume mount point, another name surrogate, or a reparse tag
  that cannot be read).

## Success Criteria *(mandatory)*

- **SC-001**: In the probe, rows COMP, UNCOMP, TIME and SUBC fail before and pass after; the
  control rows PLAIN and NONLINK pass before and after.
- **SC-002**: The unit checks of the decision pass, including the file-link encryption refusal,
  the "state already matches" case and a non-surrogate tag kept on the old way.
- **SC-003**: Feature 253's probe stays 10 / 0 (1 NOT DRIVEN) and 213's probe 8 / 0.
- **SC-004**: No target file outside the selection changes its compression, times or encryption
  through a link in any probe row.

## Clarifications

### Session 2026-10-21

- Q: When the encryption of a file link is refused, are the link's other requested changes
  (Hidden, times, ...) still applied? → A: no - as 253 decided for a directory link, the refusal is
  an error of that entry like any other: Skip / Skip all skips the whole entry, Retry repeats it,
  Cancel ends the operation; the other entries go on. A compression change made to the link itself
  just before the refusal stays (it touched only the link). (autonomous run: conservative)
- Q: Do the Encrypt / Decrypt commands over a tree refuse every file link met whose state differs?
  → A: yes, one error per such link; Skip all answers them all at once; nothing is encrypted
  through a link. (autonomous run: item - "refuses what a link cannot take")
- Q: Is a file entry decided to be a link when the operation is listed or when it runs? → A: an
  entry listed with the reparse-point bit is checked when it runs, by the existing fail-closed rule
  on its current state; an entry listed without the bit is not checked (no extra file-system query
  for ordinary files - the race of a file replaced by a link meanwhile is the same narrow one 253
  accepted). (autonomous run: conservative)

## Assumptions

- Assumption (autonomous run): a file link's own compression and times are set (the item: "changes
  only the link"), measured to work on NTFS.
- Assumption (autonomous run): encryption of a file link is refused exactly as 253 refuses a
  directory link's (`IDS_ERRORENCRYPTING`, the system's "not supported" text) - the item's "refuses
  what a link cannot take"; no new UI string.
- Assumption (autonomous run): the link rule for files is the existing fail-closed rule
  (`DeleteAsDirLink`, 197): a link when the destination is read, the tag cannot be read, or the tag
  is a name surrogate - the item's note excludes non-surrogate reparse files.
- Assumption (autonomous run): encryption is not driven on this machine (no EFS certificate may be
  created); a person step confirms it.
- Assumption (autonomous run): file links are created in the probe with the unprivileged flag
  (Developer Mode is on); a row whose link cannot be made is NOT DRIVEN.
