# Feature Specification: Code Viewer and Markdown Viewer pages fill the window on every display scaling

**Feature Branch**: `424-webview-dpi-awareness`
**Created**: 2026-11-12
**Status**: Draft
**Input**: User description: "Backlog item remove-indentation-for-text-viewers - implement exactly what it describes (GitHub #29: the text viewer opened by F3 shows the content shifted right a lot and down a little; the same happens in the Markdown Viewer)." From backlog item remove-indentation-for-text-viewers.

## Measured before the specification (HEAD a44dfdf4)

- The program runs *system DPI aware*: its windows work in one coordinate space, scaled for the
  display scaling that was in effect when the program started.
- The page of both viewers is drawn by a separate browser process. The program starts that process
  on the first view of a session (and again after it ended or crashed), and the process inherits the
  program's DPI mode. It also fixes its own scaling **at its own start**. Probe `dpi29_probe.ps1`:
  program and browser are both system aware, and the browser's windows are placed inside the viewer
  window across the process boundary.
- If the display scaling changes between the program's start and the browser's start (Settings,
  docking or undocking a laptop, a remote desktop session), the two processes disagree on the
  scaling. The page is then drawn larger and placed away from the client's corner, with its right
  and bottom parts cut off. That is the symptom in issue #29. A published analysis of WebView2
  describes the same mechanism and fixes it with per-monitor DPI awareness.
- Experiment `wv2dpi.exe`: the browser process takes its DPI mode from the DPI mode of the program's
  thread at the moment the viewer engine is created. If that thread is per-monitor aware for that
  moment, the browser runs per-monitor aware too. The browser's scaling then no longer depends on
  when either process started.
- This machine has one monitor at 100 %. The symptom itself was not driven: changing the display
  scaling would disturb the maintainer's desktop.

## Clarifications

### Session 2026-11-12

- Q: Should the dialogs opened from a viewer (Find, Go to line, message boxes) keep the program's DPI mode, or follow the viewer window's? → A: Follow the viewer window. Windows already runs a window's message handling in that window's DPI mode, and dialog templates scale themselves in per-monitor mode. At an unchanged scaling nothing changes. Wrapping each dialog call to keep the old mode would mean more code and two coordinate spaces in one window's thread. (autonomous run: conservative)
- Q: Should the remembered viewer position be converted, so that stored values keep the program's coordinates? → A: No. The value is stored and read by the viewer thread, in its own coordinates. At an unchanged scaling the numbers equal the old ones, the registry layout stays as it is, and an old value on a monitor of another scaling is kept visible by the existing check. (autonomous run: conservative)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The viewer's page fills the window after the display scaling changed (Priority: P1)

A user starts Tandem Commander and later changes the display scaling (or docks a laptop to a
monitor with another scaling, or connects by remote desktop). Then they press F3 on a text file
(Code Viewer) or a Markdown file (Markdown Viewer). The page starts at the top-left corner of the
viewer's client area, fills it, and nothing is cut off at the right or bottom edge. The text has the
size the display scaling asks for.

