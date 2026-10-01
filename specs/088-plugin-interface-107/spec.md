# Feature Specification: Plug-in interface 107 — unattended close and path-buffer contract

**Feature Branch**: `088-plugin-interface-107`
**Created**: 2026-10-01
**Status**: Draft
**Input**: `specs/NEXT-WORK.md` item 4 (both entries, as one interface bump): (a) a plug-in-visible "unattended close" so that an update is not declined because a viewer window is open (`specs/080-restart-manager-upgrade/REMAINING-WORK.md` P2); (b) the buffer contract of `GetNextFileNameForViewer` — the header promises `MAX_PATH`, the core writes up to `SAL_MAX_PATH_UTF8`.

## Clarifications

### Session 2026-10-01

The maintainer is away and asked for the recommended option at every decision; each is recorded here.

- Q: How does the program learn that a plug-in window may be closed without a question? → A: **The plug-in declares it per window** (a new interface method). The program's "may I close?" decision must stay free of side effects, so it cannot ask the window; a declaration made in advance can simply be read.
- Q: Which plug-ins declare their windows? → A: **The four viewer plug-ins that ship** — Code Viewer, Markdown Viewer, PictView, Database Viewer. Their windows hold nothing that can be lost. Windows of other plug-ins (File Comparator, Batch Renamer, Disk Map, …) keep declining the update, as today.
- Q: What does a plug-in built for an older interface get from the "next / previous file for a viewer" service when the name does not fit the buffer size the old header promised? → A: **The name is not delivered** (reported as "no further file"), instead of overflowing the plug-in's buffer. Plug-ins built for interface 107 get every name.
- Q: Does the product version change? → A: **No.** The interface version changes (106 → 107); the product version changes only with a release.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — An update goes through while a viewer window is open (Priority: P1)

A user has pressed F3 on a file and left the viewer window open, then went away. A package manager (or the installer) updates Tandem Commander. Today the program declines, the update fails, and the user finds the old version still running. With this feature the viewer windows are closed without a question, the program closes, is updated and starts again.

**Why this priority**: the Code Viewer is the default viewer for F3, so "a viewer window is open" is an everyday state, and it is the one remaining reason an unattended update fails.

**Independent Test**: start the program, open one window of each of the four viewers, run the close-request probe of feature 080: the program agrees, closes, and nothing appears on screen.

**Acceptance Scenarios**:

