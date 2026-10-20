# Feature Specification: Remembered network drive reconnects to its exact path

**Feature Branch**: `264-remembered-drive-reconnect`
**Created**: 2026-10-20
**Status**: Draft
**Input**: Backlog item remembered-network-drive-with-a-non-code-page-or-long-path - "Remembered network drive with a non-code-page or long path cannot be reconnected". From backlog item remembered-network-drive-with-a-non-code-page-or-long-path.

## Background (measured at 7bd36b89)

A remembered (persistent) network drive that Windows did not reconnect at logon is shown
in the Change Drive menu and the drive bars as disconnected. Picking it asks Tandem Commander
to reconnect it. The program reads the drive's remembered network path in the system code
page (characters outside it become `?`) and cut at 259 bytes, and hands that text to
Windows. The reconnection fails and the user sees `The path or file name "Z:\" is invalid.`

Reproduced on the current build with the independent test of feature 246
(`specs/246-network-drive-labels/test-independent/itest246_pickcp.ps1`, hidden desktop):
drives `Z:` -> `\\localhost\C$\...\unnamed_<Chinese>_<Cyrillic>` and
`Y:` -> `...\named_<Cyrillic>`, remembered and disconnected; picking each one in the drive
bar handed Windows `...\unnamed_???_?????` / `...\named_?????`, the drive stayed
disconnected and the message above appeared. The 0.1.10 build behaves the same.

## Clarifications

### Session 2026-10-20

- Q: Should the reconnection switch to Windows' "restore this letter from the profile" call, or keep its current two-step shape (background attempt with the Esc wait window, then Windows' credential dialog) with the exact path? → A: Keep the current shape with the exact path; the restore-by-letter call is adopted only if the plan measures that it keeps the Esc wait window, the saved user name and the credential dialog (autonomous run: conservative)
- Q: When the exact remembered path cannot be obtained, may the program fall back to the old code-page path? → A: No - the reconnection is reported as failed; never tried with a shortened or code-page path (autonomous run: rule - a path is never cut, refuse instead)
- Q: Is the panel's recovery for a listed drive whose connection does not answer (it tries the network path itself) part of this feature? → A: Yes - it uses the same remembered path, which the item names (`CheckAndRestoreNetworkConnection`) (autonomous run: item)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Pick a remembered drive whose path has characters outside the code page (Priority: P1)

A user has a remembered network drive mapped to a share or folder whose name holds Cyrillic,
Chinese or other characters the system code page cannot hold. Windows did not reconnect it.
The user picks the drive in the Change Drive menu or on a drive bar.

**Why this priority**: This is the defect of the item; since feature 246 the menu shows such
a path exactly, which invites the pick that then fails.

**Independent Test**: Map a remembered drive to a local administrative share path with
Cyrillic and Chinese folder names, disconnect it (keep it remembered), start the program,
pick the drive on the drive bar: the drive becomes connected and the panel shows its root.

**Acceptance Scenarios**:

