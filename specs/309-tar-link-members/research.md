# Research - 309-tar-link-members

## R1 - Copy or NTFS hard link

- **Decision**: a copy of the target's bytes, written through `SalamanderSafeFile->SafeFileCreate`
  (the overwrite question, Skip, Cancel of every extracted file).
- **Rationale**: works on every target file system (FAT32, exFAT, SMB shares); `CreateHardLinkW` fails on FAT and on many shares and would need a second error path;
  two linked files would silently change together when the user edits one. The item allows either.
- **Alternatives**: `CreateHardLinkW` with a copy fallback - two behaviours for one archive depending on
  the target file system; rejected (conservative).

## R2 - Where the link name comes from

- ustar header `linkname[100]` (not NUL-terminated when full); GNU tar puts longer names into a
  preceding 'K' (`././@LongLink`) member (read and discarded today); PAX puts them (and every non-ASCII
  name) into the `linkpath` record of the 'x' header - Python writes the ustar field as a '?' fallback
  then (measured: `????...tx`). Precedence as for names: PAX member > PAX global > GNU 'K' > ustar.
- Decoding: the same `ConvertNameToU8` as member names (UTF-8 kept, legacy bytes from the ANSI code
  page), then the same normalization (`/` and `\` to `\`, `.` and `..` resolved, a leading separator
  dropped) - `./a.txt` and `a.txt` are one name. The normalization loop moves unchanged from
  `ReadArchiveHeader` into `saltarlink.h` so both use one rule and saltests cover it.

## R3 - "Written in this operation"

- `DoUnpackArchive` keeps a `std::unordered_set<std::string>` of the normalized archive names of the
  files `WriteOutData` created and closed (not skipped, not simulated) and of reproduced links.
  A link to a name not in the set (not in the archive, after the link, outside the mask / selection,
  skipped by the user, a folder) is reported.
- The source path of the copy is built like any member's path: target folder + the name below the
  archive root (a written name always starts with the root).
- `<string>` / `<unordered_set>` go into `precomp.h` before the Debug `new` macro (the macro would break
  placement new in the STL headers).

## R4 - Never damage the target

- The source is opened `GENERIC_READ`, share mode `FILE_SHARE_READ` only: nothing - also not
  `SafeFileCreate` on an alias of the same file - can open it for writing while it is copied.
- When the destination exists and `SalFileIdMatch` (salsamefile.h, 103) says it is the source (case
  twins `A.TXT` / `a.txt`), nothing is written and the link counts as reproduced. When identity is
  unknown, `SafeFileCreate` meets the sharing violation and shows its error box (Skip / Cancel) - never
  a truncation.

## R5 - The report without new strings

- `CArchive::ReportLinkMember(name, linkName, err)`: `GetErrorText(err)` + blank line + `name -> linkName`,
  title `IDS_TARERR_TITLE`, once per operation (`LinkReportShown`), like `ReportRefusedName` (306/308).
  `err`: a symbolic link `ERROR_NOT_SUPPORTED` ("The request is not supported."), a hard link whose
  target was not written `ERROR_FILE_NOT_FOUND`, a source that cannot be opened its own error.
- New strings would need the two-stage `.slt` refresh (a maintainer step, CLAUDE.md 084).

## R6 - Callers (enumerated)

- `DoUnpackArchive`: `UnpackArchive` (Copy, drag and drop, `src/fileswn7.cpp`, `src/salshlib.cpp`),
  `UnpackWholeArchive` (Alt+F9), `deb.cpp` (both parts). A FALSE from Copy keeps the selection; nothing
  extracted is deleted (308 review).
- `UnpackOneFile`: link members are not listed, so not reachable from the panel; made consistent
  (report + FALSE instead of TRUE with nothing extracted).
- `ListArchive`: unchanged (link members stay `Ignored`).
- cpio (`ReadNewASCIIHeader` & co. through `ReadArchiveHeader`, `CpioDoUnpackArchive` for rpm):
  `LinkType` stays 0 - unchanged.
