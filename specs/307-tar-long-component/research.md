# Research - feature 307

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

- Decision: flag `NameFromGnuLong` set when a `GNUTYPE_LONGNAME` header supplied `header.Name`;
  the feature-306 check runs when `NameFromPax || NameFromGnuLong`. A later PAX path replaces the
  name (both flags may be set; the check applies to the effective name either way).
- Rationale: the same refusal and message as 306 (item *Expected*); classic ustar names cannot
  exceed the bounds (100 + 155 bytes), other formats unchanged (scope).

## R5 7-Zip fixture

- Decision: made with the installed `C:\Program Files\7-Zip\7z.exe` (22.01): `7z a -t7z t.7z
  -si<name>` takes the member name from the command line and the data from stdin, so a name no file
  system holds can be stored (tried: `7z l -slt` shows the 304-unit path). The probe row is
  NOT DRIVEN when 7z.exe is missing. ZIP row made with Python `zipfile`.
