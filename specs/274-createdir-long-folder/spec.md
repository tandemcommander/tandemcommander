# Feature Specification: Create Directory takes a relative name in a long folder

**Feature Branch**: `274-createdir-long-folder`  
**Created**: 2026-10-21  
**Status**: Draft  
**Input**: User description: "Backlog item create-directory-refuses-a-relative-name-in-a-folder-whose - implement exactly what it describes: F7 in a panel whose path is 288 bytes creates a folder from a typed relative name (also of 100 CJK letters); a name over 255 UTF-16 units and a path over the program's limit are refused with a message that says so; a probe row shows the refusal before and the creation after." From backlog item create-directory-refuses-a-relative-name-in-a-folder-whose.

## Measured before (449f35fc)

Probe `probe/createdir274_probe.ps1` (F7 = command 730, hidden desktop, Debug x64), label
before - 8 PASS / 4 FAIL (`probe/result_before.txt`):

- SHORT - "nd" in a 45-byte folder: created (control).
- REL - "nd" in a folder whose path is 288 bytes: refused "The path specified is too long."
- CJK - 100 CJK letters (300 bytes) in the 288-byte folder: refused the same.
- U255 - 255 CJK letters (765 bytes, a valid name) in a 44-byte folder: refused the same - the
  defect is not limited to deep folders: any relative name whose joined path reaches 260 bytes.
- U256 - 256 CJK letters (no file system takes it): refused with "The path specified is too
  long." - the wrong reason; the name is too long, not the path.
- LIMIT - a relative path of 98,244 bytes in the 288-byte folder (the joined path is longer than
  the program's limit): refused "The path specified is too long." - correct.

Other callers of the same joining routine that take a typed name with the default limit: Pack
(Alt+F5), Unpack (Alt+F9), the file list (Make File List to a file, and its dialog's Browse).
Their name buffers hold 259 bytes, so the default limit equals their buffer: a refusal there is
a limit of those routines, not this defect. Edit New File was fixed in feature 259.

## Clarifications

### Session 2026-10-21

- Q: Which message does Create Directory show for a new folder name over 255 UTF-16 units? → A: The existing "Cannot finish operation because of too long name." (IDS_TOOLONGNAME) in the Create Directory error window with the path; the dialog comes back with the text (autonomous run: rule - feature 259 answered the same question for Edit New File the same way; no new UI string)
- Q: Are the other callers (Pack, Unpack, Make File List) changed too? → A: No - their buffers are 259 bytes and the default limit matches them; they are listed, not changed (autonomous run: item - "fix only F7 unless they are the same few lines")

## User Scenarios & Testing *(mandatory)*

### User Story 1 - New folder by a relative name in a long folder (Priority: P1)

A user works in a disk folder whose path is 260 bytes or longer (a deep tree, or names in scripts
that take three bytes per letter), presses F7 and types the new folder's name.

**Why this priority**: it is the measured refusal of valid work; the rest of Create Directory and
the program take such paths.

**Independent Test**: probe rows REL, CJK, U255 (and SHORT as the control).

**Acceptance Scenarios**:

1. **Given** a panel in a folder whose path is 288 bytes, **When** the user presses F7, types
   "nd" and confirms, **Then** the folder "nd" is created there.
2. **Given** the same panel, **When** the user types a name of 100 CJK letters, **Then** a folder
   of exactly that name is created.
3. **Given** a panel in a short folder, **When** the user types a name of 255 CJK letters (exactly
   255 UTF-16 units), **Then** a folder of exactly that name is created.
4. **Given** a short folder and a short name, **When** the user confirms, **Then** the folder is
   created as before.

---

### User Story 2 - Refusals that say the true reason (Priority: P2)

**Why this priority**: the user must learn why nothing was created; the old text blamed the path.

**Independent Test**: probe rows U256, LIMIT.

**Acceptance Scenarios**:

1. **Given** a panel in a short folder, **When** the user types a name of 256 CJK letters,
   **Then** nothing is created and the message says the name is too long ("Cannot finish
   operation because of too long name."); the dialog comes back with the text.
2. **Given** a panel in the 288-byte folder, **When** the user types a relative path whose joined
   full path is longer than the program's path limit, **Then** nothing is created and the message
   says "The path specified is too long."; the dialog comes back.

### Edge Cases

- A typed full path (absolute) already worked and keeps working the same.
- A relative name of several components ("a\b"): the folders are created as before (the
  question about creating missing folders is unchanged); only the joined length limit changes.
- A name of 260+ bytes is created but not focused after the refresh (the focus slot holds one
  name of up to 259 bytes) - the same limit as Edit New File (259).
- An intermediate component over 255 UTF-16 units in a multi-component name keeps the system's
  answer (unchanged; only the new folder's own name is judged).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Create Directory on a disk panel MUST join a typed relative name with the panel
  path for any joined path that fits the program's path limit (the limit its dialog and the rest
  of the routine already use), and create the folder whole.
- **FR-002**: A joined path that does not fit the program's path limit MUST be refused with "The
  path specified is too long." before anything is created; the dialog comes back.
- **FR-003**: A new folder name over 255 UTF-16 units MUST be refused before any creation attempt
  with "Cannot finish operation because of too long name."; the dialog comes back.
- **FR-004**: Every other case (short names, absolute paths, invalid names, existing folders,
  plug-in file systems, archives) MUST behave as before - except that FR-003 applies to every
  typed form (a typed absolute path ending in a name over 255 units now says "too long name"
  where Windows answered "invalid name").
- **FR-005**: No new UI string; a path or name is never cut.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe goes from 8 PASS / 4 FAIL (before) to all rows PASS (after); the rows
  REL, CJK, U255 change from refusal to creation, U256 from the wrong to the right reason.
- **SC-002**: The control rows SHORT and LIMIT pass before and after.

## Assumptions

- Assumption (autonomous run): "the program's limit" is the path limit Create Directory already
  uses for its buffer and its later steps (feature 027); a path between the Windows limit of
  32,767 UTF-16 units and that limit keeps the system's answer from the creation step, as a
  typed absolute path already does - unchanged by this feature.
- Assumption (autonomous run): the other callers listed above are not the same defect and stay
  unchanged.
