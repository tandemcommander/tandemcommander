# Feature Specification: Pack refuses an archive name whose last part holds a colon

**Feature Branch**: `319-pack-name-colon`
**Created**: 2026-10-23
**Status**: Draft
**Input**: Backlog item pack-writes-the-archive-into-a-hidden-data-stream-when-its (backlog/items/pack-writes-the-archive-into-a-hidden-data-stream-when-its/desc.md) - implement exactly what it describes. From backlog item pack-writes-the-archive-into-a-hidden-data-stream-when-its.

## Background

Pack (Alt+F5) in a disk panel opens the Pack dialog; after OK the archive name (offered or typed,
relative or absolute) is turned into a full path and handed to the packer. A `:` is a drive
separator only as the second character (`C:\x.zip`, `C:x.zip`); anywhere else in a name the NTFS
file system reads `name:stream` as "the stream `stream` of the file `name`". So `report:zip`
(the dialog adds `.zip`) makes the packer create an empty file `report` and write the archive into
its hidden alternate data stream `zip.zip` - invisible to Explorer and to the panel; with an
existing file `report` the archive is attached to it as a hidden stream.

Feature 318 refuses a last part with a trailing dot or space or a device name (the same message,
the dialog again); a colon passes that rule.

Measured at e9c35c2e (hidden-desktop probe derived from 318's, whose snapshot lists every file and
every alternate data stream; the ZIP plug-in, default settings), 6 FAIL / 18 PASS:

- `report:zip`: a new empty file `report` and the stream `report:zip.zip` holding the archive - FAIL;
- `rep:x.zip`: a new `rep` + the stream `rep:x.zip` - FAIL;
- `report:zip` next to an existing file `report`: the stream `report:zip.zip` attached to it,
  `report`'s content unchanged - FAIL;
- `report:zip.zip` where `report` already holds a stream `zip.zip` with an archive: the "already
  exists - add or overwrite?" question, Add, then the ZIP plug-in "Cannot replace original archive
  with temporary working file. Archive was not changed." - yet the stream's content changed and a
  stray temporary file `Sal*.tmp` was left in the folder - FAIL;
- the absolute `<folder>\abs:x.zip`: a new `abs` + the stream - FAIL;
- `plain/rep:x.zip`: the ZIP plug-in itself refused it ("Cannot open or create file.") after its
  "Create New Archive" box, nothing created - FAIL by the item (not refused at OK);
