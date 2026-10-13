# Fix log: feature 137 - a name is not cut at a byte position

Branch `137-names-cut-at-byte` from `136-ftp-verify-rows`. Session 2026-10-13 ("fix what you
can"). Spec, plan and tasks before the measurement.

## 1. Measured on 0.1.9

| Row | Result | Record |
|---|---|---|
| QRLONG - Quick Rename on SFTP to a name of 100 CJK letters (304 bytes) | the core cuts it to 259 bytes and **asks the server to rename to the cut name**; the test server refuses ("SFTP Protocol Error" - a Linux name holds 255 bytes), so nothing is renamed *there*. A server with longer names (Windows) would take it. No word about the length | `probe/sftp_rows_before_v019.txt` |
| QR250 - a name of 250 letters (the row 131 / 133 owed) | renamed to all 250 | the same |
| AUTOREN - FTP download with "If Cannot Create File: rename automatically" into a folder that leaves room for 12 bytes of an accented name | **the file is not downloaded**: "Target file cannot be created or opened, system error: (123) the file name ... is incorrect" - the name was cut inside the letter `š` | `probe/ftp_autoren_before_v019.txt` |
| the same with room for 13 bytes (the cut falls between letters by chance) | works | not kept |

So the note "the file gets another name than it should" was right for Quick Rename in
principle and wrong for the FTP case: there the cut name is not valid text and the download
fails.

## 2. Fixed

- **Core, Quick Rename on a plug-in file system** (`src/fileswn5.cpp`): a typed name of
  `MAX_PATH` bytes or more is refused ("Cannot finish operation because of too long name."),
  the dialog comes back with the typed text, the plug-in is not called.
- **Core, the in-place rename line** (found by the review, `HandeQuickRenameWindowKey`): the
  name was read into 259 UTF-16 units and converted into 259 bytes; when that did not fit, the
  "legacy A call" supplied the name through the code page with best-fit mapping, cut - and
  that was the new name (on a server: a row of question marks, renamed literally). Now the
  buffer holds any name a file system can (so a long name on a disk works), a text over the
  edit line's buffer or over what a plug-in can receive is refused, and the line stays open.
- **FTP automatic rename** (`operats5.cpp`, directory and file): the three cuts fall at a whole
  character (`SplU8WholePrefixLen`, `splunicode.h`); when not even the first character of the
  name fits, the item fails with "name too long" instead of becoming `.txt` or ` (2)`.

## 3. Independent review

It could not break the changed code (a Python port of the two FTP compositions over 344,000
cases: no index out of range, no overlong result, no invalid text). Its findings, all taken:
the in-place rename route above; a name with nothing of the original left; a unit check that
could not fail (replaced by three that can). It listed the other core routes that hand a typed
name to a plug-in (`CreateDir`, `CopyOrMoveFromFS`: buffers of `2 * MAX_PATH` with the same
dialog limit - no cut).

Recorded, not changed: `SalMakeValidFileNameComponent` (core) cuts a name at byte 256, possibly
inside a character (a server name of 257-259 bytes that is "not valid" as a Windows name); the
cut is at a code point, not at a grapheme (an accent written as a combining mark can be lost).

## 4. Results

| What | Result |
|---|---|
| QRLONG, final build | "too long name" said, the file keeps its name, the server holds what it held |
| QR250 | renamed to 250 letters |
| AUTOREN (room for 12 bytes) | the file is downloaded as `příli.txt`, 3,000 bytes, full name 258 bytes |
| SFTP probe (17 rows) / FTP probe Czech, English (14 rows) | 34 / 0 after one rerun (see below); 33 / 0 and 33 / 0 |
| saltests | 18,774 checks, 0 failed |
| Debug build | clean |

**Seen on the way, queued** (`specs/NEXT-WORK.md`): in one run of the SFTP probe the row R2 could
not connect ("SSH handshake failed: Unable to exchange encryption keys" - not seen again in
three further runs), and at exit the debug build then showed **"Detected memory leaks!"** - a
leak on the failed-handshake path of the SFTP plug-in.

**Not driven**: the in-place rename line (it opens on a click on the focused name with a
setting; no real mouse on the hidden desktop) - read and reviewed.
