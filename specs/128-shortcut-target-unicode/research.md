# Research: feature 128 (GitHub issue #8)

## R1 - Finding the cause from a picture

The report shows a shortcut `ARCHIV.lnk` and the box `(123) Název souboru či adresáře nebo
jmenovka svazku je nesprávná.` - `ERROR_INVALID_NAME`, without a path. A box with only an error
text comes from the path check (`CheckPath` with its echo) in `CFilesWindow::Execute`
(`src/fileswn2.cpp`), which runs on the path returned by `link->GetPath`. The link interface
there was `IShellLink` - in this code base (no `UNICODE`) that is `IShellLinkA`: the target
arrives in the system code page, letters outside it as `?`. The core treats the bytes as UTF-8;
code-page bytes of an accented letter are not valid UTF-8, the wide conversion fails and the
check reports an invalid name.

Feature 069 (F-P1-25) described exactly this in `src/shellsup.cpp` ("IShellLink (the A
interface) returned the TARGET in the code page, which the strict SalGetFileAttributes below
then rejected") and moved the **drop-target** code to `IShellLinkW`. The Enter route and
`FocusShortcutTarget` (`src/fileswn0.cpp`) kept the A interface.

## R2 - Measurement

`probe/lnk_probe.ps1` on 0.1.9 (`probe/lnk_result_before_v019.txt`), shortcuts written with
`IShellLinkW` (WScript.Shell refuses a Greek target: "value out of range"):

| Row | 0.1.9 |
|---|---|
| ENTER 1 ASCII | PASS |
| ENTER 2 Czech letters | FAIL - the report's box, word for word |
| ENTER 3 Greek | FAIL - the same |
| ENTER 4 Czech + Greek, deeper | FAIL |
| ENTER 5 ASCII target, accented shortcut name | PASS |
| ENTER 6 UNC path with Czech letters | FAIL |
| GOTO 2, 3, 7 | FAIL - "Cannot obtain shortcut target or target path is not accessible." |

- **Decision**: the cause is the A interface on these two routes; the fix is the wide one.

## R3 - One rule

- **Decision**: `SalShellLinkGetPathU8(IShellLinkW*, char* path, int pathSize, DWORD flags)` in
  `src/common/salshelllink.h` (header-only so that `saltests` runs it on real shortcuts): wide
  `GetPath` into a heap buffer of 32,768 units, `SalWToU8` into the caller's buffer. NOERROR =
  the whole path; `S_FALSE` = the shortcut has no path (also when the shell answers success
  with an empty string); failure when the path does not fit - the buffer is emptied, never a
  cut path (CLAUDE.md, 097/098/101).
- The two call sites pass their real buffer sizes (`SAL_MAX_PATH_UTF8`) instead of `MAX_PATH`.
- `shellsup.cpp` and `shellib.cpp` keep their own (already wide) code; moving them to the
  helper is tidy-up, not part of the report.

## R4 - Tests

- saltests `TestShellLink128`: for four folders (ASCII; Czech; Greek; Chinese with an emoji) a
  real shortcut is written and read back: the helper's path equals the expected UTF-8 path
  exactly, names an existing folder for `SalGetFileAttributes`, fits a buffer of exactly its
  size and is refused (empty buffer) one byte short; the A interface is asked too and its
  answer differs from the path for the non-ASCII cases (the defect, kept visible); a shortcut
  without a path; NULL arguments.
- The probe, before and after: Enter on six shortcuts, *Go to Shortcut Target* on three, exact
  locations read from the Change Directory field, no error window, clean exit.
- Not driven: a real mouse double-click (Enter runs the same `Execute`); the reporter's own
  shortcut.
