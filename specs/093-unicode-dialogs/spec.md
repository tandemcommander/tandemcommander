# Feature Specification: Text typed into dialogs survives outside the code page

**Feature Branch**: `093-unicode-dialogs`
**Created**: 2026-10-01
**Status**: Draft
**Input**: `specs/NEXT-WORK.md` item 5 / encoding cluster **B-1** (`specs/069-finish-encoding-fixes/REMAINING-WORK.md` §1): 89 of the 91 dialogs of the program are created as code-page ("ANSI") windows, so a character that the system code page does not contain becomes `?` the moment it is typed or shown in a text field — and several dialogs then *store* that `?`. Includes the 7-Zip plug-in's password prompt (087 FR-010, revised there to "code-page characters only").

## Clarifications

### Session 2026-10-01

The maintainer is away and asked for the recommended option at every decision. The research (`research.md`, measured with a Win32 probe on this machine) decided the following.

- Q: What makes a text field lossy? → A: **How the dialog is created.** A dialog created through the code-page entry point gets code-page controls: text set from the program is cut down before it is stored, and typed characters arrive already converted. Reading the field with a Unicode call afterwards cannot bring them back. A dialog created through the Unicode entry point with the same template and the same code has Unicode controls. The message loop matters as much: a Unicode field served by a code-page loop still loses typed characters.
- Q: Which approach? → A: **Create the dialog as a Unicode window and keep its code** — what feature 015 did for Copy/Move, Create Directory and Rename. Per dialog, in groups, with the shared prerequisites first. Not: replacing single controls (more code, same result), nor flipping the default for all 89 dialogs at once (every risk at once).
- Q: Which dialogs? → A: **Those where a path, a name, a mask or a searched text is typed, prefilled or stored**: Change Directory, Pack, Unpack, Select/Unselect, panel filter, Convert, Make File List, the compare-arguments dialog, Change Icon, the volume label; Find Files with its sub-dialogs; the Configuration pages that store paths, commands or masks; the command line; the 7-Zip password prompts. Label-only dialogs (messages, progress, About, …) have no input to lose and stay as they are.
- Q: Message boxes? → A: **Not in this feature.** They only display text, they are the most used window of the program and of every plug-in, and they carry a known hazard (a code-page helper attached to their buttons). Deferred with that reason.
- Q: Master-password dialogs? → A: **Must not change.** The encryption key of the stored passwords is derived from the bytes those dialogs return; another encoding would lock users with an accented master password out of their passwords. Out of scope, recorded.
- Q: Other plug-ins' dialogs (FTP, SFTP, ZIP, renamer, …)? → A: **Not in this feature**, except the 7-Zip password prompts. Each plug-in has its own code-page chains; the 068 review showed a blanket change regresses FTP. Deferred.
- Q: The 7-Zip password — is "code-page characters work" (087) true? → A: To be measured before anything is changed (stage S5 starts with the measurement). The prompt returns the typed text as UTF-8 while the code that hands it to the engine reads it as code-page text. If that is confirmed, archives that users created with an accented password were encrypted with a garbled password. The fix must then **keep such archives openable**: when the true password is refused, the garbled form the old version would have used is tried once before the user is told the password is wrong.
- Q: Data already stored as `?`? → A: **Stays.** A `?` saved by an earlier version is a real question mark in the stored text; nothing can tell what it was. No migration.
- Q: The command line? → A: **Last stage, and only if its review passes.** It is one control with about a dozen places that count characters (selection offsets, drop position, a typed-character switch). If the stage is not accepted it is reverted and recorded, and the rest of the feature stands.

## User Scenarios & Testing *(mandatory)*

### User Story 1 — A path with characters outside the code page can be typed and is shown intact (Priority: P1)

On a Central European Windows a user works in a folder named `Ж-проект` or `日本`. Change Directory (Shift+F7), Pack, Unpack and the other dialogs that show or take a path display that path as it is, accept it typed, and act on exactly that path. Today the dialog shows `?-??????`, and pressing OK goes to a path that does not exist.

**Why this priority**: it is the confirmed defect of the 068 review (cluster B-1) in the dialogs used most; the entered `?` is also saved into the history.

