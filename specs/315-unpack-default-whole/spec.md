# Feature Specification: The Unpack dialog never offers a default target path or mask cut

**Feature Branch**: `315-unpack-default-whole`
**Created**: 2026-10-23
**Status**: Draft
**Input**: Backlog item unpack-dialog-offers-a-long-target-panel-path-cut-and (backlog/items/unpack-dialog-offers-a-long-target-panel-path-cut-and/desc.md) - implement exactly what it describes. From backlog item unpack-dialog-offers-a-long-target-panel-path-cut-and.

## Background

Unpack (Alt+F9) on an archive in a disk panel opens the Unpack dialog. Before the dialog opens, the
program prepares its defaults in 260-byte buffers:

- the target path combo box offers the other panel's path (first with "Use the other panel for
  unpacking", second otherwise) - copied with a byte copy that cuts a path longer than 259 bytes,
  possibly inside a UTF-8 character;
- with "Use the archive name as a subfolder", the archive's name is appended to each offered path;
  when the result would not fit, the name is dropped silently and the bare path is offered;
- a plug-in that opens the dialog for itself may pass an "Unpack files" mask; it is cut the same
  way;
- after OK, an empty target path means "next to the archive": the archive panel's path is copied
  into the buffer, cut the same way.

Feature 299 made the dialog refuse typed text that does not fit; a cut default fits, so it is
accepted and used.

Measured at 32718c27 (hidden-desktop probe `unpack315_probe.ps1`, the ZIP plug-in unpacking a.zip
holding a.k and a.kp; the right panel on a folder L), 6 rows FAIL, 3 controls PASS:

- other-ascii ("Use the other panel" on, L 297 bytes ASCII): the first entry is a 259-byte prefix
  of L; OK unpacked a.k / a.kp into a new folder named after the cut component, nothing asked.
- other-cjk (on, L 355 bytes CJK): the first entry is cut inside a CJK letter and shown through the
  code page as garbage; OK refused it as too long.
- alt-ascii / alt-cjk (off, the second entry): a 259-byte prefix of L; unpacked into the new cut
  folder.
- subdir (on, subfolder on, L 245 bytes, archive name of 20 letters, L + name = 266 bytes): the
  first entry is L without the subfolder; OK unpacked straight into L.
- src-long (the archive in a 297-byte folder, the empty entry, OK): the empty path became the
  archive folder's path cut to 259 bytes; unpacked into a new cut folder.
- Controls: L 200 bytes (on), L 250 bytes CJK (off), L 200 bytes with the subfolder: offered whole,
  unpacked there.
- The plug-in mask: no plug-in of the tree passes a mask (read only).

## Clarifications

### Session 2026-10-23

- Q: Leave a default that does not fit out of the dialog, or grow the dialog's buffers and let later steps refuse? → A: leave it out - the dialog offers what it offers when the other panel is not a disk (the empty entry, or the archive's name as a relative subfolder) (autonomous run: item - "leaving it out changes least")
- Q: With "Use the archive name as a subfolder", the other panel's path fits but path + archive name does not - offer the bare path (today) or leave the entry out? → A: leave the entry out - the bare path is a cut default (the subfolder cut away) and would unpack straight into the other panel's folder; the setting is kept by the empty / relative entry (autonomous run: item - Evidence names the silent drop; "a default that does not fit ... is never offered cut")
- Q: A plug-in's unpack mask that does not fit - which default replaces it? → A: the dialog's own default "*.*" (the default when a plug-in passes no mask), visible in the field before OK (autonomous run: item - "an empty / the other default", "the plug-in mask the same")
- Q: The empty target path falls back to the archive panel's path cut to 259 bytes - fix here? → A: yes - leaving a target out makes the empty entry the default, so the fallback must not cut either: a panel path that does not fit is refused with "The path specified is too long." and the dialog opens again (autonomous run: item - "the later steps refuse with 'The path specified is too long.' - never a cut path"; measured in the same function)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The other panel's long path is never offered cut (Priority: P1)

A user presses Alt+F9 on an archive while the other panel shows a folder whose path is longer than
259 bytes of UTF-8 (ASCII or CJK). The Unpack dialog does not offer a cut form of that path - not as
the first entry ("Use the other panel for unpacking" on) nor as the second (off). OK on any entry
never unpacks into a folder that is a cut prefix of the other panel's path.

**Why this priority**: today one Enter unpacks into another folder (a new folder named after a cut
component, or an existing prefix folder), nothing asked.

**Independent Test**: probe rows `other-ascii`, `other-cjk`, `alt-ascii`, `alt-cjk`.

**Acceptance Scenarios**:

