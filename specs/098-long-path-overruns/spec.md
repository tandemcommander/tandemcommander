# Feature Specification: Long paths - a crash, two overruns and a silent loss

**Feature Branch**: `098-long-path-overruns`
**Created**: 2026-10-03
**Status**: Draft
**Input**: defects found by the independent review of feature 097 and queued in `specs/NEXT-WORK.md` item 5; the maintainer's standing instruction: serious defects found on the way are fixed one by one. Measured first: `research.md` (every claim driven on the Debug build where it could be).

## Clarifications

### Session 2026-10-03

The maintainer asked for autonomy; the decisions are the author's recommended options.

- Q: What was confirmed? → A: **D1** - navigating into a disk folder whose path is about 7,500 characters long crashes the program (driven: level 41, 7,475 bytes): the directory line stores pixel widths in 16-bit fields. **D2** - typing the full path of a *file* of 260+ bytes into Change Directory overruns a 260-byte stack buffer (driven: the Debug build stops on "Buffer is too small"). **D4** - packing a selection with sub-folders from a folder whose path is 260+ bytes **silently leaves out the contents of those sub-folders**, also with the built-in ZIP and 7z packers (read; the walk cuts its working path to 259 bytes and reports success); and the external packer copies the source folder into a 260-byte buffer without a bound (not reachable without WinRAR). **D3** - the 7zip plug-in formats an error message with an item path into 1,024 bytes without a bound: not reachable today (the listing refuses inner paths over 255 bytes), but its twin in the same plug-in - the window caption built from an ISO image's path into 2,000 bytes - is reachable with an image at a path over about 1,980 bytes.
- Q: Since when? → A: All present in every release; D1, D2 and D4 became reachable when feature 004 made the program long-path capable.
- Q: D4 - refuse or make it work? → A: **Make it work**: the walk's working path holds any length the program handles. A silent loss is not acceptable; where a real limit remains (the external packer's console command line), refuse with the existing "path too long" message before anything is packed.
- Q: The clipboard path paste that cuts at 519 bytes (found next to D2)? → A: Refuse instead of cutting (the existing message), the rule of feature 097.
- Q: User-visible text? → A: No new strings.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deep folders do not crash the program (Priority: P1)

**Independent Test**: the probe walks into a chain of folders past 7,500 characters (and to 20,000+) and back; the program stays alive with no run-time check or crash report.

**Acceptance Scenarios**:
1. **Given** a disk folder whose path is 7,500-32,000 characters long, **When** the panel enters it, **Then** the directory line shows the path and the program stays alive; clicking parts of the path (hot-track) still navigates to the right folder.
2. **Given** a short path, **Then** the directory line behaves exactly as before.

### User Story 2 - Change Directory to a long file path (Priority: P1)

**Acceptance Scenarios**:
1. **Given** the full path of a file of 260+ bytes typed into Change Directory, **Then** the panel goes to the file's folder and focuses the file, with no overrun.
2. **Given** a path pasted from the clipboard as a panel path that does not fit, **Then** "The path specified is too long." is shown and nothing else happens.

### User Story 3 - Packing from a long folder packs everything (Priority: P1)

**Acceptance Scenarios**:
1. **Given** a folder whose path is 260+ bytes holding files and nested sub-folders, **When** they are packed into a ZIP or 7z archive (Alt+F5) or copied into an archive panel, **Then** every file of every sub-folder is in the archive (read back).
2. **Given** an external packer and a source folder of 260+ bytes, **Then** the operation is refused with the message before anything is packed.

### User Story 4 - The 7zip plug-in's message and caption buffers (Priority: P3)

**Acceptance Scenarios**:
1. **Given** an ISO image at a path over 2,000 bytes viewed through the 7zip plug-in, **Then** no overrun; the caption shows the path (shortened if needed).
2. **Given** an error message for an item, **Then** it is built with a bound.

### Edge Cases

- Paths with three-byte characters (pixel and byte lengths differ); exactly 65,535 pixels / characters.
- Packing a selection of several folders; empty sub-folders; a sub-folder at the walk's former limit (259 / 260 bytes).

## Requirements *(mandatory)*

- **FR-001**: The directory line MUST handle a path of any length the program can show, with no 16-bit truncation of positions or widths.
- **FR-002**: Change Directory with a typed file path of any supported length MUST go to the folder and focus the file without an overrun.
- **FR-003**: A path from the clipboard that does not fit MUST be refused with the existing message, never cut.
- **FR-004**: The directory walk used to pack a selection MUST NOT cut its working path; every file is packed or the operation is refused before it starts.
- **FR-005**: The external packer MUST refuse a source folder that does not fit its buffers before running.
- **FR-006**: The 7zip plug-in's message and caption buffers MUST be filled with bounds.
- **FR-007**: No new strings; no plug-in interface change; short paths behave exactly as before.

## Success Criteria *(mandatory)*

- **SC-001**: The deep-folder probe reaches 20,000+ characters with no run-time check or crash report (before: crash at about 7,500).
- **SC-002**: The Change Directory probe with a 300- and a 1,000-byte file path focuses the file (before: the Debug build stops).
- **SC-003**: Packing from a 300- and a 1,000-byte folder with nested sub-folders puts every file into the archive (read back), for ZIP and 7z; the build before shows the loss.
- **SC-004**: Debug and Release builds, unit tests, the strict guard and the probes of 095-097 pass.
