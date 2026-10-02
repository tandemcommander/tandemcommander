# Feature Specification: An edited file with an accented name is packed back into its archive

**Feature Branch**: `096-archive-edit-accented`
**Created**: 2026-10-02
**Status**: Draft
**Input**: found by the probe of feature 095 and confirmed by measurement (`research.md`): a file inside an archive whose name contains any character outside ASCII is edited, the archive is left - and the program neither offers to update the archive nor says anything. The edit is lost. The maintainer: *"This is a defect and MUST be fixed."*

## Clarifications

### Session 2026-10-02

The maintainer asked for autonomy; decisions are the author's recommended options.

- Q: What exactly happens? → A: When a file from an archive is edited (F4) or opened by Enter, the program unpacks it to a temporary folder and remembers its time and size. When the archive is left (or the program is closed) it looks at each such temporary file again to see whether it changed, and offers to pack the changed ones back. That look-up read the file's path - stored as UTF-8 - through a code-page call, so a file with a non-ASCII character in its name was "not found", taken for unchanged and forgotten; the temporary copy was then deleted. Measured for Czech and Cyrillic names, short and long, in ZIP and 7z archives, on leaving the archive and on closing the program. ASCII names, names with spaces and files in accented *folders* of the archive were not affected.
- Q: Since when? → A: Every release (0.1.0-0.1.8): feature 004 moved the unpacking side to UTF-8 and missed this look-up.
- Q: What about a file that cannot be looked at for another reason? → A: **It is offered for the update instead of being forgotten.** Only "the file is not there" may drop it from the list. A failure to look must never again turn into a silent loss.
- Q: Scope? → A: The look-up, and the one other code-page call on the same path in the same function (setting the current directory before packing). Other callers of the same class were already correct (`research.md`).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Editing `článek.txt` inside an archive keeps the edit (Priority: P1)

The user opens a ZIP or 7z archive, presses F4 on `článek.txt`, changes and saves it, and leaves the archive. The program asks whether to update the archive; after Yes the archive holds the new content.

**Independent Test**: `probe/archedit_probe.ps1` - names in ASCII (control), Czech, Cyrillic, with a space, in an accented folder, long accented names; F4 with a console "editor" that appends a line; leave the archive or close the program; read the archive back.

**Acceptance Scenarios**:

1. **Given** an edited file with a non-ASCII name, **When** the archive is left, **Then** the Archive Update question appears and after Yes the archive contains the edit.
2. **Given** the same, **When** the program is closed instead, **Then** the same question and result.
3. **Given** a file opened by Enter (its associated program changed it), **Then** the same.
4. **Given** an ASCII name, **Then** nothing changes.
5. **Given** an unchanged file (viewed, not edited), **Then** no question, as before.

### Edge Cases

- The temporary folder itself has an accented path.
- The temporary copy was deleted by the user: no question (it is not there).
- The temporary copy cannot be examined (access denied, sharing): it is offered for the update.

## Requirements *(mandatory)*

- **FR-001**: The check whether a temporary copy changed MUST find the file whatever characters its name and path contain.
- **FR-002**: A copy MUST be dropped from the list of edited files only when it did not change or does not exist; any other failure to examine it MUST keep it.
- **FR-003**: Packing back MUST run with the temporary folder as the current directory also when its path is not ASCII.
- **FR-004**: No user-visible string change; ASCII behaviour unchanged.

## Success Criteria *(mandatory)*

- **SC-001**: In **17 of 17** probe cases the archive contains the edit after the update (before: 7 of 17 - the ASCII-named ones).
- **SC-002**: Debug and Release builds succeed; unit tests and the strict encoding guard pass.
