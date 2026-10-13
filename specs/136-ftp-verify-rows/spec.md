# Feature Specification: the FTP client's texts that feature 134 changed but did not run

**Feature Branch**: `136-ftp-verify-rows`
**Created**: 2026-10-13
**Status**: Implemented
**Input**: The maintainer: "fix what you can" - the second critical point named before it:
"FTP (feature 134) has rows that were not driven. About 120 places changed and only seven
scenarios were run in the program. Bookmarks, the password prompt, the login error and saving
the log are only read and reviewed - the risk is a broken text or a crash in a dialog nobody
started."

## User Scenarios & Testing

### User Story 1 - The dialogs feature 134 changed are seen working (Priority: P1)

Each of these is started in the program, in Czech and in English, on the build before 134
(0.1.9) and on the current one, against the probe's own FTP server:

- the bookmark dialogs: the check box of New ("copy data from bookmark ..."), the label of
  Rename, the question of Remove - with a bookmark named with accented letters;
- the password prompt: the line "Connecting to ... as ..." with an accented user name;
- the login error: the server's refusal shown in the dialog, the refusal text once in UTF-8
  and once in the system code page;
- the log saved to a file: the file is UTF-8 with a byte-order mark and holds the accented
  directory name readable; the list of logs shows its item.

**Why this priority**: a change that was never run is not a fix yet; these are the dialogs a
user meets first (connecting) and the one place where bytes written to a file changed.

**Independent Test**: the probe of feature 134 with the new rows.

**Acceptance Scenarios**:

1. **Given** a bookmark `Žluťoučký kůň`, **When** New, Rename and Remove are opened, **Then**
   each text shows the name readable, in Czech and in English.
2. **Given** a user name `jiří`, **When** the server asks for a password, **Then** the prompt
   names host and user readable.
3. **Given** a refused password, **Then** the server's words are readable whether they came in
   UTF-8 or in the code page.
4. **Given** a log with an accented directory, **When** it is saved, **Then** the file starts
   with the UTF-8 mark and every line reads right.
5. No row ends with a crash, a hung dialog or a changed registry.

### User Story 2 - What the rows find is fixed (Priority: P1)

A defect a row shows in the code of 134 is fixed here; anything else is recorded.

### Edge Cases

- A dialog that cannot be driven on the hidden desktop (the clipboard for Copy log) is
  recorded as not driven with the step owed to a person.

## Requirements

- **FR-001**: Each listed text MUST be read from its control in the program, before and after,
  in two languages, or be recorded as not driven with the reason.
- **FR-002**: A saved log MUST be read back from the file and checked byte-wise for the mark
  and for valid UTF-8.
- **FR-003**: Defects found in the code of feature 134 MUST be fixed with their row as proof.
- **FR-004**: No new texts for translation; the product's registry key is restored; nothing
  but the probe's local server is contacted.

## Success Criteria

- **SC-001**: Every new row passes on the final build in both languages, or is NOT DRIVEN with
  a reason; the rows that fail on 0.1.9 are named.
- **SC-002**: The rows of 134 still pass and the bytes the server receives for them are
  unchanged.

## Assumptions

- The probe's server gets two accounts: one that asks for a password, one that refuses it
  with a chosen text and encoding.
- 0.1.9 stands for "before 134" (the FTP client did not change between 0.1.9 and 134).