1. **Given** one or more windows of the Code Viewer, the Markdown Viewer, PictView or the Database Viewer are open and nothing else stands in the way, **When** an installer asks the program to close, **Then** the program agrees, closes all those windows without showing anything, and ends.
2. **Given** a viewer window has a dialog of its own open (Find, Go to, Save As, Properties…), **When** an installer asks, **Then** the program declines at once and shows nothing (a dialog is somebody's unfinished input).
3. **Given** a window of another plug-in is open (File Comparator, Batch Renamer…), **When** an installer asks, **Then** the program declines at once, as before.
4. **Given** viewer windows are open, **When** the user exits the program normally (Alt+F4, the menu), **Then** the plug-ins ask *"viewer windows are open, close them?"* exactly as before.
5. **Given** the FTP plug-in has running operations but no window and no path in a panel, **When** an installer's close reaches the plug-in, **Then** no question is shown: the plug-in refuses to unload and the program stays, as it does for every other obstacle.

### User Story 2 — Stepping to the next file with a long path does not corrupt memory (Priority: P1)

A user views a picture or a database file in a folder whose full path is longer than 259 characters and presses Space / Backspace (next / previous file), or merely lets the viewer refresh its toolbar. Today PictView and the Database Viewer receive the long name into a 260-byte buffer: the program writes past it.

**Why this priority**: it is a memory-safety defect in shipped plug-ins, reachable by browsing an ordinary deep folder.

**Independent Test**: a folder with a path over 300 characters holding two pictures and two `.dbf` files; open the first with F3 and step to the next and back: the viewer shows the next file, no crash, no corrupted memory (Debug build's run-time checks stay silent).

**Acceptance Scenarios**:

1. **Given** PictView shows a file in a folder with a path of 300+ characters, **When** the user steps to the next or previous file, **Then** that file is shown.
2. **Given** the same in the Database Viewer, **Then** the next file is shown.
3. **Given** a plug-in built for interface 104–106 with a 260-byte buffer, **When** the next file's full name is 260 bytes or longer, **Then** the service steps over that file and writes nothing beyond what the old header promised.

### User Story 3 — A plug-in author can read the truth in the headers (Priority: P2)

A developer writing a viewer plug-in reads `spl_gen.h` and sizes a buffer from it. The header states the real size, and the constant is available to plug-ins by name; the version history says what 107 added and how an older plug-in behaves.

**Independent Test**: the header comment of every service whose output can exceed the documented size names the right constant; the constant compiles in a plug-in without a core header; the interface contract of this feature lists every addition.

**Acceptance Scenarios**:

1. **Given** the plug-in headers, **When** a plug-in includes them, **Then** `SAL_MAX_PATH_UTF8` is defined and equals the core's value.
2. **Given** a plug-in built against interface 106 (binary), **When** it is loaded into the new program, **Then** it loads and works as before (the additions are at the end of the interface).

### Edge Cases

- A viewer window that is minimised, or full screen without a caption: it is declared like any other and closes.
- A viewer window whose thread is busy and does not close in time: the plug-in reports that it cannot unload; the program stays running and nothing is shown. The close is abandoned at that plug-in: viewer windows of plug-ins asked earlier are already closed, later plug-ins are not asked.
- PictView showing an image that exists only in its window (pasted from the clipboard, scanned, a screen capture): that window is not declared, so the program declines.
- A plug-in declares a window and the window is destroyed: the declaration goes away with the window (no stale entry can make a later window with the same handle pass).
- A plug-in built for 106 that never declares anything: its windows decline the update, as today.
- The Markdown Viewer or Code Viewer window while its engine is still starting: closes like any other (feature 081's close-during-cold-start guard).
- Critical shutdown, sign-out and normal exit are not "unattended close": the new signal is FALSE there.
- A name of exactly 259 bytes fits an old plug-in's buffer; 260 does not.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The plug-in interface MUST offer a way for a plug-in to find out, while it is being unloaded, that the program is closing unattended (an installer's close request), so that it shows no prompt.
- **FR-002**: The plug-in interface MUST offer a way for a plug-in to declare, per top-level window, that the window can be closed without a question and without losing anything, and to withdraw the declaration.
- **FR-003**: The program's decision on an installer's close request MUST treat a declared window like a window the program can account for itself; every other foreign window MUST still decline. The decision MUST remain free of side effects.
- **FR-004**: The Code Viewer, the Markdown Viewer, PictView and the Database Viewer MUST declare their viewer windows, and during an unattended close MUST close them without a prompt. A window that does not close in time MUST make the plug-in refuse to unload, without a prompt.
- **FR-005**: Outside an unattended close, the four plug-ins MUST behave exactly as before (the question on a normal exit, forced close on a critical shutdown).
- **FR-006**: The FTP plug-in MUST NOT show its *"cancel existing operations?"* question during an unattended close; it MUST refuse to unload instead.
- **FR-007**: The services that hand a full file name to a viewer plug-in (next / previous file) MUST document the real buffer size, and the size MUST be available to plug-ins as a named constant in the plug-in headers.
- **FR-008**: Every in-tree plug-in that calls those services MUST pass a buffer of that size (PictView, Database Viewer; also the plug-ins not built by default: Multimedia Viewer, the two demo plug-ins).
- **FR-009**: For a plug-in built for an interface older than 107, those services MUST NOT write a name longer than the size the older header promised; such a file MUST be stepped over (the plug-in gets the next file whose name fits, or "no further file"). *Revised after the review: the first wording stopped at the first long name.*
- **FR-010**: Other services of the plug-in interface whose header promises a smaller buffer than the core can fill MUST have their header corrected in the same change (path-splitting services), and in-tree callers MUST comply.
- **FR-011**: The interface version MUST become 107; plug-ins built for 104–106 MUST keep loading and working unchanged; the additions MUST be documented (header comments, version history, an interface contract) before the code that uses them.
- **FR-012**: The user-facing documentation that tells users to close viewer windows before updating MUST be corrected.

### Key Entities

- **Unattended close**: the state in which the program closes on an installer's request, with nobody at the machine; every prompt is forbidden.
- **Declared window**: a top-level plug-in window its plug-in has declared safe to close unattended.
- **Interface version**: the number a plug-in is built against and the program reports; 107 after this feature.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: With windows of all four viewers open, **100 %** of installer close requests are agreed to and the program ends within the installer's 30-second wait, with **0** windows or prompts shown.
- **SC-002**: With a dialog of a viewer or a window of a non-viewer plug-in open, **100 %** of requests are declined within 1 second, with nothing shown (no regression of feature 080).
- **SC-003**: Stepping to the next and previous file in a folder with a 300+ character path works in all four viewers; **0** writes beyond a buffer.
- **SC-004**: **0** changes in behaviour on a normal exit, a critical shutdown and a sign-out (the same prompts as before, in the same places).
- **SC-005**: A plug-in binary built before this feature loads and passes its smoke test in the new program.
- **SC-006**: Debug and Release builds succeed; the unit tests pass; the plug-in interface diff consists only of additions at the end of the interface, new constants and comments.

## Assumptions

- The Restart Manager protocol and the program's decision rules are those established by feature 080; this feature changes one rule (foreign windows) and nothing else of that protocol.
- The four viewers hold no unsaved state in their windows (PictView's image edits exist only on screen until *Save As*; closing its window never asked to save).
- No third-party plug-in for interface 104–106 is known; the guard of FR-009 exists for correctness of the contract, not for a known binary.
- The update path of a real installer over a real installation remains a step for a person (as in feature 080); the probe that performs the Restart Manager sequence stands in for it.
