# Feature Specification: Unpack never drops the leading space of a relative target

**Feature Branch**: `316-unpack-subdir-space`
**Created**: 2026-10-23
**Status**: Draft
**Input**: Backlog item unpack-into-a-subfolder-named-after-an-archive-whose-name (backlog/items/unpack-into-a-subfolder-named-after-an-archive-whose-name/desc.md) - implement exactly what it describes. From backlog item unpack-into-a-subfolder-named-after-an-archive-whose-name.

## Background

Unpack (Alt+F9) on an archive in a disk panel opens the Unpack dialog. With "Use the archive name
as a subfolder" on, the dialog offers the archive's name (without its extension) as the target
subfolder: appended to the other panel's path when that panel is a disk and the result fits
(feature 315), otherwise alone - a relative name, meaning "a subfolder next to the archive". A user
may also type a relative target.

After OK, the program turns a relative target into a full path. That step drops every space at the
start of a relative target, so an archive named ` ssss.zip` offers ` ssss`, but OK unpacks into
`ssss` - another folder; an existing `ssss` folder is merged into (overwrite questions are still
asked). An absolute target that names a folder starting with a space keeps the space; when that
folder does not exist yet, the program refuses to create it ("Error Creating Directory" - the name
is invalid) and shows the dialog again - an existing rule for folders the user asks for, kept here.

Measured at b125acf7 (hidden-desktop probe `unpack316_probe.ps1`, the ZIP plug-in unpacking an
archive holding a.k and a.kp):

- space-sd (subfolder on, other panel off, archive ` ssss.zip`, a folder `ssss` already next to
  it, the entry ` ssss`): unpacked into `ssss`, merged with the existing folder - FAIL.
- space-sd-long (both on, the other panel 245 bytes, archive ` ` + 19 letters: the name alone is
  offered): unpacked into the 19-letter folder - FAIL.
- space2-sd (archive `  ss.zip`, two spaces): unpacked into `ss` - FAIL.
- typed-space (both off, the entry ` typed`): unpacked into `typed` - FAIL.
- ctl-abs-space (both on, a short other panel, the entry `<other panel>\ ssss`): refused with
  "Error Creating Directory (invalid name)", the dialog again, nothing unpacked.
- ctl-typed (`typed`) and ctl-blank (spaces only = an empty target, next to the archive): as
  expected.

## Clarifications

### Session 2026-10-23

- Q: A relative target starting with a space names a folder that does not exist yet - create it with the space, or refuse? → A: refuse, by the rule that already applies to the same folder given as an absolute path ("Error Creating Directory", the name is invalid, the dialog again); an existing folder of that name is unpacked into (autonomous run: item - "or the program refuses with a message"; conservative - the existing create rule is kept for every case the item does not name)
- Q: Only the archive-name default, or also a relative target the user typed? → A: every relative target of the Unpack dialog - the program cannot tell an offered entry from a typed one, both show the space and both lost it; the Copy/Move target already keeps such a space (autonomous run: item - "OK unpacks into the folder the entry shows")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The offered subfolder is the folder used (Priority: P1)

A user unpacks an archive whose name starts with a space with "Use the archive name as a subfolder"
on, and the dialog offers the name alone (a subfolder next to the archive). OK either unpacks into
the folder exactly as shown - with the leading space(s) - or refuses with a message; it never
unpacks into the folder without the space, and never touches an existing folder of that other
name.

**Why this priority**: the item's defect - files landing in, and merging with, a folder the dialog
never showed.

**Independent Test**: probe rows space-sd, space-sd-long, space2-sd: before FAIL (files in the
folder without the space), after PASS.

**Acceptance Scenarios**:

1. **Given** the archive ` ssss.zip`, a folder `ssss` next to it and no folder ` ssss`, the entry
   ` ssss`, **When** OK, **Then** a message refuses the target, the dialog shows again, nothing is
   unpacked and `ssss` is unchanged.
2. **Given** the same with the other panel's path too long for path + name (the name alone
   offered), **When** OK, **Then** the same refusal; nothing is unpacked.
3. **Given** the archive `  ss.zip` (two spaces), **When** OK on `  ss`, **Then** the same refusal.
4. **Given** a folder ` ssss` already next to the archive ` ssss.zip`, **When** OK on ` ssss`,
   **Then** the files are unpacked into ` ssss`.

---

### User Story 2 - A typed relative target keeps its space (Priority: P2)

A user types a relative target starting with a space (` typed`). OK unpacks into that folder when
it exists, or refuses with the same message - never into `typed`.

**Independent Test**: probe row typed-space: before FAIL, after PASS.

**Acceptance Scenarios**:

1. **Given** no folder ` typed`, **When** OK on ` typed`, **Then** refused, the dialog again,
   nothing unpacked, no folder `typed` created.

---

### User Story 3 - Everything else unchanged (Priority: P3)

Absolute targets, relative targets without a leading space, and an entry of spaces only (an empty
target = next to the archive) behave as before.

**Independent Test**: probe rows ctl-abs-space, ctl-typed, ctl-blank: PASS before and after.

### Edge Cases

- An entry of spaces only stays an empty target ("next to the archive", feature 315's rules).
- A relative target starting with spaces and then `\` (`  \x`) keeps its meaning (the root of the
  archive's drive) - unchanged.
- A drive-letter target with leading spaces (`  C:\x`) keeps today's trimming - unchanged.
- The cursor's next focus after unpacking names the folder used (the one with the space).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After OK in the Unpack dialog, a relative target (no drive, not starting with `\`
  after its spaces) MUST keep its leading spaces when it is turned into a full path.
- **FR-002**: A target folder starting with a space that does not exist MUST be refused with the
  existing "Error Creating Directory" message and the dialog shown again, as for the same folder
  given as an absolute path; nothing is unpacked and no other folder is created.
- **FR-003**: An existing folder starting with a space MUST be unpacked into when the entry names
  it.
- **FR-004**: Absolute targets, relative targets without leading spaces, targets of spaces only and
  every other Unpack default (feature 315) MUST behave as before.
- **FR-005**: No new UI string.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 4 of 4 measured cases with a leading space (three archive names, one typed
  target) no file lands in a folder whose name differs from the entry: before 4 FAIL, after 4 PASS.
- **SC-002**: An existing folder starting with a space receives the files (a new probe row PASS).
- **SC-003**: The 3 control rows and 315's probe pass unchanged.

## Assumptions

- Assumption (autonomous run): creating folders whose name starts with a space stays refused for
  the Unpack dialog (the existing rule for folders the user asks for); allowing it is not part of
  the item.
- Assumption (autonomous run): other dialogs that turn a relative target into a full path (Pack,
  Change Directory, Create Directory) are out of scope.
