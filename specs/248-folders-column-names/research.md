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

- **Decision** (revised after the first review): the header-only rule `SalWToCodePageWhole`
  (`src/common/salcpfit.h`, saltests `TestCpFit248`): `WideCharToMultiByte(CP_ACP,
  WC_NO_BEST_FIT_CHARS)` with an explicit length, one whole character less while the result does
  not fit (`ERROR_INSUFFICIENT_BUFFER`); no flag on the UTF-8 / UTF-7 system code page, and a retry
  without it on `ERROR_INVALID_FLAGS`; a torn high surrogate at the end is dropped; a buffer of
  fewer than 2 bytes gives an empty result (a size of 0 would make the call return the needed size
  instead of failing). First version: a direct call with `-1`, empty on failure.
- **Rationale**: the plug-in runs in the core's process, so `CP_ACP` is the code page the header
  draws in. `WC_NO_BEST_FIT_CHARS` maps a character outside the code page to the default
  character (`?`) instead of a lookalike letter (spec FR-004, Clarifications). The rule converts an
  explicit length into `bufSize - 1` bytes and writes the terminator itself; when the result does
  not fit, the function fails with
  `ERROR_INSUFFICIENT_BUFFER` and returns 0, so the rule retries one whole character shorter -
  never a half double-byte character (FR-005).
- **Alternatives considered**: `StrRetToBufA` (upstream) - best-fit and a byte cut that can split a
  double-byte character; best-fit flag `0` - would show e.g. "e" for "ě" on a 1252 system (a
  different word, against the project's stance on best-fit, 104).

## R3. Length

- **Decision**: `StrRetToBufW` into `WCHAR[COLUMN_NAME_MAX]` keeps at most 29 UTF-16 units
  (unchanged; it may tear a surrogate pair - the rule drops the torn half). A code-page form longer
  than 29 bytes (double-byte code pages) is cut at a whole character.
- **Rationale**: `CColumn::Name` must not be empty (`spl_com.h`); CLAUDE.md: a text that must be
  shortened is cut at a whole character. The first version left such a name empty (review SHOULD 2).

## R4. A pure-decision header with `saltests`?

- **Decision**: yes, after the first review: once the conversion had to shorten at a whole
  character it became a rule of its own - `src/common/salcpfit.h`, header-only (plug-ins cannot
  compile a `.cpp` of `src/common`), checked by `TestCpFit248` in `src/saltests/saltests.cpp`
  (the names of issue #13, no best-fit in 1250 / 1252, cuts in 1250 and 932, surrogate pairs,
  UTF-8, edges). The first decision, "none" (one system call), is replaced.