- unchanged and correct: `sub:x\a.zip` (a colon in a folder part) refused by the ZIP plug-in,
  nothing created; item 0 `plain.zip`, `<folder>\abs.zip`, the drive-relative `C:rel.zip` (packed
  into the panel's folder as `rel.zip`) packed; `report.` refused (318); an empty entry refused.

## Clarifications

### Session 2026-10-23

- Q: Which message does the refusal show? → A: the existing "The path specified is invalid." in a box titled Pack, then the dialog again - the message 317 and 318 show (autonomous run: rule - no new UI string without the `.slt` refresh; conservative - one message for one family of refusals)
- Q: An archive that already exists as a stream (`report:zip.zip`) - may the user still add to it, as 318 allows for an existing `report.`? → A: no, it is refused too: the item's *Expected* refuses every last part holding a `:` ("nothing is created or changed"), a stream is never a file the panel shows, and the measured Add damaged the stream and left a stray temporary file (autonomous run: item)
- Q: A colon in a folder part (`sub:x\a.zip`) - refused at OK as well? → A: no, unchanged: the item names the last part; the ZIP plug-in already refuses it and nothing is created (measured) (autonomous run: conservative - keep the existing behaviour for every case the item does not name)
- Q: Does a `/` separate the last part like a `\`? → A: yes, as in 318 - `plain/rep:x.zip` is refused like `rep:x.zip` (autonomous run: rule - the 318 rule's last part starts after `\` or `/`)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A colon in the archive name is refused (Priority: P1)

A user types an archive name containing a colon (`report:zip`, `rep:x.zip`, an absolute
`<folder>\abs:x.zip`). OK shows a message and the dialog again; nothing is written - never an
empty file with the archive hidden in its data stream.

**Why this priority**: the item's defect - the archive cannot be found by ordinary means.

**Independent Test**: probe rows colon-ext, colon-mid, colon-abs, colon-slash: before FAIL, after
PASS.

**Acceptance Scenarios**:

1. **Given** the entry `report:zip`, **When** OK, **Then** "The path specified is invalid." is
   shown, the dialog comes back, and no file or stream is created or changed.
2. **Given** the entry `rep:x.zip`, `<folder>\abs:x.zip` or `plain/rep:x.zip`, **When** OK,
   **Then** the same.

---

### User Story 2 - An existing file is not given a hidden stream (Priority: P1)

A file `report` exists in the folder; the user types `report:zip` (or `report:zip.zip`, also when
`report` already holds such a stream). OK is refused; `report` and its streams stay unchanged and
no temporary file is left.

**Why this priority**: the item's third named case - an existing file silently changed.

**Independent Test**: probe rows colon-exist, colon-stream: before FAIL, after PASS.

**Acceptance Scenarios**:

1. **Given** an existing file `report` and the entry `report:zip`, **When** OK, **Then** the
   refusal as in Story 1; `report` unchanged, no stream added.
2. **Given** a file `report` holding a stream `zip.zip` with an archive and the entry
   `report:zip.zip`, **When** OK, **Then** the refusal; the file and the stream unchanged, no new
   file.

---

### User Story 3 - Drive-letter names and the other names pack as before (Priority: P2)

A user packs with an offered name, an absolute name (`<folder>\abs.zip`) or a drive-relative one
(`C:rel.zip`). These pack exactly as before; 318's refusals stay.

**Why this priority**: the item's "a drive-letter name unchanged" - the regression guard.

**Independent Test**: probe rows ctl-plain, ctl-drive-abs, ctl-drive-rel, trail-dot, ctl-empty,
colon-dir: PASS before and after; 318's probe unchanged.

**Acceptance Scenarios**:

1. **Given** the entry `<folder>\abs.zip` or `C:rel.zip` (the panel's drive), **When** OK,
   **Then** the archive is created as before (`abs.zip`, `rel.zip` in the panel's folder).
2. **Given** `report.` or an empty entry, **When** OK, **Then** the same refusal as before.

### Edge Cases

- A colon right after the drive (`C:x.zip`) is a drive-relative name: it is resolved to a full
  path before the check, whose last part then holds no colon - packed as before.
- A colon in a folder part only (`sub:x\a.zip`): not this feature's - left to the packer, which
  refuses it (measured, nothing created).
- A last part that is only a colon (`:`), or starts with one (`:zip`): refused like any other.
- A name typed in a non-ASCII script with a colon (`zpráva:zip`): refused - the colon byte is
  never part of a UTF-8 multi-byte character.
- An ideographic or full-width colon (U+FF1A `：`) is an ordinary character in a file name: not
  refused.
- The "Use the other panel for packing" option builds an absolute name: the same check applies.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: OK in the Pack dialog MUST refuse an archive name whose last part (after the last
  `\` or `/` of the full name) holds a `:`, with "The path specified is invalid." and the dialog
  again.
- **FR-002**: The refusal MUST happen before anything is created, changed, asked or packed - no
  file, no stream, no temporary file.
- **FR-003**: The refusal MUST apply also when a file or stream of that name already exists.
- **FR-004**: A drive-letter name (`C:\x.zip`, the drive-relative `C:x.zip`) and every name
  without a colon in its last part MUST behave exactly as before, including 317's and 318's
  refusals.
- **FR-005**: No new UI string; the rule MUST be a pure, unit-tested decision.

### Key Entities

- **Archive name**: the full path the dialog's entry resolves to; its last part is the archive's
  file name.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The 6 colon rows of the probe (colon-ext, colon-mid, colon-exist, colon-stream,
  colon-abs, colon-slash) go from FAIL to PASS: no new file or stream, nothing changed.
- **SC-002**: The control rows (ctl-plain, ctl-drive-abs, ctl-drive-rel, trail-dot, ctl-empty,
  colon-dir) PASS before and after; 318's probe still all PASS.
- **SC-003**: The unit checks of the rule pass, and fail when the colon test is disabled
  (negative control).

## Assumptions

- Assumption (autonomous run): the check sits with 318's in the Pack command, after the name is
  made full, so it covers every packer (ZIP, 7-Zip, external archivers) at once.
- Assumption (autonomous run): a `:` after the second character of a full Windows path is never a
  valid file-name character (Microsoft's naming rules); a UNC path never needs one.
- Other characters Windows forbids (`* ? < > | "`) are out of scope (the item measured `*` refused
  by the packer).
