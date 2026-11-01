# Feature Specification: Switching back to the program never waits for a slow panel folder

**Feature Branch**: `372-wsl-activation-freeze`
**Created**: 2026-11-01
**Status**: Draft
**Input**: User description: "Backlog item switching-back-to-tandem-commander-freezes-it-briefly-while - implement exactly what it describes." From backlog item switching-back-to-tandem-commander-freezes-it-briefly-while.

## Background

A user keeps a panel on a WSL folder (`\\wsl.localhost\Ubuntu`). Every time they switch to
another window and back, the program stops responding for a moment and shows the busy cursor.

Measured at `50c47081` (Debug x64, hidden-desktop probe that deactivates and re-activates the
program the way Windows does and pings its main window every 2 ms):

| Left panel | Block 1 (starts +15 ms) | Block 2 (starts +218 ms) | Blocked per activation |
|---|---|---|---|
| local folder, 800 files (control) | 140 ms | - | 140 ms |
| `\\wsl.localhost\Ubuntu\` (71 entries) | 140 ms | 392-408 ms | ~535 ms |
| `\\wsl.localhost\Ubuntu\usr\bin` (827 entries) | 140 ms | 408-410 ms | ~550 ms |

Same on 5 of 5 activations. The WSL path is a network path for Windows (drive type "remote"),
its file system (9P) offers no change notification, so the program cannot refresh it
automatically and re-reads it on every activation. The basic file-system calls on that path
take about 1 ms while the distribution runs; a stopped distribution needs about 2 s for its
first answer. The second block does not grow with the number of entries (71 vs 827), so it is
a fixed cost of the refresh, not the listing.

## Clarifications

### Session 2026-11-01

- Q: The refresh of a folder without automatic refresh waits 400 ms and lists the folder a second time, to notice a folder that is being deleted; should the deferred replacement list the folder again or only check that it still exists? → A: Only check, in the background, after 400 ms; when the folder is no longer accessible, the normal refresh runs (it leaves the folder as before); when it is accessible, nothing more happens (autonomous run: recommended - the second listing found only a folder being deleted, a background check finds the same without making the window wait, and a refresh loop is impossible).
- Q: Does the background route apply only to WSL folders or to every network folder? → A: Every network folder (UNC path or remote drive); WSL folders are network folders for Windows (autonomous run: item - "and any slow network share").
- Q: May the refresh itself still show the busy cursor while it lists the folder? → A: Yes, only for the time it actually lists (a few milliseconds on a warm WSL folder), as every refresh in the program does; the activation and the check never show it (autonomous run: conservative - the listing stays on the UI thread, Assumptions).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Switching back stays responsive with a WSL folder in a panel (Priority: P1)

A user with `\\wsl.localhost\<distro>\...` in a panel switches to another program and back
(Alt+Tab, a click on the taskbar, a click into the window). The window answers at once: no busy
cursor, keys and clicks are handled immediately. The panel still shows the current content of
the folder shortly afterwards.

**Why this priority**: it is the reported defect; it happens on every activation.

**Independent Test**: the activation probe with the WSL rows: the longest time the main window
does not answer after an activation, before and after the fix.

**Acceptance Scenarios**:

1. **Given** a panel on `\\wsl.localhost\Ubuntu\`, **When** the program is deactivated and
   activated again, **Then** the WSL folder adds no wait: after the block every activation pays
   (SC-003) the main window answers within 50 ms at every moment of the 1.5 s after the
   activation (it did not answer for ~400 ms before, SC-001).
2. **Given** a panel on a WSL folder and a file created in that folder from WSL while the
   program was inactive, **When** the program is activated, **Then** the new file appears in the
   panel without any user action (as it does today).
3. **Given** a panel on a WSL folder that no longer exists (deleted from WSL meanwhile), **When**
   the program is activated, **Then** the panel leaves the folder the same way it does today
   (to the nearest existing parent or the rescue path), and the window stays responsive while the
   check runs.

---

### User Story 2 - The same for other slow network folders (Priority: P2)

A panel on a network share (UNC path or mapped network drive) that answers slowly behaves the
same: the activation never waits for the share on the UI thread before the window is
responsive.

**Why this priority**: the item asks for "any slow network share"; the mechanism is the same.

**Independent Test**: the activation probe on a local share (`\\localhost\<share>`) when one is
available; otherwise by code review of the shared path (network folders take one route).

**Acceptance Scenarios**:

1. **Given** a panel on a network folder, **When** the program is activated, **Then** the panel
   is checked and refreshed as before, but not before the window answers again.

---

### User Story 3 - Local folders are not slowed down by the change (Priority: P3)

A local folder in both panels: activation behaves as before or better.

**Independent Test**: the probe's LOCAL control row.

**Acceptance Scenarios**:

1. **Given** local folders in both panels, **When** the program is activated, **Then** the
   longest wait is not longer than before (140 ms measured) and the panels show the same content
   as before.

### Edge Cases

- The WSL distribution is stopped: its first answer takes about 2 s. The activation must not
  wait for it; the refresh happens when the answer comes.
- The user starts an action (changes the folder, opens a file) before the background check of
  the activation has finished: the user's action wins; a late result of the activation check
  must not change the panel to another folder or re-read a folder the panel no longer shows.
- The user deactivates and activates the program several times quickly: at most one check of a
  panel runs at a time; the activations meanwhile are served by its result (one refresh).
- The folder became unreachable (share disconnected, distribution unregistered): the existing
  error handling (message, rescue path) still happens, but only after the window is responsive,
  and only for the folder the panel still shows.
- The configuration "do not refresh network drives on activation"
  (`DrvSpecRemoteDoNotRefreshOnAct`) is on: unchanged - no check and no refresh.
- A panel shows an archive on a network folder: as for the folder itself.
- The program is minimized when activated: unchanged (the existing delayed timer).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Activating the program MUST NOT run the accessibility check of a network panel
  folder (UNC path or remote drive, which includes `\\wsl.localhost\...` and `\\wsl$\...`) on
  the UI thread in a way that blocks the message loop; the check runs in the background.
- **FR-002**: Activating the program MUST NOT show the busy cursor while the accessibility check
  of a network panel folder runs; the refresh shows it only while it actually lists the folder.
- **FR-003**: The refresh that activation triggers for a network folder MUST NOT block the
  message loop for longer than 50 ms on a warm WSL folder (SC-001). The fixed 400 ms wait of a
  refresh of a folder without automatic refresh MUST NOT happen on the UI thread: it becomes a
  background check of the folder 400 ms after the refresh; only when the folder is no longer
  accessible does the panel refresh again (which leaves the folder as before).
- **FR-004**: The panel content of a network folder MUST still be brought up to date after
  activation, as today (new, changed and removed entries become visible without user action).
- **FR-005**: When the background check finds the folder inaccessible, the program MUST react as
  it does today for that case (the same messages and the same rescue path), on the UI thread,
  and only when the panel still shows the folder that was checked and no newer path change
  happened.
- **FR-006**: At most one background check of a panel runs at a time; a request while one runs
  is served by its result. A result MUST be dropped when the panel's path or panel type changed
  since the check started; a check still wanted then starts again on the panel's current folder.
- **FR-007**: Local folders, archives on local disks, and plug-in file systems MUST keep their
  activation behaviour (no change in what is checked or refreshed).
- **FR-008**: `DrvSpecRemoteDoNotRefreshOnAct` MUST keep its meaning (no check, no refresh on
  activation for network folders).
- **FR-009**: Any decision that can be stated without the GUI (which panel paths take the
  background route, when a result is still valid) MUST be a pure rule under `src/common/` with
  `saltests` checks.

### Key Entities

- **Background check**: one accessibility check of one panel's folder, started by an activation
  or by the deferred verification of a refresh; it carries the panel, the folder it checked and
  the panel type; its result is applied only if it still matches the panel.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With `\\wsl.localhost\<distro>\` or `...\usr\bin` in the left panel, every time the
  main window does not answer that starts later than 100 ms after an activation (after the block
  every activation pays, SC-003) is under 50 ms, on 5 of 5 activations, compared with 392-411 ms
  starting at +218 ms before.
- **SC-002**: A file created in the WSL folder while the program is inactive is shown in the
  panel within 2 s after the activation.
- **SC-003**: The LOCAL control's longest wait after activation is not longer than before (140 ms
  at `50c47081`); the WSL rows' longest wait is not longer than the LOCAL row's plus 20 ms.
- **SC-004**: A WSL folder deleted while the program is inactive is left after activation (the
  panel shows an existing folder) within 3 s, and the window answers within 50 ms meanwhile
  except for the moment the panel changes its folder.

## Assumptions

- Assumption (autonomous run): the ~140 ms block that every activation pays, with local folders
  too, is measured and its cause recorded; it is in scope only as far as it waits for the file
  system of a panel folder (the item: "switching back to the window must never make the program
  wait for the file system"). Work it needs beyond that becomes an Inbox item.
- Assumption (autonomous run): "network folder" is the program's existing notion
  (`GetNetworkDrive()`, drive type remote); WSL paths fall in it (measured: drive type 4 =
  remote).
- Assumption (autonomous run): the listing itself (reading the folder) stays on the UI thread as
  in the rest of the program; it took 1-12 ms on WSL. Moving every folder listing off the UI
  thread is a different, larger change.
- The busy cursor of another process cannot be read on the hidden desktop; that row of the probe
  is NOT DRIVEN and the visual check is owed to a person.
- A cold WSL distribution (2 s first answer) cannot be produced reliably inside a probe without
  stopping the user's distribution; the probe measures a warm one, the cold case is covered by
  the design (the check runs in the background) and a person's check.
