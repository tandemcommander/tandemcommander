# Feature Specification: Window titles keep characters outside the code page

**Feature Branch**: `100-cjk-focus-name`
**Created**: 2026-10-03
**Status**: Draft
**Input**: a finding of feature 098's review ("Change Directory to a file with a CJK name: the viewer title shows `f??.txt`"), queued in `specs/NEXT-WORK.md`. Measured first (`research.md`): Change Directory, the focus and the file opened by F3 are all correct; **only the window title is wrong** - the viewer windows are code-page ("ANSI") windows, and setting their title with the Unicode call stores it through the system code page, so every character outside it becomes `?`.

## Clarifications

### Session 2026-10-03

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: Is it worth fixing - it is display only? → A: **Yes, narrowly.** The title, the taskbar button and Alt+Tab show `?` for every Cyrillic, Greek or CJK name on a Central European Windows (and for emoji anywhere), and two such files in one folder get the same title. The fix is small and local: set the title through the Unicode default window procedure (measured to store the exact text on a code-page window), not by converting the windows to Unicode windows (that would change keyboard and menu handling in five plug-ins).
- Q: Which windows? → A: Every place that sets a window title from a file or path name on a code-page window: the Code Viewer, the internal viewer, the Markdown Viewer, PictView, the Database Viewer, the File Comparator, and the main window's title. One helper in the core, a header-only copy for plug-ins; no plug-in interface change.
- Q: The main window's "title unchanged?" check? → A: It reads the title back to avoid redundant updates; reading through the code page gives `?` and would make it re-set the title on every call - it must read the stored Unicode text.
- Q: Threads? → A: The helper is called from the window's own thread; the File Comparator's worker-thread site is checked and, if it sets the title from another thread, routed to the window's thread or left with a note.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A viewer shows the real file name in its title (Priority: P2)

**Independent Test**: files named with U+0159 (in the code page), U+65E5, U+4E2D, U+0416 and an emoji; F3 on each; the stored title (`InternalGetWindowText`) contains the exact name. The same for the other viewers that can open the file type, and for the main window title in a folder with such a name.

**Acceptance Scenarios**:
1. **Given** a file whose name has characters outside the code page, **When** it is viewed, **Then** the viewer's title shows the name exactly.
2. **Given** a name inside the code page or ASCII, **Then** the title is exactly as before.
3. **Given** the main window in such a folder, **Then** its title shows the folder name exactly and is not re-set when nothing changed.

## Requirements *(mandatory)*

- **FR-001**: Window titles set from file or path names MUST store the exact Unicode text, also on code-page windows.
- **FR-002**: Titles of names inside the code page MUST be unchanged; no change of keyboard, menu or other window behaviour.
- **FR-003**: No new strings; no plug-in interface change.

## Success Criteria *(mandatory)*

- **SC-001**: For the five test names, every probed viewer title holds the exact name (before: `?` for the four outside the code page).
- **SC-002**: Debug and Release builds, unit tests, the strict guard and the probes of 093 and 095-099 pass.
