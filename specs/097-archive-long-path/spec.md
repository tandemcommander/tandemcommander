# Feature Specification: Archives in long or accented folders open

**Feature Branch**: `097-archive-long-path`
**Created**: 2026-10-02
**Status**: Draft
**Input**: found by feature 095 and recorded in `specs/NEXT-WORK.md`; the maintainer: *"This is a defect and MUST be fixed."* An archive whose full path is longer than 259 bytes cannot be opened in a panel. With accented folder names that is about 130 characters - a path Windows and the rest of the program handle without any special effort.

## Clarifications

### Session 2026-10-02

The maintainer asked for autonomy; the decisions are the author's recommended options. Basis: `research.md` (code reading: the one line that limits the path, and an inventory of everything a longer path would reach).

- Q: What happens today? → A: When an archive is entered, its path is copied into a 260-byte buffer and **cut without a word** - even in the middle of a character. Then, depending on where the cut falls: Enter does nothing and shows nothing; or an error names a path the user never typed; or, if a file with the cut name exists, **that other archive is opened**. The path *inside* the archive is cut the same way: entering a folder deeper than 259 bytes lands in a parent folder without a message.
- Q: What is the fix - a clear refusal, or making it work? → A: **Both, in two stages.** Stage 1 removes the silent cut everywhere on this path: what cannot be handled is refused with the existing "The path specified is too long." message and **never another archive is opened**. Stage 2 makes archives at longer paths actually open: the file layer already opens them; what stood in the way is the cut and about two dozen fixed 260-byte buffers behind it in the core, which stage 2 replaces. Stage 1 alone would leave the maintainer's complaint ("cannot be opened") unanswered; stage 2 without stage 1's refusal as a backstop would be reckless.
- Q: How long may the archive's path be after stage 2? → A: **Any length the program supports for files** (it opens files through the Unicode long-path layer), with three stated exceptions that keep the refusal: (1) an archive handled by an **external archiver** (console programs take the name on a command line): the limit stays 259 bytes; (2) an archive handled by a **plug-in built for an interface older than 107** (it may hold the name in a 260-byte buffer): the limit stays 259 bytes - the rule feature 088 introduced for viewers, extended to archive names; (3) a plug-in that states its own limit keeps it (the CAB plug-in refuses names of 256 bytes or more with its own message).
- Q: The path inside the archive? → A: Stage 1 only: entering an inner path that does not fit is refused with the message instead of landing somewhere else. The limits of the listing itself (a folder or name over 255 bytes is not listed) are a property of the archive directory structure shared with plug-ins and are not changed.
- Q: Clipboard and drag-and-drop from or into an archive at a long path? → A: The two shared fields that carry the archive's name between the program and its shell helper are 260 bytes. Stage 2 must not let them work on a cut name (pasting could unpack another file; dropping could delete a file with the cut name): for an archive whose name does not fit them the operation is refused with the message. Widening them is a separate change (the shell extension shares the structure).
- Q: User-visible text? → A: No new strings: the existing "The path specified is too long." is used.
- Q: A defect of the same kind in the ISO plug-in found by the research (an error text built without a bound when the image cannot be opened, reachable today from a 240-byte name)? → A: Fixed in stage 1 (one bounded call).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Never the wrong archive, never silence (Priority: P1)

Whatever the length of the path, entering an archive either opens exactly that archive or shows a message saying the path is too long.

**Independent Test**: a probe builds folders of chosen byte lengths; for the "twin" case it also creates a file whose name is the cut form of the archive's path. On the build before the fix Enter opens the twin; after it, the real archive opens (stage 2) or the message appears (stage 1 limits).

**Acceptance Scenarios**:

1. **Given** an archive whose path does not fit a limit that still applies (external archiver, old plug-in), **When** the user presses Enter on it, types its path in Change Directory, or returns to it through history, a tab or a hot path, **Then** the "path too long" message appears and the panel stays where it was.
2. **Given** a "twin" file at the cut path, **Then** it is never opened in place of the requested archive.
3. **Given** a folder inside an archive whose inner path does not fit, **Then** entering it shows the message instead of landing in a parent.
4. **Given** a refresh of a panel (no user action), **Then** no message is shown repeatedly.

