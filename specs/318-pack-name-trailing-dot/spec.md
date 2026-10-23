# Feature Specification: Pack refuses an archive name the file system would not keep as typed

**Feature Branch**: `318-pack-name-trailing-dot`
**Created**: 2026-10-23
**Status**: Draft
**Input**: Backlog item pack-archive-name-trailing-dot-or-space (backlog/items/pack-archive-name-trailing-dot-or-space/desc.md) - implement exactly what it describes. From backlog item pack-archive-name-trailing-dot-or-space.

## Background

Pack (Alt+F5) in a disk panel opens the Pack dialog; after OK the archive name (offered or typed,
relative or absolute) is turned into a full path and handed to the packer. Windows normally trims
trailing dots and spaces from a file name and treats a reserved device name (`CON`, `NUL`, `COM1`,
...) as a device - but the ZIP plug-in creates the archive through a path form that skips those
rules, so the name is written literally. A file named `report.` or `report.zip ` cannot be opened,
renamed or deleted by ordinary Windows programs. (A device name with an extension, `CON.zip`, is an
ordinary file on this Windows 11 build - see Clarifications.)

The dialog appends the packer's extension only to a name without a dot, so `report.` reaches the
packer as typed. Feature 317 already refuses a last part made only of spaces and dots (` ..`).

