# Feature Specification: An FTP file name with an unpaired surrogate keeps its name on a UTF-8 server

**Feature Branch**: `269-ftp-wtf8-listing`  
**Created**: 2026-10-20  
**Status**: Draft  
**Input**: User description: "Backlog item ftp-wtf8-name-listing-round-trip - implement exactly what it describes." From backlog item ftp-wtf8-name-listing-round-trip.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - The server's file is shown and downloaded under its own name (Priority: P1)

A user has a file whose name holds an unpaired UTF-16 surrogate (Windows allows such names on
NTFS; the program carries them as WTF-8) on an FTP server that stores names byte for byte in UTF-8
(a typical UNIX server). Today the plug-in's listing reads that name as code-page text: the panel
shows another name (`a` + U+D800 + `.txt` becomes `aí €.txt` with the Central European code page)
and downloading it creates a local file of that other name. After the change the panel shows the
name as it is and the download creates the file under the same name.

**Why this priority**: the shown and downloaded name is wrong for every such file; it is also the
root of the overwrite in story 2.

**Independent Test**: put the file on the test server, open the server in a panel on the hidden
desktop, copy the file to a local folder, read the local folder.

**Acceptance Scenarios**:

1. **Given** a UTF-8 server folder holding `a<U+D800>.txt`, **When** the user copies it (F5) into
   an empty local folder, **Then** the local folder holds exactly `a<U+D800>.txt` with the server's
   content.
2. **Given** a UTF-8 server folder holding `café.txt` (valid UTF-8), **When** the user copies it,
   **Then** the local folder holds `café.txt` (unchanged behaviour).
3. **Given** a legacy server that sends names in the code page (cp1250) holding `café.txt`,
   **When** the user copies it, **Then** the local folder holds `café.txt` (feature 224's detection
   unchanged).

---

### User Story 2 - Uploading over the same name asks first (Priority: P1)

The user uploads such a file to a server folder that already holds a file of the same name. Today
the upload's "target exists?" check compares the local name with the listing's misread name, finds
nothing and overwrites the server's file without the "Target File Already Exists" question (the
default setting is to ask). After the change the question comes and, answered Skip, the server's
file is kept.

**Why this priority**: it is the data loss of the item - a file on the server overwritten without
the question the user's setting asks for.

**Independent Test**: the local and the server folder hold the same such name with different
contents; upload (F5) from the local panel; record the dialogs and the server's file.

**Acceptance Scenarios**:

1. **Given** a local `a<U+D800>.txt` and a server `a<U+D800>.txt` with another content, **When**
   the user uploads the local file with the default settings, **Then** the "Target File Already
   Exists" question is shown, and after Skip the server's file still has its own content and no
   STOR / APPE was sent.
2. **Given** a local `a<U+D800>.txt` and an empty server folder, **When** the user uploads it,
   **Then** the server holds exactly `a<U+D800>.txt` with the local content (unchanged behaviour).

### Edge Cases

- A name that is valid UTF-8 or pure ASCII is kept byte for byte, as before.
- A name whose bytes are neither UTF-8 nor WTF-8 (a legacy server's code-page bytes) is still read
  in the code page and remembered as a code-page name, so commands for it go back in the code page
  (feature 224).
- A code-page name whose bytes happen to form a WTF-8 surrogate sequence (in cp1250: `í` followed
  by a byte 0xA0..0xBF and a byte 0x80..0xBF, e.g. `í` + no-break space + `€`) is now read as WTF-8
  instead of the code page. The WTF-8 reading is the program's own name encoding and the same
  ambiguity every WTF-8 reader of the program has; such a sequence in a legacy name is not expected.
- The surrogate bytes of a name that also holds bytes invalid in WTF-8 are read in the code page as
  a whole, as before.
- A path from a server's PWD reply is decoded by the same rule, so a folder whose name holds an
  unpaired surrogate keeps its name in the working path.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: A listing field (and a PWD path) whose bytes are valid WTF-8 - valid UTF-8 whose
  3-byte sequences may also encode an unpaired surrogate - MUST be kept byte for byte as the name,
  and MUST NOT be remembered as a code-page name.
- **FR-002**: A listing field whose bytes are not valid WTF-8 MUST be read as before: in the ANSI
  code page, remembered as a code-page name (feature 224); bytes undecodable either way are kept raw.
- **FR-003**: The decision "kept as UTF-8 or read in the code page" MUST be a pure rule with unit
  checks (ASCII, UTF-8, WTF-8 surrogates high and low, a valid pair encoded as two 3-byte sequences
  (CESU form), overlong and truncated sequences, code-page bytes, an embedded NUL byte, the empty field).
- **FR-004**: Names sent to the server and every other code path of the plug-in MUST stay unchanged;
  the fix is only in the reading of names.
- **FR-005**: `python tools/check_encoding.py --plugins` MUST no longer report `ftputils.cpp`
  (`strict-probe-rejects-wtf8`).

### Key Entities

- **Listing field**: the bytes of one column of a server's directory listing (a name, a link
  target, an owner ...), decoded to the program's UTF-8 (WTF-8) text once at intake.
- **Code-page name set**: the process-wide set of texts a listing or PWD gave in the code page;
  only they go back to a server in the code page (feature 224).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The probe rows DL and UP-ASK pass (before the change: both fail - another local name,
  the server's file overwritten without a question).
- **SC-002**: The control rows UP-NEW, DL-ACC and LEG-DL pass before and after.
- **SC-003**: Feature 224's probe (16 rows, UTF-8 and cp1250 servers) still passes 16 / 0.
- **SC-004**: The unit rule's checks pass in `saltests`, with 0 failed checks overall.

## Assumptions

- Assumption (autonomous run): the item's "Docker test servers, e.g. vsftpd" is met by 215's local
  ftpmini.py given a byte-transparent `wtf-8` mode - Docker is not running on the machine, and a
  UNIX server stores the name bytes the same way (item: "an agent can run one").
- Assumption (autonomous run): the item's approach "probe with `SplU8ToW` (WTF-8)" is implemented by
  a length-bounded WTF-8 validity rule (the listing field is not NUL-terminated); an embedded NUL
  byte counts as valid as it did with the strict call (conservative).
- Assumption (autonomous run): severity stays 7 - the overwrite reproduced on the probe (item Notes).
