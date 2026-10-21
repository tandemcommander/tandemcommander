# Feature Specification: A server's share list that needs a password offers the sign-in

**Feature Branch**: `285-share-list-sign-in`
**Created**: 2026-10-21
**Status**: Draft
**Input**: Backlog item share-list-offers-sign-in (backlog/items/share-list-offers-sign-in/desc.md) - implement exactly what it describes.

## Background

Since feature 125, opening `\\server\` without a Network plug-in (none ships: `nethood=off`) asks
the server for its shares and offers them in a list under the directory line; since feature 284
the way up from a share's root (`..`, Backspace, *Go to root*) takes the same route. When the
server wants a name and password before it gives the list, the route shows only the Windows error
("Path: \\server\ Error: (5) Access is denied.") and stops. A full path `\\server\share` in the
same situation offers Windows' sign-in dialog and, after a successful sign-in, opens the share.

Measured at eb173f7f (hidden-desktop probe `signin_probe.ps1`, Debug build, no `nethood.spl`,
the share-list seam of 125 answering "refused, error 5"): Change Directory `\\localhost\` (row A1)
and Backspace in `\\localhost\C$` (row A2) each show one error box "(5) Access is denied" and no
sign-in. Controls: a server that is not found (53, row N1) shows its error; a list given at once
(row R1) opens and its choice is opened.

## Clarifications

### Session 2026-10-21

- Q: Which refusals of the share list offer the sign-in? → A: exactly the ones for which a full `\\server\share` path offers it - the "logon failure" class of the core (access denied, logon failure, a password that expired or must change, an account restriction, a bad user name, an extended network error, ...); a server that is not found, unreachable, or any other error shows the error as before (autonomous run: item - "the same sign-in as a `\\server\share` path")
- Q: What is the sign-in? → A: Windows' own dialog for a name and password, as the full share path uses on Windows 7 and later; the program types, keeps and shows no name or password itself (autonomous run: item; rule - nothing new stored, `PRIVACY.md` "Passwords for network drives are entered in a Windows dialog")
- Q: What happens when the user cancels the sign-in? → A: the same as Esc in the share list: no message; from Change Directory the dialog opens again with the text, from the way up the panel stays (autonomous run: conservative - the existing "cancelled" outcome of the route)
- Q: What when the sign-in fails? → A: the message the full share path shows for the same failure (another user's connection to the server, the network provider's text, or the Windows error), then the route ends as after an error (autonomous run: item - "the same sign-in")
- Q: After a successful sign-in the list is refused again - offer the sign-in again? → A: no - the sign-in is offered once per opening; the second refusal shows the error as before (autonomous run: conservative - never a loop of dialogs; the full share path also tries the interactive sign-in once)
- Q: Is the connection made by the sign-in remembered? → A: it lasts for the Windows session like the one a full share path makes; it is not made a remembered (persistent) connection (autonomous run: item - the share path's sign-in for an unmapped path does not remember it)
- Q: Should the sign-in reuse the existing `RestoreNetworkConnection` code? → A: no - it is code-page (ANSI) and would convert the server name through the code page; the sign-in passes the server name to Windows in full Unicode (autonomous run: item *Notes*; rule - names are UTF-8 / never through an `A` API)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Signing in to a server opens its share list (Priority: P1)

A user types `\\server\` into Change Directory. The server wants a name and password before it
lists its shares. Windows' sign-in dialog appears; the user signs in; the share list appears; the
user picks a share and is there.

**Why this priority**: the gap the item names.

**Independent Test**: probe row A1 (sign-in answered by the Debug seam).

**Acceptance Scenarios**:

1. **Given** no Network plug-in and a server that refuses its share list until the user signs in, **When** the user opens `\\server\` and signs in successfully, **Then** the share list opens; choosing a share opens it; no error message is shown.
2. **Given** the same, **When** the sign-in is offered, **Then** it is offered once, for that server.

---

### User Story 2 - The way up from a share's root signs in the same way (Priority: P2)

In `\\server\share` the user presses Backspace (feature 284); the server refuses the list; the
same sign-in is offered and then the list.

**Why this priority**: the same route; it must not differ.

**Independent Test**: probe row A2.

**Acceptance Scenarios**:

1. **Given** a panel in `\\localhost\C$` and a refused list, **When** the user presses Backspace and signs in, **Then** the list opens; choosing `D$` opens `\\localhost\D$`.

---

### User Story 3 - Cancelling or failing the sign-in (Priority: P3)

The user cancels the dialog, or the sign-in fails.

**Why this priority**: the other outcomes of the dialog; they must leave the program where it was.

**Independent Test**: probe rows C1, F1, W1, K1.

**Acceptance Scenarios**:

1. **Given** a refused list, **When** the user cancels the sign-in, **Then** no message is shown and nothing changes (Change Directory opens again with the text).
2. **Given** a refused list, **When** the sign-in fails with a bad name or password, **Then** one message with the Windows error is shown and nothing changes.
3. **Given** a refused list, **When** the sign-in meets a connection to that server under another user name, **Then** the core's "Multiple connections to a server ..." message is shown and nothing changes.
4. **Given** a sign-in that succeeds while the list stays refused, **When** the route continues, **Then** the list's error is shown once and no second sign-in is offered.

### Edge Cases

- A server that is not found or not reachable: its error as before, no sign-in.
- A list that is given without a sign-in: unchanged, no sign-in.
- A list refused with an error outside the logon-failure class: the error as before.
- A Network plug-in is loaded: the plug-in route is taken first, unchanged.
- The share list is slow after the sign-in: the wait window of 125 with Esc / Close.
- A server name in another script: passed to Windows whole, in Unicode, never through the code page.
- A server name too long to build the sign-in target: no sign-in is offered (refused, never cut); the error is shown as before.
- The real Windows dialog, its *Remember my credentials* box and Esc in it belong to Windows - checked by a person.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Without a Network plug-in, when the share list of `\\server\` is refused with an error of the logon-failure class the full share path uses, the program MUST offer Windows' sign-in dialog for that server before showing any error.
- **FR-002**: After a successful sign-in the program MUST ask the server for its share list again and offer it as feature 125 does (the same list, wait window, messages).
- **FR-003**: Cancelling the sign-in MUST end the route like Esc in the share list: no message, nothing changes.
- **FR-004**: A failed sign-in MUST show the message the full share path shows for the same result and then end the route like an error.
- **FR-005**: The sign-in MUST be offered at most once per opening of `\\server\`; a refusal after a successful sign-in shows the list's error.
- **FR-006**: Any other result of the share list (given at once, server not found, other errors, no folder share) MUST behave exactly as before; so MUST every route with a Network plug-in.
- **FR-007**: The server name MUST reach Windows whole and in Unicode; a sign-in target that does not fit is refused, never cut.
- **FR-008**: The program MUST NOT type, store or show a name or password itself; the connection lasts for the Windows session and is not made persistent.
- **FR-009**: The decision of the route (list / offer the sign-in / show the error) and the sign-in target MUST be pure rules with unit checks.
- **FR-010**: No new user-interface text (no new strings).

### Key Entities

- **Refused share list**: the server's answer that it gives no list to the current user (a logon-failure class error).
- **Sign-in target**: the server's inter-process share `\\server\IPC$` - the name Windows connects to sign the user in to the server itself.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe, a refused list followed by a successful sign-in opens the share list and the chosen share, with exactly one sign-in to `\\localhost\IPC$` and no message (rows A1, A2 PASS; both showed only the error before).
- **SC-002**: A cancelled, failed or conflicting sign-in and a list refused again after the sign-in each end with the expected single message (none for the cancel) and one sign-in attempt (rows C1, F1, W1, K1 PASS).
- **SC-003**: The controls stay as measured before: a server not found shows its error without a sign-in, a list given at once opens without a sign-in (rows N1, R1 PASS).
- **SC-004**: The unit checks pass (`saltests`, 0 failed), the encoding guard reports 0 findings, the build succeeds.

## Assumptions

- Assumption (autonomous run): the item's *Expected* decides the behaviour (a sign-in like the full share path's); the sign-in is the same kind of network communication the full share path already performs - Windows connects to the server the user opened, with the name and password the user typed into Windows' dialog. Every claim of `PRIVACY.md` stays true ("when you open a network location, Windows connects to it"; "Passwords for network drives are entered in a Windows dialog and are saved only if you choose so there, by Windows"; "The program handles no name or password for it"), so `PRIVACY.md` is not changed by the run; whether the share-list bullet should name the sign-in is left to the maintainer.
- Assumption (autonomous run): the open decision `decide-ship-network-plugin-nethood` does not block this item - its option A names this core addition as a separate item, and FR-006 keeps the plug-in's behaviour.
- Assumption (autonomous run): the sign-in target is `\\server\IPC$` with resource type "any" (the connection Windows uses to authenticate to a server; measured: Windows accepts it and answers like for `\\server`).
- Assumption (autonomous run): the real dialog cannot be shown on the hidden desktop; a Debug-only seam answers the sign-in in the probe, and the real dialog against a real file server is a person's step.
