# Feature Specification: Pack never drops the leading space of a relative archive name

**Feature Branch**: `317-pack-name-space`
**Created**: 2026-10-23
**Status**: Draft
**Input**: Backlog item pack-with-a-relative-archive-name-that-starts-with-a-space (backlog/items/pack-with-a-relative-archive-name-that-starts-with-a-space/desc.md) - implement exactly what it describes. From backlog item pack-with-a-relative-archive-name-that-starts-with-a-space.

## Background

Pack (Alt+F5) in a disk panel opens the Pack dialog. With nothing selected it offers the focused
item's name + the packer's extension as the archive name - a relative name, meaning "an archive
next to the packed items" (with "Use the other panel for packing" off, the default). A user may
also type a relative name.

After OK, the program turns a relative name into a full path. That step drops every space at the
start of a relative name, so a folder ` report` offers ` report.zip`, but OK packs into
`report.zip` - another archive. When `report.zip` already exists, the "add or overwrite?" question
names that other archive, and Add puts the items into it (Overwrite would replace it). An absolute
name that starts with a space in its last part (`<folder>\ abs.zip`) keeps the space - the program
and the ZIP plug-in already write such an archive.

Feature 316 fixed the same step for the Unpack dialog.

Measured at d526127f (hidden-desktop probe `packspace_probe.ps1`, the ZIP plug-in packer, the
defaults "Use the other panel for packing" off and the "add to archive?" question on), 7 FAIL /
11 PASS:

- space-dir (folder ` report`, the entry ` report.zip`): `report.zip` created - FAIL.
- space-dir-exists (the same, `report.zip` already next to it): the question "The file
  "report.zip" already exists...", Add changed `report.zip`; no ` report.zip` - FAIL.
- space-file (file ` notes.txt`, the entry ` notes.zip`): `notes.zip` - FAIL.
- space2-dir (folder `  two`, two spaces): `two.zip` - FAIL.
- typed-space (the entry ` typed.zip`) and typed-space-noext (` typed`, the dialog adds `.zip`):
  `typed.zip` - FAIL.
- the entry `   ` (spaces only; the dialog adds `.zip`): `.zip` created - FAIL of the first probe
  version, which expected a refusal (see Edge Cases).
- ctl-plain (`plain` -> `plain.zip`) and ctl-abs-space (`<src>\ abs.zip` -> ` abs.zip`): PASS.

## Clarifications

### Session 2026-10-23

- Q: A relative archive name starting with a space - create the archive with the space, or refuse? → A: create it with the space, exactly as the entry shows; the same archive given as an absolute name is already created with the space, and creating a file (unlike a folder, feature 316) is not refused anywhere (autonomous run: item - "OK packs into the archive the entry shows (the leading space kept)")
- Q: Only the offered name, or also a relative name the user typed? → A: every relative archive name of the Pack dialog - the program cannot tell an offered entry from a typed one, both show the space and both lost it (autonomous run: item - "The same applies to a typed relative name with a leading space")
- Q: An entry of spaces only (the dialog appends the extension: `   .zip`) - what then? → A: the leading spaces are kept like any other relative name (`   .zip`); before, the spaces were dropped and the archive `.zip` was made - neither is what an empty-looking entry shows, but no rule refuses it today and the item names no such case; an empty entry stays refused ("empty name") (autonomous run: conservative - one rule for every relative name, no new refusal or string)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The offered archive name is the archive written (Priority: P1)

A user packs a file or folder whose name starts with a space; the dialog offers that name + the
extension. OK packs into the archive exactly as shown - with the leading space(s) - never into the
archive without the space; an existing archive of that other name is never asked about or touched.

**Why this priority**: the item's defect - items packed into an archive the dialog never showed,
and an existing archive of that other name updated or overwritten.

**Independent Test**: probe rows space-dir, space-dir-exists, space-file, space2-dir: before FAIL,
after PASS.

**Acceptance Scenarios**:

1. **Given** a folder ` report`, **When** OK on ` report.zip`, **Then** the archive ` report.zip`
   is created next to it and holds the folder's file; no `report.zip` is created.
2. **Given** a folder ` report` and an archive `report.zip` next to it, **When** OK on
   ` report.zip`, **Then** no question about `report.zip` is asked, `report.zip` is unchanged, and
   ` report.zip` is created.
3. **Given** a file ` notes.txt`, **When** OK on ` notes.zip`, **Then** ` notes.zip` is created.
4. **Given** a folder `  two` (two spaces), **When** OK on `  two.zip`, **Then** `  two.zip` is
   created.

---

### User Story 2 - A typed relative archive name keeps its space (Priority: P2)

A user types a relative archive name starting with a space (` typed.zip`, or ` typed` to which the
dialog adds the extension). OK packs into ` typed.zip` - never into `typed.zip`.

**Independent Test**: probe rows typed-space, typed-space-noext: before FAIL, after PASS.

**Acceptance Scenarios**:

1. **Given** the entry ` typed.zip`, **When** OK, **Then** ` typed.zip` is created.
2. **Given** the entry ` typed`, **When** OK, **Then** ` typed.zip` is created.

---

### User Story 3 - Everything else unchanged (Priority: P3)

Absolute archive names, relative names without a leading space, and an empty entry behave as
before.

**Independent Test**: probe rows ctl-plain, ctl-abs-space, ctl-empty: PASS before and after.

### Edge Cases

- An empty entry stays refused ("empty name"), the dialog again, nothing created.
- An entry of spaces only gets the extension from the dialog and keeps its spaces (`   .zip`);
  before it became `.zip` (see Clarifications).
- A relative name starting with spaces and then `\` (`  \x.zip`) keeps its meaning (the root of the
  panel's drive) - unchanged.
- A drive-letter name with leading spaces (`  C:\x.zip`) keeps today's trimming - unchanged.
- The "add or overwrite?" question, the "archive is one of the packed items" refusal (119) and the
  Overwrite aside (176) work with the name with its space.
- "Use the other panel for packing" on offers an absolute name - unchanged (it already kept the
  space).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After OK in the Pack dialog, a relative archive name (no drive, not starting with `\`
  after its spaces) MUST keep its leading spaces when it is turned into a full path.
- **FR-002**: Every step after OK (the "packed into itself" check, the "add or overwrite?" question,
  Overwrite, the packer, the refresh of the folder) MUST use that name - never the name without
  the spaces.
- **FR-003**: Absolute archive names, relative names without leading spaces, and an empty entry
  MUST behave as before.
- **FR-004**: No new UI string; no change to the packers or the plug-in interface.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 6 of 6 measured cases with a leading space (four offered names, two typed) the
  archive written is the one the entry shows: before 6 FAIL, after 6 PASS.
- **SC-002**: An existing archive whose name is the shown name without the space is never asked
  about or changed (row space-dir-exists).
- **SC-003**: The control rows pass unchanged before and after.

## Assumptions

- Assumption (autonomous run): archives whose name starts with a space are created (no refusal) -
  the program already creates them for an absolute name; refusing them is not part of the item.
- Assumption (autonomous run): external archivers receive the archive name quoted
  (`"$(ArchiveFullName)"`), so the space reaches them; they are not driven by the probe (the ZIP
  plug-in, the default for .zip, is).
- Assumption (autonomous run): other dialogs that turn a relative name into a full path (Change
  Directory, Create Directory, the plug-in service) are out of scope.
