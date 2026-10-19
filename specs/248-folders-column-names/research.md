# Research - 248-folders-column-names

## R1. In which encoding does the core read `CColumn::Name`?

- **Decision**: the Windows code page (ACP).
- **Rationale**: the core is an MBCS build (no `<CharacterSet>` in `src/vcxproj/*.vcxproj`);
  every reader of the name - `CHeaderLine::PaintItem` (`filesbx2.cpp`: `TextOut`,
  `GetTextExtentPoint32`) and the column width measurement (`filesbx2.cpp` ~344, ~401) - uses the
  `A` functions. The header context menu (`mainwnd1.cpp`), sorting (`filesbx2.cpp` ~708) and the
  view configuration (`fileswn9.cpp`) use `CColumn::ID`, never the name. The core's own column
  names come from `LoadStr` (code page); every other plug-in that inserts a column uses `LoadStr`
  or literals (7zip, ftp, sftp, regedt, undelete, zip, unrar, nethood, demoplug). FEATURE-HISTORY
  124: "column names (code page in the whole program)".
- **Alternatives considered**: make the core read the name as UTF-8 (a new interface flag or a
  version check) - rejected by the maintainer's decision of 2026-10-19 (fix in the plug-in only,
  interface unchanged).

## R2. How to convert

- **Decision**: `WideCharToMultiByte(CP_ACP, WC_NO_BEST_FIT_CHARS, colNameW, -1, col.Name,
  sizeof(col.Name), NULL, NULL)`; a result `<= 0` leaves the name empty.
- **Rationale**: the plug-in runs in the core's process, so `CP_ACP` is the code page the header
  draws in. `WC_NO_BEST_FIT_CHARS` maps a character outside the code page to the default
  character (`?`) instead of a lookalike letter (spec FR-004, Clarifications). With `-1` the
  terminator is converted too; when the result does not fit, the function fails with
  `ERROR_INSUFFICIENT_BUFFER` and returns 0 - it never leaves a half double-byte character as a
  result the code would use (FR-005); the name is then emptied as the current code does.
- **Alternatives considered**: `StrRetToBufA` (upstream) - best-fit and a byte cut that can split a
  double-byte character; best-fit flag `0` - would show e.g. "e" for "ě" on a 1252 system (a
  different word, against the project's stance on best-fit, 104).

## R3. Length

- **Decision**: unchanged. `StrRetToBufW` into `WCHAR[COLUMN_NAME_MAX]` keeps at most 29 UTF-16
  units (documented: the string is truncated to the buffer). In a single-byte code page 29
  characters always fit 30 bytes; in a double-byte code page a long name may not fit and is left
  empty, as a long non-ASCII name was left empty with UTF-8 before.
- **Rationale**: conservative (spec Clarifications); the item does not ask to change it.

## R4. A pure-decision header with `saltests`?

- **Decision**: none. The change is one system call with its flags; there is no rule of the
  program's own to test without the GUI (stop-rules §2.5 applies to pure decisions). The proof
  is the GUI probe plus a byte check recorded in the fix log.