1. **Given** a remembered, disconnected drive `Z:` mapped to `\\server\share\Архив_中文档`,
   **When** the user picks `Z:` in the drive bar or the Change Drive menu, **Then** Windows
   is asked to reconnect exactly `\\server\share\Архив_中文档`, the drive becomes connected,
   the panel shows `Z:\` and no error message appears.
2. **Given** the same drive whose server is unreachable, **When** the user picks it,
   **Then** the user sees Windows' text for the real error (for example "network path was
   not found"), not "The path or file name is invalid", and the panel stays where it was.

---

### User Story 2 - Pick a remembered drive with a long path (Priority: P1)

A user has a remembered drive mapped to a deep folder whose network path is longer than
259 characters (bytes in the code page).

**Why this priority**: The same defect: the path was cut, Windows got another path.

**Independent Test**: As story 1, with a remembered path longer than 259 characters, if
Windows accepts such a remembered connection at all (measured in the plan); the
reconnection uses the whole path.

**Acceptance Scenarios**:

1. **Given** a remembered, disconnected drive whose remote path is 259 characters long and
   ends in Cyrillic (longer than 259 bytes in any byte form the program keeps), **When** the
   user picks it, **Then** Windows is asked to reconnect the whole path and the drive
   becomes connected. (Measured, research R1: Windows refuses to create a connection whose
   remote path has 260 or more characters, so no longer remembered path exists.)

---

### User Story 3 - Open a path on a disconnected remembered drive in a panel (Priority: P2)

The user types `Z:\folder` into the command line / Change Directory, or a panel opens a
path on a remembered drive (hot path, history, start-up path) while the drive is
disconnected. The panel's reconnection uses the same chain as the pick.

**Why this priority**: Same defect reached from another user action (the item names it).

**Independent Test**: With the drive of story 1 disconnected, start the program with the
left panel path `Z:\` on the command line: the panel reconnects the drive and lists it.

**Acceptance Scenarios**:

1. **Given** the drive of story 1 disconnected, **When** a panel changes to `Z:\`, **Then**
   the drive is reconnected to its exact path and listed.
2. **Given** a drive that Windows lists but whose connection does not answer (the "letter
   listed" recovery that tries the network path itself), **When** the panel changes to it,
   **Then** the network path tried is the exact remembered path, not its code-page form.

---

### User Story 4 - Credentials and cancelling keep working (Priority: P3)

The reconnection still uses the user name saved with the remembered connection, still
offers Windows' credential dialog when the saved credentials are refused, and the wait
window still lets the user cancel a slow reconnection with Esc.

**Why this priority**: Regression guard named by the item's *Expected*.

**Independent Test**: Code review plus a person step on a machine with a password-protected
share (the hidden desktop has no keyboard and no password-protected server).

**Acceptance Scenarios**:

1. **Given** a remembered drive saved with user name `DOMAIN\user`, **When** it is
   reconnected, **Then** the reconnection is attempted as `DOMAIN\user` first.
2. **Given** the server refuses the saved credentials, **When** the user picks the drive,
   **Then** Windows' credential dialog appears; Cancel leaves the drive disconnected without
   a further error message; correct credentials connect it.
3. **Given** a slow server, **When** the reconnection waits, **Then** the wait window
   "trying to reconnect, press Esc to cancel" appears after its usual delay and Esc cancels.

### Edge Cases

- A remembered path that holds only code-page characters (ASCII, Czech): behaves exactly
  as before (no regression).
- A remembered path that holds unpaired surrogate code units (possible in a share or
  folder name): passed to Windows as it is - the path is never converted through a lossy
  form.
- Windows does not list the letter as remembered any more (removed in the meantime): no
  reconnection is attempted, as before.
- Not enough memory for the path: the reconnection is refused with an error, never tried
  with a shortened path.
- The drive is already connected by the time Windows is asked (another program reconnected
  it): treated as success, the drive list is refreshed, as before.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The remembered network path used to reconnect a drive MUST be obtained from
  Windows in full Unicode and at full length; it MUST never pass through the system code
  page and MUST never be cut.
- **FR-002**: The reconnection MUST hand Windows exactly that path, together with the user
  name and network provider saved with the remembered connection (when the saved path is
  the same path, compared case-insensitively as Windows compares it).
- **FR-003**: Both entry points MUST use the exact path: picking a disconnected remembered
  drive in the Change Drive menu or a drive bar, and a panel's path change to a
  disconnected remembered drive (including the recovery for a listed drive whose connection
  does not answer, which tries the network path itself).
- **FR-004**: The first reconnection attempt MUST keep the cancellable wait window (Esc)
  and MUST not block the user interface; on refused credentials Windows' credential dialog
  MUST be offered as before; the remembered connection is updated in the user's profile
  exactly as before.
- **FR-005**: Error handling MUST stay as before: credential conflict, refused credentials,
  provider-specific (extended) errors and other errors show the same messages; an extended
  error's provider text is shown in full Unicode.
- **FR-006**: When the exact path cannot be obtained (no memory, Windows answers nothing),
  the program MUST NOT fall back to a shortened or code-page path; it reports the failure
  as a failed reconnection.
- **FR-007**: Remembered paths made of code-page characters and shorter than 260 bytes MUST
  behave exactly as before.
- **FR-008**: Out of scope and unchanged: reconnecting a UNC path without a drive letter,
  the Network plug-in's connection requests, the texts of the drive list (backlog
  `drive-list-code-page-texts`).

### Key Entities

- **Remembered connection**: a drive letter, its remote network path, the saved user name
  and the network provider, as Windows keeps them in the user's profile.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the reproduction of the item (two remembered drives with Cyrillic / Chinese
  paths), both drives reconnect on the first pick, with no error message - before: 0 of 2.
- **SC-002**: The reconnection is asked for the exact remembered path in 100 % of the probe
  rows (compared character by character).
- **SC-003**: A remembered path of 259 characters with a Cyrillic tail (the longest Windows
  accepts, research R1) reconnects on the first pick - before: fails.
- **SC-004**: An ASCII remembered drive (negative control) reconnects as before; an
  unreachable server still reports its real error within the same time as before.

## Assumptions

- Assumption (autonomous run): Windows 11 is the only target (constitution); the Windows
  XP / Vista credential branches of the old code are not carried to the new path.
- Assumption (autonomous run): the password dialog with a real password-protected share
  cannot be driven on the hidden desktop; it is owed to a person as a confirmation step.
- Nothing new is stored: the user's profile is updated by Windows exactly as before
  (the same "update profile" request).
