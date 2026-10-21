# Feature Specification: The parent of a share's root offers the server's shares

**Feature Branch**: `284-share-root-parent`
**Created**: 2026-10-21
**Status**: Draft
**Input**: Backlog item share-root-parent-offers-share-list (backlog/items/share-root-parent-offers-share-list/desc.md) - implement exactly what it describes. From backlog item share-root-parent-offers-share-list.

## Background

Since feature 125, typing `\\server\` into Change Directory without a Network plug-in (none ships:
`nethood=off`) asks the server for its shares and offers them in a list under the directory line;
picking one opens `\\server\share`. The way *up* from a share's root was left out: in the root of
`\\server\share` the panel lists no `..` entry, Backspace (and Ctrl+PgUp, *Parent directory*) does
nothing, and *Go to root* opens the same share root again. With a Network plug-in loaded, all three
go to the plug-in's `net:` panel of the server.

Measured at e35f8588 (hidden-desktop probe `shareroot_probe.ps1`, Debug build, no `nethood.spl`,
at `\\localhost\C$`): Backspace -> the panel stays, no list, no window; *Go to root* -> stays, no
list; Home, Enter -> opens the first folder `$WINDOWS.~BT` (no `..` is listed); *Open in other
panel* on the first item -> the folder. Controls: Backspace / *Go to root* in
`\\localhost\C$\Windows` -> `\\localhost\C$`; Backspace in `C:\` -> stays.

## Clarifications

### Session 2026-10-21

- Q: Should the root of a share list a `..` entry without the plug-in (so that it can be clicked, and Backspace has something to execute)? → A: yes - the item names `..` among the ways up, and it is the entry the panel already lists there when the plug-in is loaded (autonomous run: item)
- Q: What does "offer the server's share list" do exactly - a new list, or the one of Change Directory? → A: exactly what Change Directory does with `\\server\` since 125: the same list, the same wait window, the same messages; picking a share opens it, Esc leaves the panel where it was (autonomous run: item - "as Change Directory to `\\server\` does since 125")
- Q: Opening the `..` of a share's root in the other panel (*Open in other panel*) - what does it open? → A: the other panel offers the server's shares, as it does with the plug-in (there it opens the `net:` panel of the server) (autonomous run: conservative - the plug-in's behaviour mapped to the core's list; otherwise the command would open a path that cannot exist)
- Q: Opening the `..` of a share's root in a new tab (middle click)? → A: unchanged - nothing happens, as now and as with the plug-in (the code says "the UNC-root nethood jump stays a Backspace thing") (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Backspace in a share's root offers the other shares (Priority: P1)

A user is in `\\server\share` and wants another share of the same server. Backspace (or
Ctrl+PgUp, *Parent directory*, Enter or a double click on `..`) shows the server's shares; the
user picks one and is there.

**Why this priority**: the defect the item names; the way up is the common way to change shares.

**Independent Test**: probe rows B1 (Backspace), D1 (Home, Enter: `..` is the first item).

**Acceptance Scenarios**:

1. **Given** a panel in `\\localhost\C$` and no Network plug-in, **When** the user presses Backspace, **Then** the server's share list opens; choosing `D$` opens `\\localhost\D$` with no message.
2. **Given** the same, **When** the user goes to the first item and presses Enter, **Then** the first item is `..` and the share list opens.
3. **Given** the share list is open, **When** the user presses Esc, **Then** the panel stays in `\\localhost\C$` with no message.
4. **Given** the server refuses the list, **When** the user presses Backspace, **Then** the same error message as Change Directory to `\\server\` shows, naming `\\server\`, and the panel stays.

---

### User Story 2 - Go to root in a share's root offers the shares (Priority: P2)

*Go to root* (Ctrl+\ / the command) in a folder of a share goes to the share's root, as before;
in the share's root itself it offers the server's shares.

**Why this priority**: named by the item; less used than Backspace.

**Independent Test**: probe rows G1, S2.

**Acceptance Scenarios**:

1. **Given** a panel in `\\localhost\C$`, **When** the user runs *Go to root*, **Then** the share list opens; choosing `D$` opens `\\localhost\D$`.
2. **Given** a panel in `\\localhost\C$\Windows`, **When** the user runs *Go to root*, **Then** the panel goes to `\\localhost\C$`, no list.

---

### User Story 3 - `..` of a share's root opened in the other panel (Priority: P3)

*Open in other panel* on the `..` of a share's root makes the other panel offer the server's
shares.

**Why this priority**: follows from listing `..`; without it the command would open a path that
does not exist.

**Independent Test**: probe row O1.

**Acceptance Scenarios**:

1. **Given** a panel in `\\localhost\C$` with `..` focused, **When** the user opens it in the other panel (and activates it), **Then** the other panel offers the share list; choosing `D$` opens `\\localhost\D$` in the other panel, the first panel stays in `\\localhost\C$`.

### Edge Cases

- A Network plug-in is loaded: `..`, Backspace, *Go to root* and *Open in other panel* go to its `net:` panel exactly as before (the plug-in route is checked first and left untouched).
- A folder inside a share (`\\server\share\dir`): `..` / Backspace go to the parent folder, *Go to root* to the share's root - unchanged, no list.
- A drive root (`C:\`) and a device path (`\\.\C:\`, `\\?\...`): unchanged - no `..`, Backspace does nothing.
- The server lists no folder share: the message Change Directory shows for `\\server\` ("A share name is missing ..."), the panel stays.
- The server is slow: the wait window of 125 with Esc / Close.
- A share root reached under a name the share list cannot rebuild (a server name too long for the list's buffers): the route of 125 refuses or shows its message; the panel stays - never a cut path.
- The panel's directory line (clicking its parts) is unchanged.
- Middle click on `..` of a share's root (open in a new tab): unchanged, nothing happens.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Without a Network plug-in, the listing of the root of a share (`\\server\share`) MUST include the `..` entry, as it does with the plug-in.
- **FR-002**: Without a Network plug-in, executing that `..` (Enter, double click, Backspace, Ctrl+PgUp, *Parent directory*) MUST offer the server's share list exactly as Change Directory to `\\server\` does (feature 125): picking a share opens it; Esc / cancel leaves the panel where it was; an error shows the same message and leaves the panel.
- **FR-003**: Without a Network plug-in, *Go to root* in the root of a share MUST offer the server's share list the same way; in a folder inside a share it MUST go to the share's root as before.
- **FR-004**: Without a Network plug-in, *Open in other panel* on the `..` of a share's root MUST make the other panel offer the server's share list the same way.
- **FR-005**: With a Network plug-in loaded, every route above MUST behave exactly as before.
- **FR-006**: Every other path (a folder inside a share, a drive root, a device path, an archive, a plug-in file system) MUST behave exactly as before.
- **FR-007**: The decision "is this the root of a share, and which server" MUST be a pure rule with unit checks; the server path it gives is never cut (a name that does not fit is refused - the route then does nothing new).
- **FR-008**: No new user-interface text (no new strings).

### Key Entities

- **Share root**: a disk path `\\server\share` (optionally with a trailing backslash) whose server part is a server name - not `.` or `?` (device prefixes).
- **Server path**: `\\server\` - what Change Directory takes to offer the share list.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the probe, Backspace, *Go to root*, Enter on the first item and *Open in other panel* in `\\localhost\C$` each open the share list, and choosing the second entry opens `\\localhost\D$` with no message (rows B1, G1, D1, O1 PASS; all four were "nothing happens" before).
- **SC-002**: Esc in the list and a refused list leave the panel in `\\localhost\C$` (rows X1, E1 PASS; E1 with exactly one message naming `\\localhost\`).
- **SC-003**: The regression controls stay as measured before (rows S1, S2, L1 PASS).
- **SC-004**: The unit checks of the share-root rule pass (`saltests`, 0 failed), the encoding guard reports 0 findings, the build succeeds.

## Assumptions

- Assumption (autonomous run): the open decision `decide-ship-network-plugin-nethood` does not block this item - its recommended option A (keep the plug-in off) names this core addition as a separate item, and FR-005 keeps the plug-in's behaviour whichever way it is decided.
- Assumption (autonomous run): the routes reuse the Change Directory route of 125 (`\\server\` handed to the panel's path change), so the plug-in check, the wait window, the messages and the never-cut refusals are the same code; no network communication is added beyond what Change Directory to `\\server\` already does (`PRIVACY.md` already covers it, 125).
- Assumption (autonomous run): the behaviour with the plug-in present is verified by code reading (the plug-in route is checked first and not changed); the plug-in is not built in the default configuration and the 125 measurement with it showed a leak at every exit.
- Assumption (autonomous run): picking a share whose name the panel cannot open is handled by 125's route (message, panel stays).