### User Story 2 - An archive in a deep or accented folder opens and works (Priority: P1)

A ZIP, 7z or TAR archive in a folder whose path is 130-250 accented characters (260-777 bytes), or longer than 259 characters, opens; its files can be viewed, unpacked, edited and packed back; files can be added and deleted.

**Independent Test**: the probe enters such archives, lists them (item count), views a file, edits a file and updates the archive, unpacks to a folder, adds a file, deletes a file, and leaves; compares results with a short-path control; the Debug build's run-time checks and the crash report are the detectors for any buffer that was missed.

**Acceptance Scenarios**:

1. **Given** a ZIP archive at a path of 260-777 bytes, **When** entered, **Then** its listing is shown and view, unpack, edit + update, add and delete work as at a short path.
2. **Given** the same for 7z and TAR archives, **Then** the same for the operations those plug-ins support.
3. **Given** a path longer than 259 characters (a true long path), **Then** the same, or the documented message where an exception applies.
4. **Given** an archive at a short path, **Then** every operation behaves exactly as before.
5. **Given** copy-to-clipboard or drag from an archive whose name does not fit the shared fields, **Then** the operation is refused with the message and nothing is unpacked or deleted.

### Edge Cases

- A cut that would fall in the middle of a UTF-8 character.
- Lengths just below and above each old limit (259/260 bytes; 259/260 characters).
- The archive path given on the command line (`-L`, `-R`), forwarded to a running instance, stored in a tab, in history, in a hot path.
- The archive's name in messages, titles, the crash report and the plug-in service that returns the panel's path (each had a 260-byte buffer).
- An ISO image that cannot be opened at a 240-byte path (the plug-in's unbounded error text).
- Leaving the archive and re-entering; two panels on the same long-path archive.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Entering an archive MUST NOT cut its path or the inner path. A path that cannot be handled MUST be refused with the existing "path too long" message, the panel staying where it was; a refresh MUST NOT repeat the message.
- **FR-002**: The program MUST never open a different file than the archive requested.
- **FR-003**: An archive whose path the file layer can open MUST open in the panel when it is handled by a plug-in built for interface 107 or later; every core buffer that receives the archive's path MUST hold it whole or the operation that needs it MUST refuse cleanly.
- **FR-004**: For an archive handled by an external archiver, or by a plug-in built for an interface older than 107, the limit of 259 bytes MUST stay and be enforced by refusal (FR-001).
- **FR-005**: Operations that pass the archive's name through the 260-byte shared fields (clipboard, drag-and-drop with the shell helper) MUST refuse an archive whose name does not fit, before anything is unpacked or deleted.
- **FR-006**: The ISO plug-in's error text for an image that cannot be opened MUST be built with a bound.
- **FR-007**: No new user-visible string; the plug-in interface version does not change; behaviour for paths that fit today's limits is unchanged.
- **FR-008**: What is not made to work (external archivers and old plug-ins beyond 259 bytes, the shared fields, inner paths beyond the listing's limits, command-line forwarding limits) MUST be recorded with its reason.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In the twin-file case the build before the fix opens the wrong archive; the fixed build never does (**0** of the probe's cases).
- **SC-002**: For ZIP, 7z and TAR archives at paths of 260, 400, 777 bytes (accented) and at more than 259 characters, the probe's enter / list / view / unpack / edit + update / add / delete sequence gives the same results as the short-path control, with the program alive and no run-time check or crash report.
- **SC-003**: Every refusal case shows exactly one message and leaves the panel where it was.
- **SC-004**: Short-path rows are identical on both builds.
- **SC-005**: Debug and Release builds succeed; unit tests, the strict encoding guard and the probes of features 095 and 096 pass.

## Assumptions

- The inventory of `research.md` is the work list; anything it missed is caught by the probe's run-time checks or by the independent review.
- GUI probes run on the hidden desktop; a real mouse drag is owed to a person.