**Independent Test**: a GUI probe opens each dialog on such a folder and checks three things per text field: the field is a Unicode control; its prefilled text read back equals the real path; characters posted to it one by one arrive intact. Then OK, and the effect is checked on disk or in the panel.

**Acceptance Scenarios**:

1. **Given** the panel in `…\Ж-проект`, **When** Change Directory opens, **Then** the field shows the real path; **When** the user types `…\日本` and confirms, **Then** the panel is in that folder and the history entry holds those characters.
2. **Given** Pack or Unpack with such a target path, **When** confirmed, **Then** the archive or the files are created under exactly that path.
3. **Given** Select, the panel filter, Convert or Make File List, **When** a mask or name with such characters is entered, **Then** it is applied and remembered unchanged.
4. **Given** text made only of code-page characters, **Then** every dialog behaves exactly as before.

### User Story 2 — Find Files accepts and keeps such text (Priority: P1)

*Named*, *Look in* and *Containing* take any character; the search uses it; the histories store it.

**Independent Test**: the probe types into the three fields of the Find window (which runs its own message loop on its own thread — the typing test is what proves the loop), starts a search in a folder named with such characters and finds the file.

**Acceptance Scenarios**:

1. **Given** the Find window, **When** characters outside the code page are typed into *Named*, *Look in* or *Containing*, **Then** they arrive intact, the search uses them, and after closing the program the stored histories hold them.
2. **Given** the Find window's menu, keyboard shortcuts and the result list, **Then** they work as before.

### User Story 3 — Configuration stores paths and commands intact (Priority: P2)

Hot Paths, User Menu, Viewers, Editors, the Command Shell page and the archiver pages store what the user sees. Today merely selecting a User Menu item whose command holds such a character rewrites it with `?`.

**Independent Test**: the probe opens Configuration, sets such a path in a Hot Path and in a User Menu command, confirms, closes the program and reads the stored values.

**Acceptance Scenarios**:

1. **Given** a stored hot path or user-menu command with characters outside the code page, **When** the page is opened and closed with OK without a change, **Then** the stored value is unchanged.
2. **Given** such text typed into those fields (also into the in-place editors of the lists), **Then** it is stored intact.
3. **Given** the Configuration tree, the lists with in-place renaming, and the pages that were not converted, **Then** they work as before.

### User Story 4 — The 7-Zip password prompt takes any character (Priority: P2)

A 7z or RAR archive encrypted with a password such as `heslo-ř` or `пароль` opens when that password is typed; a 7z archive created with such a password can be opened by other programs with the same password; archives made by earlier versions still open with the password the user remembers.

**Independent Test**: archives made by the 7-Zip program with such passwords are opened through the engine with the string the fixed code produces; an archive made with the garbled form (what the old code produced) opens through the retry.

**Acceptance Scenarios**:

1. **Given** an archive encrypted elsewhere with `heslo-ř`, **When** that password is typed, **Then** it opens.
2. **Given** a new 7z archive created by the plug-in with `heslo-ř`, **Then** the 7-Zip program opens it with `heslo-ř`.
3. **Given** an archive created by an earlier version of the plug-in with `heslo-ř`, **When** `heslo-ř` is typed, **Then** it opens (through the one retry).
4. **Given** an ASCII password, **Then** nothing changes.

### User Story 5 — The command line takes any character (Priority: P3)

Typing, pasting or inserting (Ctrl+Enter) a name with characters outside the code page into the command line keeps them; the command runs with them; the history stores them.

**Independent Test**: the probe posts such characters to the command line, inserts a file name, reads the text back and runs a command that writes its argument to a file.

**Acceptance Scenarios**:

1. **Given** a file `日本.txt` under the cursor, **When** its name is inserted into the command line, **Then** the command line shows and executes it (today: `??.txt`).
2. **Given** editing keys, selection, drag-and-drop into the command line, history recall and Ctrl+Backspace, **Then** they behave as before for code-page text, and select/delete whole characters for other text.

### Edge Cases

