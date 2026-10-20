# Feature Specification: Change Attributes on a junction changes the junction, not its target folder

**Feature Branch**: `253-attrs-link-own-entry`
**Created**: 2026-10-20
**Status**: Draft
**Input**: Backlog item `change-attrs-on-link-reaches-target` - "Change Attributes on a junction
compresses / re-times the target folder". From backlog item change-attrs-on-link-reaches-target.

## Background (measured at d5f67ace)

Feature 213 stopped Change Attributes from walking into a junction (the target's files no longer
change). The junction's own entry is still changed - and three parts of that change land on the
TARGET folder instead of the junction:

1. **Compression** (the Compressed box, the Compress / Uncompress commands): the target folder is
   compressed or uncompressed; the junction keeps its state. Measured by the probe
   `attrs_link253_probe.ps1`: rows COMP, UNCOMP and SUBC (a folder holding a junction, with "Include
   subdirectories") FAIL.
2. **Times** (Modified / Created / Accessed): the target folder gets the new times; the junction
   keeps its own. Row TIME FAIL.
3. **Encryption** (the Encrypted box, the Encrypt / Decrypt commands): by reading, the link's path is
   handed to the system's encrypt / decrypt service, which offers no way to stay on the link - the
   target folder would be encrypted or decrypted. Not driven: the machine has no file-encryption
   certificate and encrypting would create one in the user's store.

The other attributes (Archive, Read-only, Hidden, System) already change the junction only (213).
A measurement outside the program showed that compression and times can be applied to the junction
itself; encryption cannot.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Compressing a junction compresses the junction only (Priority: P1)

A user focuses (or selects) a junction or a directory symbolic link and sets or clears Compressed in
Change Attributes (or uses Compress / Uncompress). The junction's own entry takes the new state; the
folder it points to keeps its compression.

**Why this priority**: today the user changes a folder outside the selection without knowing it.

**Independent Test**: probe rows COMP, UNCOMP, SUBC: the junction compressed / uncompressed, the
target folder and its file unchanged.

**Acceptance Scenarios**:

1. **Given** a junction to an uncompressed folder, **When** Compressed is set on the junction,
   **Then** the junction is compressed and the target folder and its files are not.
2. **Given** a compressed junction to a compressed folder, **When** Compressed is cleared on the
   junction, **Then** the junction is uncompressed and the target folder stays compressed.
3. **Given** a folder holding a file and a junction, **When** Compressed is set with "Include
   subdirectories", **Then** the folder, its file and the junction are compressed, the junction's
   target folder and its files are not.

---

### User Story 2 - Setting times on a junction sets the junction's times only (Priority: P1)

A user sets Modified / Created / Accessed on a junction. The junction's own times change; the target
folder keeps its times.

**Why this priority**: the target folder's times are user data (sorting, backups, sync tools).

**Independent Test**: probe row TIME: the junction modified on the set date, the target folder keeps
its earlier date.

**Acceptance Scenarios**:

1. **Given** a junction to a folder modified in 2010, **When** the Modified date 2001-02-03 is set
   on the junction, **Then** the junction shows 2001 and the target folder still shows 2010.

---

### User Story 3 - Encrypting or decrypting a junction is refused (Priority: P2)

A user sets or clears Encrypted on a junction (or uses Encrypt / Decrypt). Because a link cannot be
encrypted on its own, the program refuses this entry with its existing encryption error (Retry /
Skip / Skip all / Cancel); the target folder's encryption never changes. Entries that are not links
are encrypted as before, also in the same operation.

**Why this priority**: the same defect, but rarer (needs file encryption) and not drivable here.

**Independent Test**: by reading and unit checks of the decision; a person check on a machine with
a file-encryption certificate.

**Acceptance Scenarios**:

1. **Given** an unencrypted junction, **When** Encrypted is set on it, **Then** the encryption error
   is shown for the junction and the target folder stays unencrypted.
2. **Given** a junction whose encryption state already matches the request, **When** the operation
   runs, **Then** no error is shown (nothing to change).
3. **Given** a selection of a plain folder and a junction, **When** Encrypted is set and the
   junction's error is skipped, **Then** the plain folder is still encrypted.

---

### User Story 4 - Ordinary folders and files behave as before (Priority: P1)

**Independent Test**: probe row PLAIN (a plain folder compressed and re-timed) passes before and after.

**Acceptance Scenarios**:

1. **Given** a plain folder or file, **When** any Change Attributes is applied, **Then** the result
   is exactly as before.

### Edge Cases

- A link whose kind cannot be determined: treated as a link (fail closed, as Delete and 213 do) -
  the change stays on the entry itself, encryption refused.
- A cloud placeholder folder (a reparse point that is not a link): behaves as before.
- A file symbolic link: not named by the item, behaves as before (recorded for the backlog).
- Copy / Move with compression or encryption of the created target folders: unchanged (the program
  created those folders; they are not links).
- A read-only junction: the read-only bit is lifted and restored on the junction itself, as for any
  entry.
- The file system does not support compression for the junction: the existing "not supported"
  handling applies.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Change Attributes on an entry that is a junction / directory symbolic link (the
  program's existing fail-closed link rule) MUST set or clear compression on the link's own entry,
  never on its target folder.
- **FR-002**: Setting Modified / Created / Accessed times on such an entry MUST change the link's own
  times, never the target folder's.
- **FR-003**: Setting or clearing encryption on such an entry, when its state differs from the
  request, MUST be refused for that entry with the existing encryption error; the target folder's
  encryption MUST NOT change; other entries of the operation MUST keep being encrypted / decrypted.
- **FR-004**: Archive / Read-only / Hidden / System on a link, and every attribute on entries that
  are not such links (plain folders, files, cloud placeholders, file symbolic links), MUST behave
  exactly as before.
- **FR-005**: Copy and Move MUST keep their compression / encryption behaviour of created folders.
- **FR-006**: No new UI text, no plug-in interface change, no change of what is stored.
- **FR-007**: The decision "what does Change Attributes do with this entry's compression, times and
  encryption" MUST be a pure, unit-tested rule.

### Key Entities

- **Directory link**: a folder entry that is a reparse point the program takes for a link (junction,
  directory symbolic link, volume mount point, other name surrogate, or a reparse tag that cannot be
  read).

## Success Criteria *(mandatory)*

- **SC-001**: In the probe, rows COMP, UNCOMP, TIME and SUBC fail before and pass after; the control
  row PLAIN passes before and after.
- **SC-002**: The unit checks of the decision pass, including the encryption refusal and the "state
  already matches" case.
- **SC-003**: Feature 213's probe stays 8 / 0 (Change Attributes / Case / Convert on links).
- **SC-004**: No target folder outside the selection changes its compression, times or encryption
  through a link in any probe row.

## Assumptions

- Assumption (autonomous run): a link's own compression is set (the item: "changes only the link"),
  measured to work on NTFS; refusing compression of a link is not needed.
- Assumption (autonomous run): encryption of a link is refused with the existing error dialog
  (`IDS_ERRORENCRYPTING` and the system's "not supported" text) - the item's "refuses what a link
  cannot take"; no new UI string.
- Assumption (autonomous run): file symbolic links keep their behaviour (not named by the item); a
  backlog item records them.
- Assumption (autonomous run): encryption is not driven on this machine (no EFS certificate may be
  created); a person step confirms it.
