# Contract: removing passwords from history entries (085, F1)

Module: `src/common/salurlpwd.{h,cpp}` — pure, no core or plugin globals,
compiled into `salamand`, `saltests` and the FTP plugin. Revised after the
first independent review (REJECT, 2026-10-01): the part no longer ends at a
space or quote in single values, escaped delimiters count, the FTP address
form became a pure tested function, form 2 no longer ends at `\`.

**Principle**: a history entry may lose a little more than the password; it
must never keep any of it.

## C1 — `SalStripAuthorityPassword(char* p, BOOL commandLine)`

`p` points at the start of an address part (`[user[:password]@]host…`).
The part ends at `/` or the terminating NUL; with `commandLine` also at a
character `<= ' '`, `"`, `'`, `<`, `>`.

Inside the part: `at` = the **last** `@` or `%40`; `colon` = the **first**
`:` or `%3A`/`%3a` before `at`. If both exist, the bytes `[colon, at)` are
removed in place (the rest of the string moves left). Returns TRUE when
something was removed. Never removes anything when the part has no `@`/`%40`,
or no colon before it (`host:2121` keeps its port).

## C2 — `SalStripUrlPasswords(char* text)` — one typed value

For a path or address typed into one field (Change Directory, Copy/Move
target, Find's *Look in*). Applies C1 (`commandLine = FALSE`) to every address
part:

1. after each `://` immediately preceded by at least two scheme characters
   (letters, digits, `+`, `-`, `.`);
2. if `text`, after leading white space, starts with a name of ≥ 2 scheme
   characters whose first is a letter, followed by `:` and **not** `//` — the
   part after the `:` (`ftp:corp\alice:pw@host`);
3. if `text`, after leading white space, starts with `//` — the part after it.

A one-character scheme (`C:`) is never a scheme.

## C2' — `SalStripCommandLinePasswords(char* text)` — a command line

The same three forms, with `commandLine = TRUE`, except that a form-1 URL
immediately preceded by `"` or `'` ends at the matching quote (or `/`) instead
of at white space: `curl "ftp://u:my pass@h/f"` → `curl "ftp://u@h/f"`.

## C2'' — `SalStripAddressPassword(char* address, const char* const* fsNames, int n)`

For a field whose content is always an address (FTP Quick Connect, where
`alice:pw@host` is a user and a password, while C2 would read `alice:` as a
file-system name). Skips leading white space, then `name://`, or one of
`fsNames` (case-insensitive; NULL/empty entries ignored) followed by `:` and
an optional `//`, or a bare `//`; applies C1 (`commandLine = FALSE`) to the
rest. The FTP plugin passes its two assigned names and the literals `ftp`,
`ftps` (the load-time cleaning may run before the names are assigned).

## C3 — `SalStripHistoryPasswords(char** history, int count, BOOL (*strip)(char*))`

For a most-recent-first history array of `malloc`ed strings: applies `strip`
to every entry; then removes every entry equal (byte-exact) to an earlier one,
`free`ing it; then moves the remaining entries up so that no NULL precedes a
non-NULL entry (`SaveHistory` stops at the first NULL). Returns TRUE when the
array changed. Compiled into the module that owns the array, so `free`
matches the allocation.

## C4 — where it is applied (the only places)

| Site | What |
|---|---|
| `dialogs3.cpp` `CChangeDirDlg::Transfer` | C3(C2) on `ChangeDirHistory` after the add |
| `dialogs3.cpp` `CCopyMoveDialog::Transfer`, `CCopyMoveMoreDialog::Transfer` | C3(C2) **only when the history is `CopyHistory`** (`CCopyMoveDialog` also serves Create Directory, Quick Rename and Edit New) |
| `viewer.cpp` `HistoryComboBox(…, stripPasswords = TRUE)`, used by `finddlg1.cpp` for *Look in* | C3(C2) before the drop-down is refilled |
| `editwnd.cpp` command-line execution | C3(C2') on `EditHistory` after the add |
| `zip.cpp` `CSalamanderGeneral::AddValueToStdHistoryValues` | C3(C2) when the array is `CopyHistory` or `ChangeDirHistory` |
| `mainwnd2.cpp` `LoadConfig` | C3(C2) on `ChangeDirHistory`, `CopyHistory`, `FindLookInHistory`; C3(C2') on `EditHistory` |
| `ftp/dialogs1.cpp` Quick Connect `Transfer` | the Address text written back before `HistoryComboBox` is `LastRawHostAddress` after `FTPStripAddressPassword` (= C2'') |
| `ftp/ftp.cpp` `LoadConfiguration` | C3(`FTPStripAddressPassword`) on `HostAddressHistory` |

The value handed to the operation (the panel path, the copy target, the
command, Find's search location, the Quick Connect connection data split at
`CBN_KILLFOCUS`) is never passed through C1–C3.

Both `LoadHistory` implementations (core `salamdr2.cpp`, FTP `ftp.cpp`) now
free and clear an entry whose `GetValue` failed instead of leaving an
uninitialised buffer (review finding 6 — C3 reads every entry).

## C5 — invariants (tested in `saltests`, `TestUrlPasswordStrip085`)

- no input grows; output is always a valid C string;
- a text without `@`/`%40` is returned byte-identical;
- applying C2 / C2' / C2'' twice equals applying it once (idempotent);
- valid UTF-8 in, valid UTF-8 out.

## Known limits (stated in `PRIVACY.md` and `CHANGELOG.md`)

- A password containing an unescaped `/` ends the address part early and is
  not removed (FTP itself would not parse it as a password either; `%2F`
  works).
- On the command line, a password containing a space outside a quoted URL.
