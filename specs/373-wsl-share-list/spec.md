# Feature Specification: A WSL server path offers its distributions as the share list

**Feature Branch**: `373-wsl-share-list`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item wsl-localhost-offers-no-share-list (backlog/items/wsl-localhost-offers-no-share-list/desc.md) - implement exactly what it describes." From backlog item wsl-localhost-offers-no-share-list.

## Background

Feature 125 made a server path without a share (`\\server`, `\\server\`) in Change Directory
offer the server's shared folders as a menu; feature 284 sends the way up from a share's root
(`..`, Backspace) to the same menu. The list is read in two ways: first the SMB question
("which folders does this server share"), and only when that is *refused* the second way,
the list the computer's network providers give. When the first way answers "network path not
found" (error 53) the second way is never tried, to avoid a second network timeout for a
server that does not exist.

WSL (`\\wsl.localhost`, the older alias `\\wsl$`) is not an SMB server: the first way always
answers 53, so the user sees an error instead of the list of distributions that File Explorer
shows. The network provider of WSL answers the second way at once with the distributions.

Measured at `5b62b037` (Debug x64; the calls themselves from a PowerShell script, and a
hidden-desktop probe of the program, real route, no seam):

| Path typed | First way (SMB) | Second way (providers) | The program shows |
|---|---|---|---|
| `\\wsl.localhost` | 53 in 1-17 ms | docker-desktop, Ubuntu in 1-7 ms | error (53) |
| `\\wsl$` | 53 | the same two | error (53) |
| Backspace at `\\wsl.localhost\Ubuntu` | 53 | the same two | error (53) for `\\wsl.localhost\` |
| `\\localhost` (local Server service) | the shares | - | the list (works) |
| a name that does not exist | 53 after 1.3 s | 1203 in 0-1 ms *after* the first way | error (53) after 1.3 s |
| `\\192.0.2.1` (never answers) | 53 after 21 s | 1203 in 0-6 ms *after* the first way | error (53) after 21 s |

Asked *first* (cold), the second way waits the same network timeout as the first (21 s for an
address that never answers, 2.7 s for a missing name); asked *right after* the first way
failed, it answers within a few milliseconds for every missing server tried (five addresses
and names, including the gateway that has no SMB). So the second way stays the second
question and adds no second timeout.

## Clarifications

### Session 2026-11-01

- Q: Which errors of the first way lead to the second way? → A: "Network path not found" (53) - the one measured for WSL - in addition to the refusals that lead there today; "network unreachable" (1231), "host unreachable" (1232) and "the remote computer is not available" (51) keep today's behaviour (one error, no second question) (autonomous run: conservative - the item names 53 and only "possibly" 51; 51 was never measured, and the other two say the network itself does not reach the name).
- Q: When both ways fail for a server, which error does the box show - the first way's (53) or the second way's (1203)? → A: The first way's, 53 - the box the user sees today, word for word (autonomous run: item - "a server that really does not exist still shows one error"; the existing rule of 125 for refused lists already reports the first error).
- Q: For `\\wsl$` the providers return `\\wsl.localhost\<distro>`; which server does the opened path use? → A: The server the user typed (`\\wsl$\<distro>`); the share name is the part after the last backslash, as the second way of 125 already does (autonomous run: conservative - no change to how the path is built).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - `\\wsl.localhost` offers the distributions (Priority: P1)

A user types `\\wsl.localhost` (or `\\wsl.localhost\`) in Change Directory, sees the list of
the WSL distributions in the share menu of feature 125 and picks one; the panel opens
`\\wsl.localhost\<distribution>`.

**Why this priority**: it is the defect the item names.

**Independent Test**: on a computer with WSL and at least one distribution, Change Directory
`\\wsl.localhost` opens the menu with the distributions; picking one opens it in the panel.

**Acceptance Scenarios**:

1. **Given** WSL with distributions, **When** the user enters `\\wsl.localhost`, **Then** the
   share menu lists the distributions and no error appears.
2. **Given** the menu, **When** the user picks a distribution, **Then** the panel shows
   `\\wsl.localhost\<distribution>`.
3. **Given** WSL, **When** the user enters `\\wsl.localhost\`, **Then** the same.

---

### User Story 2 - The older alias and the way up (Priority: P2)

`\\wsl$` offers the same list (and opens `\\wsl$\<distribution>`); Backspace (or `..`) in
the root of `\\wsl.localhost\<distribution>` offers the list as for any share's root
(feature 284).

**Independent Test**: Change Directory `\\wsl$`; Backspace at `\\wsl.localhost\Ubuntu`.

**Acceptance Scenarios**:

1. **Given** WSL, **When** the user enters `\\wsl$` and picks a distribution, **Then** the
   panel shows `\\wsl$\<distribution>`.
2. **Given** the panel at `\\wsl.localhost\<distribution>`, **When** the user presses
   Backspace, **Then** the menu lists the distributions; Esc leaves the panel where it was.

---

### User Story 3 - A server that does not exist still ends in one error, not later (Priority: P1)

A user mistypes a server name or names a computer that is off. The program shows the same
single error as today, after the same wait as today.

**Independent Test**: Change Directory `\\<name that does not exist>` and `\\192.0.2.1`; one
error box each, with the same error as today, the time to it measured before and after.

**Acceptance Scenarios**:

1. **Given** a name that does not exist, **When** the user enters `\\<name>`, **Then** one
   error box naming the path with error 53, no menu, the panel stays.
2. **Given** an address that never answers, **When** the user enters it, **Then** one error
   box after about one network timeout (not two), no menu, the panel stays.
3. **Given** an SMB server that answers (`\\localhost`), **Then** its list as today.

### Edge Cases

- The second way answers with nothing (a provider claims the name but has no disk
  containers): the first error (53) is shown, as today - an empty answer does not become "no
  shared folder".
- The second way fails too (1203, as measured for missing servers): the first error (53) is
  shown - the user sees exactly today's message.
- The second way returns entries whose remote name has another server part (for `\\wsl$` it
  returns `\\wsl.localhost\<distro>`): the share name is the part after the last backslash,
  and the opened path is built from the server the user typed (`\\wsl$\<distro>`), as the
  second way already does for refused lists.
- The user gives up waiting (Esc / Close of the wait window): unchanged (the job runs on its
  worker thread; feature 125/193).
- A sign-in-class refusal (feature 285) is unchanged: it is not error 53.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: When the SMB share question for `\\server` fails with "network path not found"
  (53) and gave no share, the program MUST ask the network providers for the server's disk
  containers (the second way of feature 125) before deciding what to show.
- **FR-002**: When that second answer holds at least one folder, the program MUST offer it as
  the share list (sorted, hidden-share rules and never-cut rules of 125 unchanged).
- **FR-003**: When the second way fails or holds no folder, the program MUST show the first
  error (53), exactly as today.
- **FR-004**: Errors 51, 1231 and 1232 of the first way MUST keep today's behaviour (the error,
  no second question); every other error keeps today's route (refusals go to the second way
  as they do now).
- **FR-005**: The second way MUST stay the second question, asked after the first one failed,
  never before it or in parallel (it costs a full network timeout when asked first).
- **FR-006**: The decision which first-way error leads to the second way, and which error is
  shown in the end, MUST be a pure rule in `src/common/saluncserver.h` with saltests checks.
- **FR-007**: The way up of feature 284 and the sign-in of feature 285 MUST keep working (they
  use the same list).

### Key Entities

- **Share list answer**: the folders found, and the error to show when none (the first way's
  error when both ways fail).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On the measuring computer, `\\wsl.localhost`, `\\wsl.localhost\`, `\\wsl$` and
  Backspace at `\\wsl.localhost\Ubuntu` open the menu with the distributions (probe rows W1-W4
  PASS; before: three of four ended in error 53).
- **SC-002**: A name that does not exist and an address that never answers still end in one
  error 53 box; the time to it stays within 2 s of the time measured before (1.3 s and 21 s),
  never near two timeouts (probe rows N1, U1).
- **SC-003**: `\\localhost` still offers its SMB list (probe row C1).
- **SC-004**: saltests count grows by the checks of the new rule, 0 failed.

## Assumptions

- Assumption (autonomous run): the measured "second way answers at once after the first way
  failed" holds because Windows remembers the failed name for a while; it was measured for five
  missing servers on one computer with the WebDAV client stopped. With the WebDAV client running,
  the provider order may make the second question slower for some names; the wait stays on the
  worker thread behind the wait window with Esc / Close (feature 125), so the user is never held
  without a way out. A measurement with the WebDAV client running is not part of this feature.
- Assumption (autonomous run): `PRIVACY.md` stays unchanged - it says the program asks the
  server "through Windows" for its shared folders; the change uses the existing second route of
  feature 125 (already used for refused lists) for one more answer, no new kind of
  communication and no new address.
- No new UI string: the menu and the errors are those of feature 125.
- Other non-SMB providers (WebDAV, third-party) benefit when they answer the same way; only WSL
  is measured.