**Why this priority**: This is the reported defect (GitHub #29). The default F3 viewer for text
files shows its text cut off.

**Independent Test**: Start the program, change the scaling, press F3 on a text file and on a
Markdown file, and compare the page's top-left with the client's top-left. It needs a person (a
scaling change), so it is owed as a manual check. On this machine the probe checks the structural
precondition instead: the browser process and the viewer window run per-monitor aware, so their
coordinates no longer depend on a start-time scaling.

**Acceptance Scenarios**:

1. **Given** the program was started at one display scaling and the scaling was changed afterwards, **When** the user opens a text file with F3, **Then** the Code Viewer's page starts at the client's top-left corner and its right and bottom edges are the client's edges.
2. **Given** the same situation, **When** the user opens a Markdown file, **Then** the Markdown Viewer's page fills the client the same way.
3. **Given** the scaling never changed (one monitor, 100 %), **When** the user opens either viewer, **Then** the viewer looks and behaves exactly as before: same window position and size, same status bar, same page.

---

### User Story 2 - The viewer on a monitor with another DPI, and moved between monitors (Priority: P2)

A user with two monitors at different scaling opens a viewer on either monitor, or moves an open
viewer from one monitor to the other. The page always fills the client area, is drawn sharp at that
monitor's scaling, and the status bar keeps a height that fits its text.

**Why this priority**: The item names this setup as a likely trigger. Today the viewer is
bitmap-stretched there (blurry) and is exposed to the same mismatch.

**Independent Test**: A person with two monitors at different scaling (manual check). This machine
checks that the viewer reacts to a DPI change message by keeping its page and status bar laid out
within the client.

**Acceptance Scenarios**:

1. **Given** two monitors with different scaling, **When** the user moves an open viewer to the other monitor, **Then** the window takes the size Windows suggests for the new scaling, the page fills the client, and the status bar text is not clipped.
2. **Given** the main window is on the second monitor, **When** the user presses F3, **Then** the viewer opens on that monitor at the position the program asks for, and its page fills the client.

---

### Edge Cases

- A second instance of an older version (0.3.0 or earlier) uses the same browser data folder at
  the same time and has already started the browser in the old DPI mode. The newer instance's
  viewer engine then fails to start (measured: the controller fails with `ERROR_INVALID_STATE`, in
  both orders). The viewer then reports the engine as unavailable, as it
  already does for other environment mismatches (feature 085), and nothing is lost.
- A window position remembered by an earlier version ("save position") is read as before. On a
  monitor at the scaling of the program's start it means the same place. Elsewhere it is kept
  visible on a monitor (the existing check).
- Dialogs opened from a viewer (Find, Go to line, the first-run hint) follow the viewer window's
  scaling. Below the viewer windows the rest of the program keeps its DPI mode.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The browser process that draws both viewers' pages MUST be started per-monitor DPI aware, whichever viewer or background preparation starts it first. Its scaling MUST NOT depend on the display scaling at the program's start or at its own start.
- **FR-002**: The Code Viewer and Markdown Viewer windows MUST run per-monitor DPI aware, so that the page's placement and the window share one coordinate space on every monitor.
- **FR-003**: When a viewer window gets a new DPI (moved to another monitor, the scaling changed), it MUST take the size Windows suggests and lay out its page and status bar again. The status bar's font and height MUST follow the new DPI.
- **FR-004**: The position and size the program asks a viewer to open at (given in the program's own coordinates) MUST be converted to the viewer's coordinates. With the same scaling on every monitor as at the program's start, the conversion MUST leave them unchanged.
- **FR-005**: The rest of the program (main window, panels, other plug-ins, dialogs not opened by these viewers) MUST keep its current DPI behaviour.
- **FR-006**: With an unchanged scaling equal to the program's start scaling, both viewers MUST look and behave as before (window rectangle, client size, status bar height, page size and content).
- **FR-007**: The change MUST stay inside the shared WebView2 host (one host, never copied, `architecture/11-webview2-integration.md`) and the two viewers' window code. No plug-in interface change, no new UI strings, nothing new stored.
- **FR-008**: The remembered viewer position ("save position") MUST keep its stored format and meaning at an unchanged scaling. It is not converted (Clarifications).

### Key Entities

- **Viewer window**: a Code Viewer or Markdown Viewer top-level window, its own thread, a status bar (Code Viewer) and the page.
- **Browser process**: the shared process tree that draws every viewer page of the session (one per browser data folder).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: After a display-scaling change made while the program runs, the page of either viewer starts at the client's top-left corner within 1 pixel, and neither the right nor the bottom edge is cut off (manual check, owed to a person).
- **SC-002**: The probe shows the browser process and both viewer windows in per-monitor DPI mode (before: system mode), and the main window unchanged (system mode).
- **SC-003**: At an unchanged 100 % scaling, both viewers' window rectangles, client sizes and status bar heights are equal to the measurements before the change.
- **SC-004**: The rule that converts a requested viewer rectangle between coordinate spaces passes its unit checks, including the identity case and two scaled cases.

## Assumptions

- Assumption (autonomous run): the trigger of #29 is a mismatch between the program's and the browser's start-time scaling (or a monitor of another DPI). It was measured structurally on this machine (DPI modes, the experiment), not by changing the display. Confirming it on screen is a manual check before the next release (stop-rules rule 9).
- Assumption (autonomous run): Microsoft's recommended DPI mode for WebView2 hosts, per-monitor v2, is applied only to the viewer windows and the creation of the shared viewer engine. Switching the whole program is out of scope (constitution III, incremental modernization).
- Assumption (autonomous run): The dark-theme menu bar of the viewers keeps its font sized for the program's start scaling on a monitor of another DPI. That is cosmetic, and only on a mismatched monitor where today the whole window is bitmap-stretched. It is recorded as a limit.
- The Windows 11 baseline (constitution IV) provides every per-monitor API used. No fallback for older systems.
