# Fix log: feature 134 - FTP client, mixed texts

Branch `134-ftp-mixed-templates` from `release-0.1.10` (the tree prepared for 0.1.10, so this
feature is for the version after it). Session 2026-10-13, asked for by the maintainer ("do all
four", point 4). Spec Kit order: `spec.md`, `plan.md`, `research.md`, `tasks.md`,
`agent-brief.md` before the first line of code.

## 1. Measured before any change (`probe/ftp134_result_before_*.txt`)

The triage of feature 130 was reading only. The probe (`probe/ftp134_probe.ps1` with its own
server `probe/ftp134_server.py`) on the build of 0.1.10:

| Row | Czech | English |
|---|---|---|
| MKDU8 - Create Directory refused, the reply holds the name as UTF-8 | **garbled**: `Adresář: NovĂ˝ adresĂˇĹ™`, the reply too | readable |
| MKDCP - the reply holds the name in code page 1250 | name garbled, reply readable | **garbled** (a UTF-8 name and a code-page reply in one text) |
| MKDASCII - a reply without the name | name garbled | readable |
| COPY - subject of the Copy dialog | **garbled** | readable |
| COPY - title of the operation window | **garbled** | readable |
| COPY - both lists of the operation window | **garbled** | readable |
| DELETE - the question | readable (the Czech template has no accented letter - "works by accident", as the triage said) | readable |
| DELETE - the state cell with the server's refusal | **garbled** | readable |
| LOG | **garbled** | **garbled** (`Changing path to "/Ĺ˝luĹĄ..."` next to a readable `CWD /Žluť...`) |
| CWDERR - a directory that does not exist | readable (the core answers) | readable |

9 texts fail in Czech, 2 in English. The triage's two predictions that were only deduced - the
log is wrong in English too, and a code-page reply spoils an English message - are confirmed.

## 2. How the work was done

- Shared pieces first (the session): `LoadStrU8` (`ftp.h`, `ftp.cpp`), `FTPTextToU8` /
  `FTPGetErrorTextU8` (`ftputils.h`), the core's `GetCommonFSOperSourceDescr` as UTF-8
  (`src/zip.cpp`) with Undelete's label (`src/plugins/undelete/dialogs.cpp`); built.
- Four work packages in parallel with `agent-brief.md` (contracts between the packages: who
  gives UTF-8 after the feature), no build inside a package. Records: `parts/A.md` (control
  connection, sockets, SSL, **the log**), `parts/B.md` (file system, configuration, parser),
  `parts/C.md` (dialogs), `parts/D.md` (operations, queue, workers).
- One build afterwards: **clean at the first attempt** (37 files, about 1,200 lines added).

## 3. What changed, by what a user sees

- **Messages**: about 60 sentences with a name, a path, a Windows error text or the server's
  reply (create directory, change path, list, quick rename, download, bookmark questions,
  export / import errors, file-locked messages, ...). Replies and `FormatMessage` texts are
  made UTF-8 at the place of use (`FTPTextToU8`, `CFTPU8Piece`), never where they are parsed.
- **Copy / Move / Delete / Change attributes questions and the operation window** (title, item
  descriptions, state with the server's refusal, the connection's action and status, the Solve
  Error dialog's reply field). The subject text comes from the core as UTF-8 now.
- **The log** (`CLogs::LogMessage`): every appended message is made UTF-8 on its own, so the
  log as a whole is always valid UTF-8; the composed messages use UTF-8 templates. *Save log*
  writes UTF-8 with a BOM; *Copy* puts Unicode text on the clipboard.
- **Controls that could only show the code page** (wrong in English too): the "Connecting to
  ... as ..." line of the password prompt, the login error's reply, the list of logs, the
  lists of server types and proxy servers, the certificate error text, and the Quick Connect
  address written back on OK - **the address history now gets the text that was typed** (it
  got the UTF-8 bytes read through the code page).
- Not changed, by rule: everything sent to a server and its log copy, stored configuration,
  the listing file, identity keys, message-box captions.

Counts from the records (rows of the triage's tables): A 43 fixed / 16 right as it is; B 18
fixed / 3 right; C 21 fixed / 8 right / 1 recorded; D 34 fixed / 4 right / 1 piece recorded.
The triage was wrong in three rows (a "numbers only" text has a UTF-8 separator; a row that
assumed a signed `char`; one row that shares its template with a defective one).

## 4. Independent reviews (two, read-only, refute-first, each with its own test programs)

Neither found a change of bytes that are sent, stored, written to a listing file or compared,
an overrun, a dangling pointer or a format / argument mismatch (the templates of all shipped
translations were sampled against the arguments).

- **A real regression - fixed**: the two list views of the operation window convert a cell with
  `SplU8ToW` into the 260 units the list view offers; that gives 0 also when the text does not
  FIT, and the fallback then read the whole cell through the code page. Before the feature a
  Czech description with ASCII names was "invalid UTF-8", took the code-page path and was
  readable; after it the same long cell was valid UTF-8, did not fit, and every accented letter
  of the sentence came out as two wrong ones (measured by the reviewer). Now `FTPCellTextToW`
  (`ftputils.h`): converted whole, cut to fit at a whole character.
- The log's rule for a torn last character could drop a real code-page letter at the end of a
  message that is UTF-8 otherwise (`... není` lost its `í`): the UTF-8 part is kept and the
  last bytes are read through the code page now - nothing is dropped.
- The advanced-settings summary cut a value at 36 bytes of UTF-8 (fewer letters than before in
  languages with accented templates): 36 characters again.
- `SplU8TrimTornTail` on a text that may be code page (worker error text, the first line of a
  reply) took its last accented letter: `FTPTrimTornTailIfU8`.
- `FTPLogMsgCutKeepLineEnd` could leave `\n\r\n` after a cut that ended in a lone `\n`.
- The interface comment of `GetCommonFSOperSourceDescr` (`spl_gen.h`) says the text is UTF-8.

Recorded, not changed: a UTF-8 reply that a 300- or 700-byte reply buffer cut inside a
character is read through the code page in a message box (the log shows it right) - old; the
caret arithmetic of the Logs window counts bytes against a UTF-16 edit control (it drifts when
the size limit trims the log while the caret is not at the end) - cosmetic, more visible now;
a log that holds a zero byte is copied to the clipboard up to it; the tool-tip width of a list
cell is measured with an `A` call.

## 5. Tests

| What | Result | Record |
|---|---|---|
| probe, build of 0.1.10, Czech / English | FAIL 9 / FAIL 2 (section 1) | `probe/ftp134_result_before_czech.txt`, `..._english.txt` |
| probe, final build, Czech / English | PASS 18, FAIL 0 / PASS 18, FAIL 0 | `probe/ftp134_result_czech.txt`, `..._english.txt` |
| the bytes the server received, before vs after (PORT numbers aside) | identical, 95 lines, both languages | `probe/compare_server_logs.py`, `probe/server_bytes_*.log` |
| regressions: 116 FTP passwords, 131 (`%` in a host name), 127, 130 Czech | 45 / 0 (5 not driven); 2 / 0; 19 / 0 (3 not driven); 19 / 0 | |
| saltests / `tools/check_encoding.py` | 18,567 checks, 0 failed / `TOTAL: 0` | |
| `build.cmd full`, `build.cmd full release` | clean | |
| product registry key | identical before and after every run | |

**Not driven in the program** (read, reviewed and built only; owed to a person or a later
probe): the bookmark questions (Remove / Rename / New with an accented bookmark name), the
password prompt's "Connecting to ... as ..." line and the login error's reply (they need a
server that asks for a password / refuses it), the Quick Connect address in the history, Save
log (the file starts with a BOM) and Copy log (clipboard), the lists of server types and proxy
servers, the certificate error text (needs FTPS), the wait windows (they appear only on a slow
server), a list cell longer than 259 characters, the connect error state machine with a proxy.

## 6. Left

- A message cut by a reply buffer inside a UTF-8 character (above).
- The Logs window's caret arithmetic in bytes.
- `PrintDiskSize` mode 2 of the core ("1 234 bajtů") is mixed in itself (a UTF-8 separator in a
  code-page text) - one log line of a worker shows the separator wrong; the core's function.
- The "other defects seen" of the triage that were not on a changed line (cut display copies
  of names in the Solve Error dialogs, autorename at a byte offset - `specs/NEXT-WORK.md`).