1. **Given** "Use the other panel" on and the other panel on a 297-byte ASCII (or 355-byte CJK)
   path, **When** Alt+F9, **Then** no combo entry names a folder under the other panel's tree that
   is not the whole path; OK on the first entry creates nothing under the other panel's tree.
2. **Given** the setting off and the same paths, **When** Alt+F9 and OK on the second entry (or the
   only one), **Then** the same.
3. **Given** a path that fits (200 bytes ASCII, 250 bytes CJK), **When** Alt+F9, **Then** it is
   offered whole and OK unpacks into it - as before.

---

### User Story 2 - The archive subfolder is never dropped silently (Priority: P2)

With "Use the archive name as a subfolder" on, the other panel's path fits but the path plus the
archive's name does not. The dialog does not offer the bare path (which would unpack straight into
the other panel's folder).

**Why this priority**: files land among the other folder's files instead of in a subfolder.

**Independent Test**: probe row `subdir`; control `ctl-subdir`.

**Acceptance Scenarios**:

1. **Given** subfolder on, the other panel on a 245-byte path, an archive name of 20 letters,
   **When** Alt+F9, **Then** no entry is the bare other-panel path; OK creates nothing under the
   other panel's tree.
2. **Given** a 200-byte path, **When** Alt+F9, **Then** the entry is "<path>\a" and OK unpacks into
   it - as before.

---

### User Story 3 - The empty target never becomes a cut archive folder (Priority: P1)

The user presses OK with the empty target (it means "next to the archive") while the archive's
folder path is longer than 259 bytes.

**Why this priority**: the empty entry is the default this feature offers in place of a cut one;
today it unpacks into a new cut folder.

**Independent Test**: probe row `src-long`.

**Acceptance Scenarios**:

1. **Given** the archive in a 297-byte folder and the empty entry, **When** OK, **Then** "The path
   specified is too long." is shown, nothing is created or unpacked, and the dialog opens again.

---

### User Story 4 - A plug-in's long unpack mask is never offered cut (Priority: P3)

A plug-in opens the Unpack dialog for itself with a mask longer than 259 bytes. The dialog offers
"*.*" in place of a cut mask.

**Independent Test**: `saltests` rows of the pure rule (no plug-in of the tree passes a mask).

**Acceptance Scenarios**:

1. **Given** a plug-in mask that fits, **Then** it is offered whole - as before.
2. **Given** a mask that does not fit, **Then** "*.*" is offered, never a prefix of the mask.

### Edge Cases

- The other panel is not a disk (archive, plug-in file system): no other-panel entry - unchanged.
- The other panel's path is exactly 259 bytes: fits, offered whole; 260 bytes: left out.
- The archive's name alone does not fit (empty path + name of 260+ bytes): nothing offered (as
  today), never a cut name.
- Both entries left out: the combo box holds the single empty entry (the empty and the alternative
  entries are equal, shown once - as when the other panel is not a disk).
- A CJK path is never offered as invalid UTF-8 (no garbage entry).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A default target path (the other panel's path, with or without the archive's
  subfolder) is offered only whole; when it does not fit the dialog's 260-byte buffer it is left out
  (the entry stays empty, as for a non-disk other panel).
- **FR-002**: With "Use the archive name as a subfolder", an entry is offered only with its
  subfolder; when path + subfolder does not fit, the entry is left out (never the bare path).
- **FR-003**: A plug-in's unpack mask is offered only whole; one that does not fit is replaced by
  "*.*".
- **FR-004**: After OK, an empty target that would become the archive panel's path is refused with
  "The path specified is too long." when that path does not fit; nothing is created or unpacked and
  the dialog opens again.
- **FR-005**: Defaults that fit are offered and used exactly as before (controls).
- **FR-006**: No new UI string; the existing "The path specified is too long." is reused.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Probe `unpack315_probe.ps1`: rows other-ascii, other-cjk, alt-ascii, alt-cjk, subdir,
  src-long FAIL before and PASS after; the controls ctl, ctl-alt, ctl-subdir PASS before and after.
- **SC-002**: `saltests`: the pure rule's rows pass (whole / left out at 259 / 260 bytes, CJK at a
  letter boundary, subfolder appended or the entry emptied, mask whole or "*.*"); a cut at 259 bytes
  as negative control fails them.
- **SC-003**: Feature 299's probe `unpack299_probe.ps1` still passes 12 / 0.

## Assumptions

- Assumption (autonomous run): "fits" means the UTF-8 text plus its terminator fits 260 bytes
  (MAX_PATH) - the buffers' size and 299's `Validate` limit.
- Assumption (autonomous run): the mask row is not driven by a probe - no plug-in of the tree passes
  a mask; the rule is covered by `saltests` and by reading.
- Out of scope: growing the dialog's buffers beyond 260 bytes; other dialogs.
