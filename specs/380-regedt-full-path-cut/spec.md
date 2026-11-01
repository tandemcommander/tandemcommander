# Feature Specification: Registry Editor - a too long full key path is refused, never cut

**Feature Branch**: `380-regedt-full-path-cut`
**Created**: 2026-11-01
**Status**: Draft
**Input**: Backlog item `regedt-full-path-cut-reported-as-success` - "Registry Editor: a too long
full key path is cut and reported as success". From backlog item regedt-full-path-cut-reported-as-success.

## Background (measured at 823f2873)

When the left panel shows a Registry Editor key and the user types a path relative to it (Change
Directory, Shift+F7, or the command line `cd`), the program asks the plug-in for the full path into
a buffer of 260 bytes. The plug-in converts the full key path to UTF-8 and treats the conversion as
successful whatever its result. A conversion that does not fit fills the buffer, fails, and leaves
the first 259 bytes behind - the program then goes to that cut path.

- Hidden-desktop probe `specs/380-regedt-full-path-cut/probe/regpath380_probe.ps1`
  (`result_before.txt`): under `reg:\HKEY_CURRENT_USER\Software\TcProbe380\<150 x 'x'>`, typing
  100 x 'r' (full path 294 bytes) put the panel, without any message, into the **other existing
  key** `...\<65 x 'r'>` - the path cut at 259 bytes. Under a CJK key, typing 40 CJK letters cut the
  path inside a character; the plug-in then reported "Unable to open registry key ...\uFFFD".
  The control (typing `s`) went to `...\s`.
- The same conversion's result is not checked where the plug-in hands a name back to the panel to
  focus after a rename: Quick Rename (F2, 260 bytes) and a rename by Move (F6 to a new name in the
  same key, 520 bytes). A key or value name may need up to about 1,500 bytes of UTF-8, so the focus
  name can be cut and the panel may focus another item whose name is that cut text.
- The Find window's *Focus* command converts the found item's path and name without checking the
  result (its buffers are large enough today, so it cannot fail at present).

## Clarifications

### Session 2026-11-01

- Q: The program's buffer for the full path is 260 bytes; should the plug-in hand back a longer
  path through a heap buffer? → A: No. The buffer is the caller's (the plug-in interface gives its
  size); the plug-in cannot exceed it. A full path that does not fit is refused with the plug-in's
  "too long path" message. Enlarging the core's buffer is a core change for every file-system
  plug-in and is recorded as a separate backlog item. (autonomous run: item - "prefer a heap buffer
  where the interface allows a longer path"; the interface does not allow it here)
- Q: For a rename whose new name does not fit the panel's focus-name buffer, refuse the rename or
  perform it and not focus? → A: Perform the rename and hand back **no** focus name (never a cut
  one). The name handed back is only a hint the panel uses to focus the item after the refresh;
  the rename itself is a registry operation that does not pass through that buffer, and today it
  succeeds. The plug-in's own *New key* (F7) already does exactly this in the same case. Refusing
  would take away a working rename; handing back nothing is what "never cut" requires.
  (autonomous run: conservative - changes least, loses no function, never acts on a cut name)
- Q: The Find window's *Focus* conversion cannot fail with today's buffers - change it? → A: Yes,
  check it: a conversion that does not fit shows the "too long path" message and focuses nothing
  (the item asks the Find dialog to refuse as well). (autonomous run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A typed relative path never lands in another key (Priority: P1)

The user is in a deep registry key and types a relative path whose full path does not fit the
program's path buffer. The program tells them the path is too long and the panel stays where it
was. It never opens a different key whose name happens to be the cut text.

**Why this priority**: the user then acts (delete, edit, export) on the key the panel shows; a
silently different key is the worst outcome of this defect.

**Independent Test**: the probe's LONG and CJK rows.

**Acceptance Scenarios**:

1. **Given** the panel at a key whose full path is 194 bytes and an existing sibling key named by
   the first 65 letters of the typed name, **When** the user types a 100-letter relative name,
   **Then** the "too long path" message appears and the panel stays at the original key.
2. **Given** a CJK key, **When** the user types a CJK relative path whose full path exceeds 259
   bytes, **Then** the "too long path" message appears (not "unable to open ...\uFFFD") and the
   panel stays.
3. **Given** the same key, **When** the user types a short relative name, **Then** the panel goes
   to it as before (control).

### User Story 2 - A rename never focuses a cut name (Priority: P2)

After a Quick Rename (F2) or a rename by Move (F6 to a new name in the same key) to a long name,
the item is renamed; the panel focuses the renamed item only if its name fits the panel's buffer,
otherwise it focuses nothing new - never an item named by the cut text.

**Why this priority**: a wrong focus after a successful operation can lead the next key press to
another item; narrower than story 1 (needs names over 260 / 520 bytes).

**Independent Test**: code reading of both sites; the result of every conversion is checked and a
failure leaves the focus name empty.

**Acceptance Scenarios**:

1. **Given** a key, **When** it is renamed with F2 to a name that fits, **Then** the renamed item
   is focused as before.
2. **Given** a key, **When** it is renamed to a name whose UTF-8 form does not fit the focus
   buffer, **Then** the rename is done and no cut name is handed to the panel.

### User Story 3 - Find's Focus never sends a cut path (Priority: P3)

The Find window's *Focus* command sends the panel to the found item only with its whole path and
name; a conversion that does not fit is refused with the "too long path" message.

**Independent Test**: code reading (cannot fail with today's buffers).

### Edge Cases

- The full path fits exactly (259 bytes + terminator): accepted as before.
- The conversion fails in the middle of a multi-byte character: refused like any other failure.
- The relative path itself cannot be converted to the plug-in's wide form: refused with the same
  message, never reported as success with the text unchanged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the full key path of a typed relative path does not fit the buffer the program
  gives, the Registry Editor MUST report failure and show its "too long path" message; the panel
  MUST stay at its current key.
- **FR-002**: The Registry Editor MUST NOT report success for the full path with a buffer holding
  anything other than the whole path; a failed conversion of the typed path into its own form MUST
  be reported as failure too.
- **FR-003**: After a Quick Rename and after a rename by Move, the name handed back for focusing
  MUST be the whole new name or empty; never a cut name.
- **FR-004**: The Find window's *Focus* MUST check both conversions (path and name); on a failure
  it MUST show the "too long path" message and send nothing to the panel.
- **FR-005**: Everything else MUST behave as before: paths and names that fit are converted and
  used exactly as today; no new UI text, no change to the plug-in interface.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe's LONG and CJK rows, FAIL before the fix, PASS after it; SHORT PASS in both.
- **SC-002**: No call of the conversion whose output reaches the panel (full path, focus names) is
  left with an unchecked result in the Registry Editor (checked by `grep`).
- **SC-003**: Build succeeds; the encoding guard reports `TOTAL: 0`.

## Assumptions

- Assumption (autonomous run): the remaining unchecked conversions of the plug-in write into
  buffers sized three times the wide maximum (display texts of error and overwrite dialogs,
  `AcceptChangeOnPathNotification`'s comparison key) and cannot fail; they are left unchanged.
- Assumption (autonomous run): rows of the rename and the Find *Focus* are not driven by the probe
  (reading the focused item of the owner-drawn panel and driving the Find window are outside this
  probe); they are proven by reading and recorded in `fix-log.md`.
- Assumption (autonomous run): the existing message `IDS_LONGNAME` is used; no UI string changes,
  so no translation refresh is needed.
