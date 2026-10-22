# Research - feature 306

## R1 Record syntax and precedence

- **Decision**: records `"%d %s=%s\n"`; the length counts the whole record including itself and
  the newline. Member (`x`) values beat global (`g`) values, both beat the classic header and a
  GNU long name. An empty value cancels the keyword (member: the global value does not apply;
  global: the global value is removed). The last record of a keyword wins. NUL bytes after the
  last record end the data.
- **Rationale**: POSIX.1-2001 `pax` "Extended header" rules; Python `tarfile._proc_pax` and GNU tar
  `xheader_decode` behave the same; NUL tolerance costs nothing.
- **Alternatives**: applying only `x` (rejected - the item names `g`).

## R2 Errors

- **Decision**: a malformed record or an invalid `size` refuses the archive with
  `IDS_TARERR_HEADER` (TAR_ERROR, like a malformed GNU long name). Extended header data over
  1 MiB: same. An invalid / out-of-range `mtime` is ignored (the classic time stays).
- **Rationale**: a wrong size or name desynchronises or misnames every later member - refuse
  rather than guess (stop-rules §1.4); a time does not; Python sets 0 and GNU tar warns.
- **Alternatives**: skipping the bad header (rejected: would read on under the fallback name -
  the defect itself).

## R3 Time

- **Decision**: `[-]digits[.digits]`; seconds floor + 100-ns fraction (first 7 digits, the rest
  dropped); accepted range -11644473600 (1601-01-01) to 910692730085 (the largest FILETIME
  second). The reader's existing conversion (`+11644473600`, `*10^7`) works on unsigned 64-bit
  arithmetic, so a negative second stored as its two's complement converts correctly; the
  fraction is added after the multiplication.

## R4 Refusal of a name no file system takes

- **Decision**: after the name is decoded to UTF-8 and normalised, a member whose name came from
  a PAX `path` and has a component over 255 UTF-16 units (`SAL_NAME_MAX_UTF16_UNITS`, the rule of
  `SalNameTooLongForFileSystemU8`) gets `Ignored`; the first such member of a listing or a
  whole-archive unpack shows `GetErrorText(ERROR_FILENAME_EXCED_RANGE)` + the path, title
  `IDS_TARERR_TITLE`.
- **Rationale**: measured - the same name as a GNU long name crashes the core while listing;
  feature 260 refused a gzip name the same way with the same text. Per-member skip keeps the rest
  (clarification 1).
- **Alternatives**: refusing the archive (loses every other member); the GNU route too (outside
  the item - Inbox).

## R5 Where values live

- **Decision**: global values in `CArchive` (reset when `ReadArchiveHeader` is called with
  `probe == TRUE`, the first header of every pass: `ListArchive`, `UnpackOneFile`,
  `DoUnpackArchive`); member values local to one `ReadTarHeader` call (the `x` header and its
  member are read in the same call, as `L` + member are).

## R6 Writers measured

- Python 3.14 `tarfile` (PAX default): `x` header named `././@PaxHeader`, fallback name cut at
  100 bytes, non-ASCII as `?`. GNU and Windows `tar.exe` (bsdtar) write the same record syntax.