Measured at efb9b0ad (hidden-desktop probe derived from 317's, the ZIP plug-in, default settings),
12 FAIL / 30 PASS:

- created literally, NOT openable through an ordinary path: `report.`, `report.zip..`,
  `report.zip `, `report. `, and the absolute `<folder>\abs.` - FAIL;
- created literally, openable through an ordinary path on this Windows 11 build (10.0.26300):
  `CON.zip`, `con` (the dialog adds `.zip`), `NUL .zip`, `COM1.zip`, `lpt9.tar.zip`,
  `COM<superscript 1>.zip`, the absolute `<folder>\prn.zip` - FAIL by the item's *Expected*;
- correct and unchanged: ` ..` refused ("The path specified is invalid.", 317); `plain.zip`,
  `report.v1.zip`, `CONSOLE.zip`, `con bla.zip`, `COM10.zip`, ` typed.zip`, `.cfg.zip` packed; an
  empty entry refused ("Empty name has no sense here.").

## Clarifications

### Session 2026-10-23

- Q: Should a device name with an extension (`CON.zip`) be refused although this Windows 11 build opens it through an ordinary path? → A: yes, refused like a trailing dot or space (autonomous run: item - *Expected* names "a device name" among the names to refuse)
- Q: Which message does the refusal show? → A: the existing "The path specified is invalid." in a box titled Pack, then the dialog again - the message 317 shows for ` ..` (autonomous run: rule - no new UI string without the `.slt` refresh; conservative - one message for one rule)
- Q: Is a device name preceded by spaces (` CON.zip`) or a name ending in a control character (a tab) refused too? → A: no - their behaviour is unchanged; Windows does not treat ` CON` as a device and does not trim a tab, the item names neither (autonomous run: conservative - keep the existing behaviour for every case the item does not name)
- Q: An archive that already exists under such a name (`aux.zip`, an archive literally named `report.` by an earlier Pack) - may the user still add to it or overwrite it? → A: yes, as before 318: the name is refused only when no file of exactly that name exists (checked through `\\?\`, so an existing `report` never counts for `report.`); nothing new is created by adding (autonomous run: conservative - keep the existing behaviour for every case the item does not name; review of 318, SHOULD 1)
- Q: Does a `/` in the entry separate the last part like a `\`? → A: yes - the packers' path conversion turns `/` into `\`, so `./CON.zip` and `sub/CON.zip` are refused like `CON.zip` (autonomous run: rule - FR-005 "every name"; review of 318, NOTE 2)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A trailing dot or space is refused (Priority: P1)

A user types an archive name that ends with a dot or a space (by mistake, or `report.` meaning "no
extension"). OK shows a message and the dialog again; nothing is written - never a file other
programs cannot open or delete.

**Why this priority**: the item's main defect - a literal file Windows tools cannot handle.

**Independent Test**: probe rows trail-dot, trail-dots, trail-space, trail-dot-space,
abs-trail-dot: before FAIL, after PASS.

**Acceptance Scenarios**:

1. **Given** the entry `report.`, **When** OK, **Then** "The path specified is invalid." is shown,
   the dialog comes back, and no file is created or changed.
2. **Given** the entry `report.zip ` (or `report.zip..`, `report. `), **When** OK, **Then** the same.
3. **Given** an absolute entry `<folder>\abs.`, **When** OK, **Then** the same.

---

### User Story 2 - A reserved device name is refused (Priority: P2)

A user types an archive name whose last part is a reserved device name, with or without an
extension (`CON.zip`, `con` which the dialog turns into `con.zip`, `NUL .zip`, `COM1.zip`,
`lpt9.tar.zip`). OK shows the same message and the dialog again; nothing is written.

**Independent Test**: probe rows dev-con, dev-con-noext, dev-nul-space, dev-com1, dev-lpt9-2ext,
dev-com-sup, abs-dev: before FAIL, after PASS.

**Acceptance Scenarios**:

1. **Given** the entry `CON.zip`, **When** OK, **Then** the message, the dialog again, nothing
   created.
2. **Given** the entry `con`, **When** OK, **Then** the same (the name became `con.zip`).

---

### User Story 3 - Everything else unchanged (Priority: P3)

Names with dots or spaces inside, names that only start with a device name, names with a leading
space (317), and an empty entry behave as before.

**Independent Test**: probe rows space-dots, ctl-plain, ctl-mid-dot, ctl-console, ctl-con-word,
ctl-com10, ctl-lead-space, ctl-dot-start, ctl-empty: PASS before and after.

### Edge Cases

- ` ..` / ` .` (317) stay refused with the same message.
- `report.v1.zip`, `.cfg.zip`, ` typed.zip` (dots inside, a leading dot, a leading space) are packed.
- `CONSOLE.zip`, `con bla.zip`, `COM10.zip` are not device names - packed.
- A device name followed by spaces before the extension (`NUL .zip`) is a device name - refused.
- A device name preceded by spaces (` CON.zip`) and a name ending in a tab are unchanged (see
  Clarifications).
- Only the last part of the path is checked. A folder part with a trailing dot or a device name
  (`sub.\a.zip`, `CON\a.zip`) is not refused by this rule; the ZIP plug-in refused each such name
  itself ("path not found"), nothing created (measured by the review of 318).
- An existing file of exactly the refused name (`aux.zip`, a literal `report.`) is not refused: the
  "add or overwrite?" question as before. An existing `report` does not count for `report.`.
- A `/` separates like `\` (`./CON.zip`, `plain/CON.zip` refused).
- "Use the other panel for packing" on offers an absolute name - the same rule applies to it.
- The refusal comes before the "add or overwrite?" question and before the "archive is one of the
  packed items" check: nothing is asked, nothing is touched.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: After OK in the Pack dialog, an archive name whose last part ends with a dot or a
  space MUST be refused with the existing "The path specified is invalid." message and the dialog
  shown again; no archive is written and no existing file is changed, moved or deleted - unless a
  file of exactly that name already exists (FR-007).
- **FR-002**: An archive name whose last part is a reserved device name - `CON`, `PRN`, `AUX`,
  `NUL`, `COM0`-`COM9`, `LPT0`-`LPT9`, `COM`/`LPT` followed by a superscript 1, 2 or 3 - alone or
  followed by spaces and/or an extension (everything from the first dot), compared without regard
  to letter case, MUST be refused the same way.
- **FR-003**: The refusal of 317 (a last part of only spaces and dots) MUST stay (it is a case of
  FR-001).
- **FR-004**: Every other archive name MUST behave as before - in particular names with dots or
  spaces inside or at the start, and names that only begin with a device name.
- **FR-005**: The rule MUST apply to relative and absolute names alike, to the offered and the typed
  name, for every packer.
- **FR-006**: No new UI string; no change to the packers or the plug-in interface.
- **FR-007**: When a file of exactly the typed name already exists (an existence check that does
  not trim dots or spaces), the name MUST NOT be refused: adding to it or overwriting it works as
  before 318.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 12 of 12 measured names the file system would not keep as typed are refused with no
  file written: before 12 FAIL, after 12 PASS.
- **SC-002**: The 9 rows that must not change (317's refusal, 7 packed controls, the empty entry)
  pass before and after.
- **SC-003**: The rule is checked by unit checks covering every case of FR-001 and FR-002 and their
  near misses.

## Assumptions

- Assumption (autonomous run): device names are refused although on this Windows 11 build an
  ordinary path opens and creates `CON.zip`, `aux.zip` and even `con` (measured before the change
  and by the review) - the item's *Premise* that Windows tools cannot open them does not hold here;
  they are refused because the item's *Expected* names them and the program's own name rule (used
  for names coming from archives) treats them as invalid. The user loses only the ability to create
  a new archive named like a device; an existing one is added to as before (FR-007).
- Assumption (autonomous run): the device list is Microsoft's documented list of reserved names
  (including `COM0`/`LPT0` and the superscript digits) - refusing a name that is harmless on a
  newer Windows is preferred to writing one that is not on another.
- Assumption (autonomous run): the existing message "The path specified is invalid." (used by 317
  for the same dialog) is the refusal message - no new string.
- Assumption (autonomous run): other characters Windows forbids in names (`* ? < > | " :`) are out
  of scope - the item names only trailing dots/spaces and device names; their behaviour is unchanged.
- Assumption (autonomous run): external archivers are not driven by the probe; the check happens in
  the program before any packer runs, so it covers them too.
