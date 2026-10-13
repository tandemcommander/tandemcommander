# Research: feature 134

## R1 - The log becomes UTF-8 (the maintainer's decision)

- **Decision**: every message appended to a log is made UTF-8 at the sink (valid UTF-8 kept,
  anything else read through the system code page); composed log messages use UTF-8 templates.
  A saved log file and the text copied from the log are UTF-8.
- **Rationale**: the log is one byte string per connection and is shown as UTF-8 only when all
  of it is valid UTF-8. It receives code-page sentences, UTF-8 names, raw replies and the
  commands as sent - one accented name spoils the whole log, in English too. No per-site
  change repairs that.
- **Asked**: closing message of 130 and the recommendation after 131 ("I would convert the log
  to UTF-8 ... the price is that the bytes of a saved log and of copied text change"); the
  maintainer answered "do all four".
- **Alternatives**: keep the log as it is (the names stay garbled); convert only at display
  time (the saved file would stay mixed).
- **Consequence to check**: the log's size limit counts bytes; a message cut by a buffer must
  keep its line end; the copy of a sent command shows the name readable although the bytes
  sent may be in the code page - the log shows what was meant, the server's own log what was
  sent (recorded in the fix log).

## R2 - The core's subject text

- `CSalamanderGeneral::GetCommonFSOperSourceDescr` (`src/zip.cpp`) composes a core word
  (`::LoadStr`, code page) with the panel item's name (UTF-8). **Decision**: the core gives the
  whole text as UTF-8 (`LoadStrU8`). Users: the FTP client (five sites) and Undelete
  (`dialogs.cpp:836`); a plug-in that wraps the text in a code-page template is no worse off
  than today (the text was mixed already) and right once its template is UTF-8.

## R3 - Server replies and other texts of unknown encoding

- **Decision**: `FTPTextToU8(text, buf, size)` - valid UTF-8 is kept, anything else is read
  through the system code page - at the place of use, never inside `FTPGetErrorText` or the
  reply parsers (their callers rely on the bytes). This is the reverse rule of 127.

## R4 - What is never touched

The triage's list (section "What must not be touched") is taken over as it is: everything sent
to the server and its log copy, stored data, identity keys, message-box captions, the filter
text modified in place, `TRACE` texts.

## R5 - The test server

- **Decision**: a server of the probe's own, standard library only (`socketserver`), on
  127.0.0.1: USER / PASS, SYST, FEAT, PWD, CWD, TYPE, PASV, LIST, RETR, STOR, MKD, DELE, RNFR /
  RNTO, QUIT. It serves a small in-memory tree with accented names (UTF-8 listing), can be told
  to refuse a command with a reply text in ASCII, UTF-8 or code page 1250, to slow a transfer,
  and logs every received line as hex (SC-002).
- **Alternatives**: `pyftpdlib` (not installed; cannot answer in a chosen encoding without
  overrides); a real server (not allowed - nothing but the local machine is contacted).

## R6 - Measure first

The triage is reading only. Before any change the probe records, on the build before: the
bookmark question, the three refusals, an operation-window cell, the Copy label, the log text -
in Czech and in English. A row that does not fail before is a finding (a template without an
accented letter works by accident, the triage says so for `Odstranit soubor %s z %s`).
