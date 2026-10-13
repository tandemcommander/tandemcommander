# Feature Specification: FTP client - messages, operation windows and the log show names readably

**Feature Branch**: `134-ftp-mixed-templates`
**Created**: 2026-10-13
**Status**: Implemented
**Input**: The maintainer: "do all four, one after another" - point 4 of the recommendation
after feature 131: "FTP mixed texts after the release: about 104 places in eight steps; it needs
a test FTP server. To the open question: I would convert the log to UTF-8 - otherwise two
encodings stay side by side in it and file names keep showing garbled; the price is that the
bytes of a saved log and of copied text change." The map of the places is
`specs/130-plugin-mixed-templates/triage/ftp.md` (read-only triage of feature 130, nothing
measured).

## User Scenarios & Testing

### User Story 1 - Messages and dialogs of the FTP client name files and servers readably (Priority: P1)

In a language whose texts have accented letters (Czech, German, Slovak, French, ...), a message
of the FTP client made of a translated sentence and a name - a bookmark, a file or directory on
the server, a local file, the text of a Windows error, the server's own reply - shows one half
as garbage. This is the defect of GitHub #7, fixed in the core (127) and in the other plug-ins
(130); the FTP client is the last place.

**Independent Test**: no server needed - Connect to FTP Server, a bookmark named
`Žluťoučký kůň`, the buttons Remove, Rename and New; with a server - create a directory that
already exists (the server's refusal in a message box).

**Acceptance Scenarios**:

1. **Given** Czech and a bookmark with an accented name, **When** Remove is pressed, **Then**
   the question shows the sentence and the name both readable.
2. **Given** a server that refuses a command with a reply in ASCII, in UTF-8 or in the system
   code page, **When** the refusal is shown, **Then** sentence, name and reply are readable in
   all three cases.
3. **Given** English, **Then** every text is what it was.

### User Story 2 - The operation window, wait windows and confirmations (Priority: P1)

Copying, moving or deleting files with accented names: the descriptions in the operation
window's lists, the "what is being done" column, the texts of the wait windows and the question
that names what is going to be copied or deleted are readable.

**Independent Test**: copy one file with an accented name from the server; read the cells of the
operation window's lists and the label of the Copy dialog.

### User Story 3 - The log of a connection is readable (Priority: P2)

The log mixes translated sentences, names and the server's replies in different encodings, so
one accented directory makes the whole log show through the wrong encoding - in English too.
Every line of the log is readable; a saved log and the text copied from it are UTF-8.

**Independent Test**: connect, enter a directory with an accented name, open the log window and
read its text; save the log and read the file.

### User Story 4 - Places that showed a name wrong in every language (Priority: P2)

A few controls could only show text of the system code page: the "Connecting to ... as ..."
line of the password prompt, the list of logs, the address written back by Quick Connect (and
then stored in the address history), the lists of server types and proxy servers, the
certificate error text.

### Edge Cases

- A server reply or a stored value in the system code page (an old bookmark, an old server):
  shown as before - nothing that was readable becomes unreadable.
- A user name, host or bookmark saved by an older version in the code page.
- A text cut by a buffer: cut at a whole character.
- The log's size limit counts bytes: a message may be longer than before.

## Requirements

- **FR-001**: Every text the FTP client composes from a translated sentence and a name, path,
  error text or server reply MUST be shown readable in every language the product ships.
- **FR-002**: Nothing sent to a server, stored in the configuration, written to a listing file
  or compared as an identity MUST change. The two exceptions, both corrections: the address
  Quick Connect writes back and stores is the text that was typed; a saved log and the text
  copied from the log are UTF-8.
- **FR-003**: A server reply or stored value of unknown encoding MUST be shown at least as well
  as before (valid UTF-8 as UTF-8, anything else through the system code page).
- **FR-004**: English texts MUST be unchanged; no new texts for translation; no change of the
  plug-in interface. The core's subject text for file-system operations becomes UTF-8 as a
  whole (it was a code-page word around a UTF-8 name).
- **FR-005**: A name or path used as such is never cut by this work; a shown text is cut only
  at a whole character.

## Success Criteria

- **SC-001**: The probe rows that fail on the build before (a bookmark question, a refusal with
  each of the three reply encodings, an operation-window cell, the Copy label, the log) pass on
  the final build, in Czech; in English the same rows give the texts of the build before.
- **SC-002**: The bytes the test server receives for a fixed sequence of actions are identical
  before and after.
- **SC-003**: Every place listed by the triage has a verdict in the feature's records (fixed /
  right as it is / recorded with a reason).
- **SC-004**: Regression probes of 116 (FTP passwords), 127, 130 and 131 pass; unit checks pass.

## Assumptions

- The maintainer's "do all four" after the recommendation is taken as the decision that the log
  becomes UTF-8.
- The test server is a small server of the probe's own (standard library), able to answer with
  a chosen reply text and encoding; no real server is contacted.
- What cannot be driven on the hidden desktop (wait windows that appear only on a slow server,
  the clipboard) is recorded as not driven.
