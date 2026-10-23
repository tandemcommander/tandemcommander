# Research - feature 321 (R1-R5 from the first run, 307)

## R1 Where the stack overflows

- Decision: `CFilesWindow::RefreshListBox` (`src/fileswn2.cpp`) - `char formatedFileName[SAL_FIND_NAME_U8]`
  (780 bytes), filled by `AlterFileName(formatedFileName, f->Name, f->NameLen, ...)` for every
  listed name (brief and detailed views); `AlterFileName` copies `NameLen + 1` bytes. The same
  buffer size is used by many other `AlterFileName` callers (`filesbx1.cpp`, `fileswn5.cpp`,
  `fileswn8.cpp`, `fileswna.cpp`, `filesmap.cpp`, `fileswn0.cpp`, `plugins3.cpp`).
- Rationale: matches every measured length - 604 and 769 bytes list, 904 bytes crash - and the
  call stack: `CommonRefresh` calls `RefreshListBox`; its call-stack message is a local object
  destroyed before the function's epilogue, where the run-time check finds the corrupted frame,
  so the innermost message reported is `CommonRefresh`.
- How the name got there: the member lies at the archive root, `ReadArchiveHeader` sets
  `header.Path = NULL`, `ListArchive` calls `AddFile(NULL, ...)`, and `AddFile` evaluates its
  bound only under `path != NULL`.

## R2 Fix the buffers or bound the names

- Decision: bound the names - with no folder part, refuse `NameLen >= SAL_FIND_NAME_U8`.
- Rationale: the listing already enforces exactly this bound for entries with a folder part
  (feature 222), so every panel buffer sized `SAL_FIND_NAME_U8` was designed for it; one check
  covers every plug-in. Making every buffer that a name reaches dynamic is dozens of sites in the
  core (drawing, quick search, rename, info line, operations) - a feature of its own; the item
  allows "and/or".
- Alternatives: (a) apply the whole feature-222 rule (255 UTF-16 units) also without a folder
  part - rejected: FS plug-ins list registry value names (up to 16383 characters) and FTP names
  over 255 units today; they would vanish or fail. (b) widen only `RefreshListBox`'s buffer -
  rejected: the next buffer overflows.

## R3 What a refusal does in each plug-in

- tar: `ListArchive` shows "Internal error: file data structure corrupted." and fails the listing
  (only reachable now for a non-GNU, non-PAX name of 780+ bytes - impossible for ustar); with the
  GNU refusal the member never reaches `AddFile`.
- FS plug-ins: regedt / nethood / undelete ignore the result (the entry is just missing); FTP /
  SFTP / folders / portables report or abort the listing. All better than corrupting the stack;
  no such name occurs in normal use (Linux: 255 bytes per component; Windows: 765 bytes).
- ZIP: lists with a folder part (feature 222 already skips a too-long item).

## R4 GNU long names in the tar reader

- Decision: flag `NameFromGnu` set when a `GNUTYPE_LONGNAME` header supplied `header.Name`;
  the feature-306 check runs when `NameFromPax || NameFromGnu`. A later PAX path replaces the
  name (both flags may be set; the check applies to the effective name either way).
- Rationale: the same refusal and message as 306 (item *Expected*); classic ustar names cannot
  exceed the bounds (100 + 155 bytes), other formats unchanged (scope).

## R5 7-Zip fixture

- Decision: made with the installed `C:\Program Files\7-Zip\7z.exe` (22.01): `7z a -t7z t.7z
  -si<name>` takes the member name from the command line and the data from stdin, so a name no file
  system holds can be stored (tried: `7z l -slt` shows the 304-unit path). The probe row is
  NOT DRIVEN when 7z.exe is missing. ZIP row made with Python `zipfile`.

## R6 The refusal per pass (the first run's review-2 MUST)

- Decision: the GNU refusal uses feature 308's `SalPaxNameUsableU8(name, isDir, prefixLen, Listing)`
  exactly as the PAX refusal does - one condition `(NameFromPax || NameFromGnu)`.
- Rationale: with the listing bound in every pass, a whole-archive Unpack of a deep GNU tree (GNU tar
  writes an `L` name for every path over 100 bytes) skipped members NTFS takes, still succeeded, and
  "Delete archive after unpacking" deleted the archive (measured by 307's review 2). 308 solved the
  same for PAX: the depth bound only in `ListArchive` (`Listing = TRUE`), only the over-255-unit
  component in `UnpackOneFile` / `DoUnpackArchive` (`Listing = FALSE`), `NameRefused` makes an
  extraction asked for the member report it and fail.
- Alternatives: a separate GNU rule - rejected, two rules for one question.

## R7 The panel's other extension copies (`src/fileswn3.cpp`)

- Decision: only the two copies into `char buf[SAL_FIND_NAME_U8]` (archive panels with simple icons,
  FS panels with simple icons) are bounded. The other three copy into `fileName[SAL_MAX_PATH_UTF8 + 4]`
  or a disk name's `nameU8[3 * MAX_PATH + 4]` (at most 765 bytes from the file system) - checked at
  HEAD, safe.
