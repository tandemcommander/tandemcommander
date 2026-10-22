# Feature Specification: Drive Information writes the volume label as typed

**Feature Branch**: `300-volume-label-wide`
**Created**: 2026-10-22
**Status**: Draft
**Input**: Backlog item volume-label-written-through-ansi-api (backlog/items/volume-label-written-through-ansi-api/desc.md) - implement exactly what it describes. From backlog item volume-label-written-through-ansi-api.

## Background

Drive Information (the CM_DRIVEINFO command: menu, toolbar, the drive's information from the panel
and the status bar) shows the volume label of the panel's drive in an edit field; when the user
changes it and presses OK, the program writes the new label to the drive. The program reads the
typed label as UTF-8 and then hands those bytes, together with the volume path (also UTF-8), to the
Windows call that reads its text **in the system code page**. Every letter outside ASCII is
therefore written as two or three wrong letters: `Zálohy` (UTF-8 `5A C3 A1 6C 6F 68 79`) on code
page 1250 is written as `ZĂˇlohy`. A mounted-folder volume path with a non-ASCII letter would name
another (non-existent) path.

The project's encoding checker lists the Windows calls that take a name or path in the code page;
this call is missing from the list, so the checker could not report it.

Measured at 82bf0dac (by reading and with the checker; the write itself is not driven): the site is
the only call of its kind in the core; the core is built without `UNICODE`, so the call is the
code-page variant; the checker's report-only rule `ansi-api-on-utf8-path` reports 39 findings at
HEAD and 40 with the call added to its list - the one new hit is exactly this site; the plug-in
scan finds no such call. The run is not elevated and the machine has no removable drive, so the
real write is a step owed to a person.

## Clarifications

### Session 2026-10-22

- Q: What does OK do when the typed label or the volume path cannot be converted to wide text? → A: nothing is written; the existing "Unable to change drive label." message is shown with the Windows text of the conversion error and the dialog stays with the label field marked (autonomous run: conservative - refuse rather than guess, no new UI string)
- Q: Should the label field become a wide (Unicode) field so letters outside the code page can be typed? → A: no - the field stays as it is; only the write changes (autonomous run: item - its *Expected* names the write and the checker only)
- Q: Should the checker's `ansi-api-on-utf8-path` rule become strict, or get a strict guard for the label call? → A: no - the call is added to the rule's list, the rule stays report-only (autonomous run: item - "`SetVolumeLabel` is added to the checker's `ANSI_NAME_API` list")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A non-ASCII label is written as typed (Priority: P1)

A user opens Drive Information on a drive (a USB stick, or a fixed drive with administrator rights),
types the label `Zálohy` (or `Диск`, as far as the field accepts it) and presses OK. The drive's
label is now exactly `Zálohy` - Explorer and a second opening of Drive Information show it so.

**Why this priority**: it is the defect - today the drive receives a garbled label.

**Independent Test**: the program no longer uses the code-page variant of the call at all (its
import list names only the wide variant); the real write on a scratch drive is a person step.

**Acceptance Scenarios**:

1. **Given** a drive whose label the user may change, **When** the user types `Zálohy` and presses
   OK, **Then** the drive's label is `Zálohy` (not `ZĂˇlohy`).
2. **Given** an ASCII label (`BACKUP`), **When** OK is pressed, **Then** the label is `BACKUP` - as
   before.
3. **Given** the label is left unchanged, **When** OK is pressed, **Then** nothing is written - as
   before (feature 069).

---

### User Story 2 - A failed write is still reported (Priority: P2)

A user without the right to change the label (a fixed drive, the program not elevated) types a new
label and presses OK. The program shows "Unable to change drive label." with the Windows error
text (access denied) and keeps the dialog open with the label field marked - as before.

**Why this priority**: the error path must keep working after the call changes.

**Independent Test**: hidden-desktop probe: Drive Information on a fixed drive, unelevated, a new
label, OK → the error box, the dialog stays; the drive's label is unchanged.

**Acceptance Scenarios**:

1. **Given** an unelevated program and a fixed drive, **When** a new label is typed and OK pressed,
   **Then** the error message with the access-denied text appears and the label is not changed.

---

### User Story 3 - The checker covers the call (Priority: P3)

A developer adds a new code-page call of the label-writing API with a UTF-8 path or name; the
encoding checker's `ansi-api-on-utf8-path` report lists it.

**Why this priority**: it keeps the defect from returning unseen.

**Independent Test**: the checker's report before and after the fix, and a negative control (the
call put back in a scratch copy is reported).

**Acceptance Scenarios**:

1. **Given** the fixed tree, **When** the checker's `ansi-api-on-utf8-path` report runs, **Then**
   it lists no label-writing call and its count is back to the 39 of HEAD; the strict run stays at
   `TOTAL: 0`.
2. **Given** a scratch copy with the old call, **When** the report runs, **Then** the call is
   listed.

### Edge Cases

- The typed label cannot be converted to the wide form (not valid UTF-8 / WTF-8, or no memory):
  nothing is written; the existing "Unable to change drive label." message is shown with the
  Windows text of the conversion error and the dialog stays (refuse, never guess).
- The volume path cannot be converted: the same refusal.
- An empty label (the user cleared the field): written as empty - the label is removed, as before.
- A label too long for the field's buffer: refused before any write (feature 270) - unchanged.
- A label with letters outside the system code page typed into the field: the field itself may
  turn them into `?` (the dialog is a code-page dialog, feature 069 note); this feature does not
  change the field. What the field holds is written exactly.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The label typed in Drive Information MUST reach the drive exactly as the field holds
  it - no conversion through the system code page.
- **FR-002**: The volume path given with the label MUST likewise reach the system unchanged (wide
  text), so a mounted-folder path with non-ASCII letters names the right volume.
- **FR-003**: When the label or the path cannot be converted to the wide form, the program MUST NOT
  write anything; it MUST show the existing "Unable to change drive label." message with the
  conversion error and keep the dialog open with the label field marked.
- **FR-004**: Every other behaviour of Drive Information MUST stay as it is: no write when the
  label is unchanged, the refusal of a too-long label (270), the panels' hands-off around the write,
  the error message on a failed write.
- **FR-005**: The encoding checker's list of name-taking code-page calls MUST include the
  label-writing call, so its `ansi-api-on-utf8-path` report lists any code-page use with a UTF-8
  path or name; any other site the addition finds MUST be fixed or recorded (measured: none).
- **FR-006**: No user-interface text is added or removed.

### Key Entities

- **Volume label**: the drive's name, up to 32 letters (NTFS) / 11 (FAT); read and shown already
  as wide text (feature 004).
- **Volume path**: the drive root (`E:\`) or a mounted folder, with a trailing backslash.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The program's executable no longer uses the code-page variant of the label-writing
  call (0 imports of it after, 1 before).
- **SC-002**: The checker's `ansi-api-on-utf8-path` report, with the call in its list, shows 0 hits
  of the call after the fix (1 before), and the strict run stays at 0 findings.
- **SC-003**: The unelevated error path (probe) shows the error message and leaves the drive's
  label unchanged - 100% of the probe rows PASS.
- **SC-004**: On a scratch drive, a label `Zálohy` typed in Drive Information is shown as `Zálohy`
  by Explorer (person step).

## Assumptions

- The conversion-failure behaviour, the label field and the checker rule's strictness are settled
  in *Clarifications*.
- The real write needs an elevated program for a fixed drive or a removable drive; neither is
  available in the run - the confirmation is a person step (the item's `who: both`).
