# Feature Specification: Long archive paths do not overrun buffers

**Feature Branch**: `095-archive-path-buffers`
**Created**: 2026-10-02
**Status**: Draft
**Input**: `specs/NEXT-WORK.md` item 5, found by the analysis of feature 092: *"An unbounded `StrICpy` into `buf[MAX_PATH]` at `fileswn9.cpp` (`OfferArchiveUpdateIfNeeded`, the disk-cache key). A path longer than 259 bytes overruns it."*

## Clarifications

### Session 2026-10-02

The maintainer is away and asked for full autonomy; the decisions are the author's recommended options.

- Q: Is it one place? → A: **No - the same pattern four times, plus neighbours.** Wherever the panel shows an archive and the program builds the name under which files of that archive are kept in the disk cache, the archive's path is copied without a length check into a buffer on the stack: `fileswn9.cpp` (260 bytes), `fileswn2.cpp` (620), `fileswn6.cpp` (520), `fileswn5.cpp` (830). In two of them the path inside the archive and the file name are appended, and the same functions hold further fixed buffers filled from the same data. The archive's path may be up to 98,301 bytes since long paths are supported (feature 004); UTF-8 makes it worse - a path of 130 Czech characters is already over 259 bytes.
- Q: When does it happen? → A: When an archive whose full path (in UTF-8 bytes) is longer than the buffer is open in a panel and the user views or edits a file from it (F3, F4, Enter on a file), leaves the archive after editing a file from it, or the program offers to update the archive. The write goes past a stack buffer: a crash at best.
- Q: Fix how? → A: **Remove the fixed sizes on this path.** The name is built in storage that fits the longest path the program supports; where a later consumer has a real limit (the cache's own limit for a name, a temporary file's path), the existing "name too long" outcome is used instead of overrunning. No behaviour change for paths that fit today.
- Q: Scope? → A: The four sites and every fixed buffer in the same functions that receives the archive path, the path inside the archive or the file name. Other unbounded copies elsewhere in the program are not searched for in this feature; what is seen on the way is recorded.
- Q: User-visible text? → A: None new; the existing "name too long" message is reused where a limit is real.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Viewing and editing files from an archive in a deep folder (Priority: P1)

An archive lies in a folder whose full path is longer than 260 bytes (deep folders, or fewer but accented characters). The user enters it, presses F3 or F4 on a file, edits and saves, leaves the archive. Everything works as for a short path, or - where a real limit of Windows or of the cache is reached - a message says the name is too long. The program never crashes and never corrupts memory.

**Why this priority**: memory corruption on a path a user reaches by ordinary work.

**Independent Test**: a probe builds a folder tree with a path of about 300, 600 and 1,000 bytes (ASCII and accented), puts a ZIP archive there, opens it in a panel, views and edits a file from it and leaves the archive; the Debug build's run-time checks catch any stack overrun. The same probe on the build before the fix shows the failure.

**Acceptance Scenarios**:

1. **Given** an archive whose path is longer than 259 bytes, **When** a file in it is viewed (F3), **Then** the viewer shows it, or a "name too long" message appears; the program stays alive and no run-time check fires.
2. **Given** the same archive, **When** a file is edited (F4), saved, and the archive is left, **Then** the update question and the update work as for a short path.
3. **Given** an archive in a short path, **Then** every step behaves exactly as before.

### Edge Cases

- A long path *inside* the archive and a long file name, each alone and together with a long archive path.
- A name that is not a valid Windows file name (the existing substitute name).
- Two files in one folder of the archive whose names differ only in case (the existing suffix on the cache name).
- The path lengths just below and just above each old buffer size (259/260, 519/520, 619/620, 829/830 bytes).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Building the disk-cache name of an archive or of a file in an archive MUST NOT write past any buffer, for every archive path, inner path and file name the program can hold.
- **FR-002**: Every fixed-size buffer in the affected functions that receives the archive path, the inner path or the file name MUST either be sized for the longest value or be filled with a bounded copy whose overflow leads to the existing "name too long" outcome.
- **FR-003**: For values that fit the old buffers the behaviour MUST be unchanged, including the exact cache names (so that files already in the cache during a session are found).
- **FR-004**: No new user-visible string; no plug-in interface change.
- **FR-005**: Unbounded copies seen elsewhere MUST be recorded, not silently fixed.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: On archive paths of about 300, 600 and 1,000 bytes the probe's view / edit / leave sequence ends with the program alive, no run-time check or crash report, on the fixed build; the build before the fix fails on at least the shortest.
- **SC-002**: On a short path the probe's results are identical on both builds.
- **SC-003**: Debug and Release builds succeed; unit tests and the strict encoding guard pass.

## Assumptions

- The Debug build's stack run-time checks (`/RTC1`) and the crash report are the detector; the probe runs on the hidden desktop.
