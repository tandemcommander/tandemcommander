# Contract: removing passwords from history entries (085, F1)

Module: `src/common/salurlpwd.{h,cpp}` — pure, no core or plugin globals,
compiled into `salamand`, `saltests` and the FTP plugin.

## C1 — `SalStripAuthorityPassword(char* p, BOOL backslashEnds)`

`p` points at the start of an address part (`[user[:password]@]host…`).
The part ends at the first of: `/`, a character `<= ' '`, `"`, `'`, `<`, `>`,
the terminating NUL, and — only when `backslashEnds` — `\`.

Inside the part: `at` = the **last** `@`; `colon` = the **first** `:` before
`at`. If both exist, the bytes `[colon, at)` are removed in place (the rest of
the string moves left). Returns TRUE when something was removed.

Never removes anything when the part has no `@`, or no `:` before its last `@`.

## C2 — `SalStripUrlPasswords(char* text)`

Applies C1 to every address part found in `text`, in place:

1. after each `://` whose preceding scheme is ≥ 2 characters, first a letter,
   then letters, digits, `+`, `-`, `.`, and the scheme is at the start of the
   text or preceded by a character that cannot be part of a scheme —
   `backslashEnds = FALSE`;
2. if `text`, after leading white space, starts with such a scheme followed by
   `:` and **not** `//` — the part after the `:`, `backslashEnds = TRUE`;
3. if `text`, after leading white space, starts with `//` — the part after it,
   `backslashEnds = FALSE`.

Returns TRUE when anything was removed. A one-character scheme (`C:`) is never
a scheme.

## C3 — `SalStripHistoryPasswords(char** history, int count, BOOL (*strip)(char*))`

For a most-recent-first history array of `malloc`ed strings: applies `strip`
to every entry; then removes every entry equal (byte-exact) to an earlier one,
`free`ing it; then moves the remaining entries up so that no NULL precedes a
non-NULL entry (`SaveHistory` stops at the first NULL). Returns TRUE when the
array changed.

The array is owned by the caller's module; C3 is compiled into that module, so
`free` matches the allocation.

## C4 — where it is applied (the only places)

| Site | What |
|---|---|
| `dialogs3.cpp` `CChangeDirDlg::Transfer` | C3(C2) on `ChangeDirHistory` after the add |
| `dialogs3.cpp` `CCopyMoveDialog::Transfer`, `CCopyMoveMoreDialog::Transfer` | C3(C2) on the dialog's history after the add |
| `finddlg1.cpp` `CFindDialog::Transfer` | C3(C2) on `FindLookInHistory` after `HistoryComboBox` stored it |
| `editwnd.cpp` command-line execution | C3(C2) on `EditHistory` after the add |
| `zip.cpp` `CSalamanderGeneral::AddValueToStdHistoryValues` | C3(C2) when the array is `CopyHistory` or `ChangeDirHistory` |
| `mainwnd2.cpp` `LoadConfig` | C3(C2) on the four arrays above after `LoadHistory` |
| `ftp/dialogs1.cpp` Quick Connect `Transfer` | the Address text written back before `HistoryComboBox` is `LastRawHostAddress` with C1 applied after the FTP/FTPS prefix and `//` |
| `ftp/ftp.cpp` `LoadConfiguration` | C3 with the FTP address rule on `HostAddressHistory` |

The value handed to the operation (the panel path, the copy target, the
command, the Quick Connect connection data) is never passed through C1–C3.

## C5 — invariants (tested in `saltests`, `TestUrlPasswordStrip085`)

- no input grows; output is always a valid C string;
- a text without `@` is returned byte-identical;
- applying C2 twice equals applying it once (idempotent);
- valid UTF-8 in, valid UTF-8 out.
