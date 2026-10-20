# Research: 259 - long names

## R1 - What limit does a copy name have?

- **Decision**: 255 UTF-16 units (`SalNameTooLongForFileSystemU8`, feature 222), counted on the whole
  candidate; the candidate's full path additionally below `SAL_MAX_PATH_UTF8`.
- **Rationale**: it is the limit NTFS / exFAT / FAT32 apply to a component; the old 259-byte limit
  refused valid CJK names and let invalid long ASCII names fall to "to itself".
- **Alternatives**: shortening the name to fit (cuts a name - forbidden by the standing rule);
  bytes (wrong unit, 222).

## R2 - What does the user see when the copy name is too long?

- **Decision**: `BuildName(targetDir, sourceName, NULL, &skip, &ErrTooLongTgtNameSkipAll,
  sourcePath, TRUE)` - the existing question "Name "%s" with full path is too long." with Skip /
  Skip all / Focus / Cancel; Skip goes on with the next item, Cancel / Focus ends the build.
- **Rationale**: feature 141 uses it for a mask result no file system takes - the same situation
  (an operation-made target name that cannot exist); no new string (no `.slt` refresh).
- **Alternatives**: `IDS_TOOLONGNAME` box and end of operation (no per-item choice); a new string.

## R3 - Edit New File: accept or state the limit?

- **Decision**: accept long paths (`SalGetFullName(..., SAL_MAX_PATH_UTF8)`, `checkPath`
  `SAL_MAX_PATH_UTF8`), as Create Directory (027). Every consumer was checked: `CheckPath`,
  `FileNameInvalidForManualCreate`, `SalCreateFileEx` (W API, long-path) and `EditFile` (012) take
  long paths; `NextFocusName` (780 bytes) is filled by `SalGetFullName` only for names under 260
  bytes - a longer new name is not focused (a limit, no data issue).
- **Rationale**: the program supports such paths everywhere else; refusal loses the user's work.
- **Alternatives**: keep the refusal and only state it (the item's second option - weaker).

## R4 - IsSimpleSelection without code page

- **Decision**: wide names: `SalWToU8Alloc` (WTF-8, never fails on a real name) - NULL (low
  memory, or an empty component of a malformed list) refuses the selection (`ret = FALSE`); the
  common folder too long for `SrcPath` -> `SrcPathTooLong`. ANSI list: the CP_ACP decoding stays
  (that is the list's encoding); its raw-bytes fallbacks and the `lstrcpyn` cut are replaced by
  the same refusal / flag.
- **Rationale**: no code-page or cut name ever reaches the operation; "too long" is told as such.
- **Alternatives**: keep CP_ACP as a last resort (wrong name - an operation on another file).

## R5 - The pre-Vista copy patterns ("Copy of x", "Copy (2) of x")

- **Decision**: unchanged except that "the result does not fit" sets the too-long flag; a guard
  keeps their 260-byte writes inside `targetPath` (only reached on Windows before Vista, which the
  product does not run on).