- A code-page helper window attached to a Unicode text field turns the field back into a code-page one, silently. Every helper attached to a field of a converted dialog must follow the field's kind.
- A text longer than the buffer: once a field can hold any character, the UTF-8 form needs up to three bytes per typed unit. On overflow the text is cut at a whole character — never read back through the code page (which would hand `?` and garbled bytes to the caller).
- A dialog that is not modal and is served by the main loop: that loop's dialog-key handling must be the Unicode one, otherwise every non-ASCII character typed there is corrupted (also for dialogs that stay code-page windows — measured — so the change must be neutral for them).
- Lists and trees inside a converted dialog start sending the Unicode forms of their notifications; handlers written for the code-page forms would go silent.
- A surrogate pair (emoji) and a lone surrogate typed or prefilled.
- Text that a dialog's own code still reads or writes through a code-page call: it keeps working for code-page text; such sites on the converted dialogs move to the Unicode helpers.
- The same dialog class used by a plug-in through the core (none — no dialog class crosses the plug-in interface; attached controls are created by core code).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: In every dialog listed in *Clarifications* (third answer), each text field MUST show prefilled text exactly, MUST accept typed, pasted and programmatically inserted characters of any script exactly, and the value the program uses and stores MUST be that text.
- **FR-002**: For text made only of characters of the system code page, every converted dialog MUST behave as before: same values, same keyboard handling, same histories.
- **FR-003**: Helpers attached to a text field (history combo edits, key forwarders, in-place editors of lists) MUST keep the field a Unicode control.
- **FR-004**: When text does not fit the caller's buffer it MUST be cut at a whole character; it MUST NOT be re-read through the code page.
- **FR-005**: The message loops that serve converted windows (Find's thread, the Configuration window, the main loop's dialog-key handling, secondary loops run while such a window is open) MUST deliver typed characters intact, and MUST remain neutral for windows that are still code-page windows.
- **FR-006**: List and tree notifications inside converted dialogs MUST keep working (label editing in Hot Paths and Views, the Configuration tree, Find's result list).
- **FR-007**: Stored data MUST NOT be migrated or rewritten by opening a dialog and confirming it unchanged.
- **FR-008**: The 7-Zip plug-in MUST hand the engine the password the user typed, as Unicode text, for opening, extracting, testing and creating archives; when the engine refuses it for an existing archive, the plug-in MUST try once the form an earlier version would have derived from the same typed text before reporting a wrong password. Passwords stay wiped from memory as in 087.
- **FR-009**: Message boxes, the master-password dialogs, label-only dialogs and other plug-ins' dialogs MUST NOT change; each is recorded as deferred with its reason.
- **FR-010**: The plug-in interface version MUST NOT change (no interface change is needed); the shared plug-in dialog library may gain an optional, default-off way to create a Unicode dialog.
- **FR-011**: No translation string changes.

### Key Entities

- **Converted dialog**: a dialog created as a Unicode window; its text fields hold UTF-16; the program reads and writes them through the existing UTF-8 helpers.
- **Message loop**: the code that takes messages from the queue for a window; four of them serve converted windows.
- **Legacy password form**: the string an earlier version of the 7-Zip plug-in derived from a typed password (its UTF-8 bytes read as code-page text).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In each converted dialog, a test text of Cyrillic, CJK and a surrogate pair is read back unchanged after being prefilled and after being typed character by character — **100 %** of the fields under test; the same probe run against the previous build fails on exactly those fields.
- **SC-002**: For code-page-only text every probed dialog gives the same value as the previous build.
- **SC-003**: After a session that used such text in Change Directory, Find and a Hot Path, the stored configuration holds it unchanged (no `?`).
- **SC-004**: An archive encrypted by the 7-Zip program with `heslo-ř` and with `пароль` opens with the fixed code; an archive encrypted with the legacy form opens through the retry; ASCII passwords are unaffected.
- **SC-005**: Debug and Release builds succeed; all unit tests and the probes of features 087–089 and 092 pass; the strict encoding guard reports 0 findings.
- **SC-006**: No dialog outside the list changes its window kind (checked by the probe on a sample: a message box, About, a master-password dialog).

## Assumptions

- The machine's code page is 1250; "outside the code page" is tested with Cyrillic, CJK and an emoji.
- Posted characters stand in for the keyboard in the probe; a real keyboard and an input method editor (IME) pass stay owed to a person.
- Histories and configuration values are already stored as UTF-8 through the registry layer (feature 004); only the window in front of them was lossy.
