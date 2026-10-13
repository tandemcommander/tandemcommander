# Feature Specification: From a server name to its shared folders

**Feature Branch**: `125-unc-server-shares`
**Created**: 2026-10-13
**Status**: Draft
**Input**: GitHub issue #5 (`issues/issue_5.md`): "Shift+F7, `\\server\`, Enter - expected: the server's shares; actual: *A share name is missing in the path specified*. Proposed: enable the Network plug-in (`nethood=on`)." Target release 0.1.10.

## What was measured before this specification was written

Probe `probe/unc_probe.ps1` on the hidden desktop, the released 0.1.9 against a build of the
same sources with the Network plug-in switched on (`probe/unc_measure_v019.txt`,
`probe/unc_measure_with_nethood_plugin.txt`):

| Typed in Change Directory | 0.1.9 | The same with the Network plug-in |
|---|---|---|
| `\\localhost\`, `\\localhost`, `\\<this computer>\` | error box *A share name is missing in the path specified* - **the report is confirmed** | the panel opens `net:\\<server>` (a list of the server's visible shares) |
| `\\` | error box *A server name is missing...* | the panel opens `net:\` and scans the network |
| `\\<a server that does not exist>\` | the same error box, at once (the program never asks the network) | the panel opens `net:\\<that name>`, empty, no message |
| leaving the program afterwards | clean exit | **the Debug build reports "Detected memory leaks!" at every exit** after the plug-in was used |

The report is valid. Its cause is right: the program hands an incomplete network path only to
a "Network" plug-in, and the shipped set has none.

Its proposed remedy - shipping the Network plug-in - was examined (a read-only audit of the
plug-in and the measurement above; details in `research.md`). The plug-in works for the
reported case, but it has not been maintained through the last hundred features: it ends its
worker threads by force when the program closes (the leaks above), shows nothing for a server
that does not exist, carries the predecessor's product name in its texts, compares names by
rules the rest of the program has abandoned, and it changes more than the reported case (the
parent of every shared folder, the *Network* item of the Change Drive menu). Which plug-ins
ship is a recorded policy of the project (feature 007) and a public claim (`PRIVACY.md`).
**That decision is the maintainer's and is not taken here**; this feature makes the reported
case work without it and records what enabling the plug-in would need.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - I type a server name and get to its shared folders (Priority: P1)

A user in a company network presses Shift+F7, types `\\server\` (or `\\server`) and presses
Enter. Instead of an error, the program reads the shared folders of that server and offers
them as a list under the panel's path line. The user picks one and the panel shows that
folder.

**Why this priority**: it is the reported defect; today the only way on is to know and type a
share name.

**Independent Test**: type `\\<a reachable server>\` in Change Directory; a list of its shared
folders appears; choose one; the panel's path is `\\server\<share>`.

**Acceptance Scenarios**:

1. **Given** a reachable server with shared folders, **When** the user enters `\\server\` in Change Directory, **Then** no error appears and a list of the server's shared folders is offered.
2. **Given** that list, **When** the user chooses a folder, **Then** the panel opens `\\server\<folder>`.
3. **Given** that list, **When** the user closes it without choosing (Esc), **Then** the panel stays where it was and no message appears.
4. **Given** `\\server` without the trailing backslash, **When** entered, **Then** the behaviour is the same.
5. **Given** shared folders hidden by the `$` convention (administrative shares), **When** the list is shown, **Then** visible folders come first and the hidden ones follow, set apart - an administrator can pick `C$` without typing it.

---

### User Story 2 - A server that cannot be read is reported truthfully (Priority: P1)

The user types the name of a server that does not exist, is switched off, or refuses the
question. The program says so - with the reason Windows gives - and the panel stays where it
was. The wait can be cancelled with Esc.

**Why this priority**: the program now asks the network where it used to answer at once; a
mistyped name must not freeze it or end in silence.

**Independent Test**: type `\\<a name that does not exist>\`; a message naming the path and the
Windows error appears within the time Windows needs to give up; Esc during the wait ends it
earlier.

**Acceptance Scenarios**:

1. **Given** a server name that does not exist, **When** entered, **Then** an error message names the path and the reason, and the panel is unchanged.
2. **Given** a slow answer, **When** the wait lasts more than a moment, **Then** a "press Esc to cancel" notice is shown and Esc ends the wait without an error message about the server.
3. **Given** a server with no shared folder to offer, **When** entered, **Then** the user is told that a share name is missing (as today), not shown an empty list.

---

### User Story 3 - Nothing changes where a Network plug-in is present (Priority: P2)

A build or an installation that does have a Network plug-in (a developer's build, a future
release that ships it) keeps handing incomplete network paths to the plug-in, exactly as
before.

**Why this priority**: the new behaviour is the fallback, not a replacement.

**Independent Test**: the same probe on a build with the plug-in: `\\server\` opens `net:\\server`.

**Acceptance Scenarios**:

1. **Given** a loaded Network plug-in, **When** `\\server\` is entered, **Then** the plug-in's panel opens and no list of the core is shown.

---

### Edge Cases

- `\\` alone (no server): stays an error (*a server name is missing*) - the program has no list of servers to offer without the plug-in.
- `\\.\...` and `\\?\...`: not network servers; unchanged.
- Share names with letters of any script, with spaces, or as long as Windows allows: shown and opened exactly.
- A server with hundreds of shares: all are offered (the list scrolls).
- The path arrives from somewhere other than the Change Directory dialog (a hot path, the command line, a path typed in the panel's path line): the same list is offered; when the caller cannot show the dialog again, a cancelled list simply ends the change.
- The program is closed, or an installer asks it to close, while the list is open or the server is being read: the program closes; nothing is left behind.
- The user has no session with the server and the server wants a name and password: the Windows error is shown (signing in to a server is not part of this feature - a full path `\\server\share` already offers it).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the user enters a network path that names a server and no share, and no Network plug-in is present, the program MUST read that server's shared folders and offer them for choosing instead of reporting a missing share name.
- **FR-002**: Choosing a shared folder MUST open it in the panel that the path was entered for; closing the list without a choice MUST leave the panel unchanged and show no error.
- **FR-003**: The list MUST contain the server's folder shares only (no printers, no IPC), visible ones first in alphabetical order, hidden ones (name ending with `$`) after them and set apart.
- **FR-004**: Share names MUST be shown and used exactly as the server reports them (any script; never cut).
- **FR-005**: Reading a server MUST NOT freeze the program: after a short moment a cancellable wait notice MUST appear, and Esc MUST end the wait.
- **FR-006**: A server that cannot be read MUST be reported with the path and the reason given by Windows; the panel MUST stay unchanged.
- **FR-007**: A server with no folder share to offer MUST be reported as a missing share name (the existing message).
- **FR-008**: With a Network plug-in present the behaviour MUST be exactly what it was (the path goes to the plug-in).
- **FR-009**: `\\` without a server name, `\\.\` and `\\?\` paths MUST behave as before.
- **FR-010**: The program MUST still close cleanly (also on an installer's request) while the list is open or a server is being read.
- **FR-011**: The privacy statement MUST say that naming a server makes the program ask that server for its list of shared folders.

### Key Entities

- **Server-only path**: `\\server` or `\\server\` - a server name, no share.
- **Share entry**: name, kind (folder share or other), hidden or visible, the server's remark.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Entering `\\<reachable server>\` leads to a list of its shared folders with zero error messages (today: always an error).
- **SC-002**: From typing the server name to standing in a shared folder takes one choice (today: impossible without knowing the share name).
- **SC-003**: A mistyped server name produces a message with the reason; the program stays responsive and Esc ends the wait.
- **SC-004**: Builds with a Network plug-in behave as before in all probe rows.
- **SC-005**: The program exits with code 0 and no error window after every probe row, including "close while reading".

## Assumptions

- The Network plug-in stays disabled in the default build; enabling it is a product decision for the maintainer. What it would need is listed in `research.md` and carried to `specs/NEXT-WORK.md`.
- The parent of a shared folder's root (`..` in `\\server\share`) stays unavailable without the plug-in; offering the share list there is a possible follow-up, not part of the report.
- Signing in to a server that refuses an anonymous or current-user question is out of scope; the existing sign-in of a full `\\server\share` path is unchanged.
- No new texts: the wait notice, the error format and the "share name is missing" message already exist in all languages.
- The fix is released in 0.1.10.
