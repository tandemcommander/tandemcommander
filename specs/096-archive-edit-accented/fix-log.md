# Fix log: feature 096 - edited files with non-ASCII names

Branch `096-archive-edit-accented`, from `095-archive-path-buffers`.

## Measurement

`research.md`; `probe/archedit_result_Debug_x64.txt` and
`..._pre094.txt`: in 10 of 17 cases - every name with a non-ASCII character,
ZIP and 7z, on leaving the archive, on closing the program and for a file
opened by Enter - no Archive Update question, archive unchanged, temporary
copy deleted. Cause: `FindFirstFile` (code page) on the UTF-8 path
`SourcePath\FileName` in `CFileTimeStamps::CheckAndPackAndClear`; unchanged
since the Open Salamander import, wrong since feature 004 made the paths
UTF-8 (in v0.1.0 ... v0.1.8).

## Fix (`src/salamdr3.cpp`)

- `CheckAndPackAndClear`: `SalFindFirstFile` + `WIN32_FIND_DATAW`; an item
  is dropped only when the file did not change or is not there
  (`ERROR_FILE_NOT_FOUND`, `PATH_NOT_FOUND`, `NO_MORE_FILES`, `INVALID_DRIVE`,
  `DIRECTORY`, `BAD_PATHNAME`); any other failure keeps it; a kept item that
  was never seen gets normal attributes and size 0; bounded path buffer;
  `SetCurrentDirectoryW` through `SalU8ToW` before packing.
- `AddFilesToListBox`: the list of the Archive Update dialog has room for a
  deep inner path plus a long name (it showed only the folder).

## Evidence

Probe on the hidden desktop, fixed build (`probe/archedit_result_fixed.txt`):
17 of 17 cases - Archive Update shown, archive holds the edit, temporary copy
deleted afterwards. Debug and full Release builds without errors; saltests
13,102 checks, 0 failed (none of this is reachable from the test program,
which links only `src/common`); strict guard TOTAL: 0. Registry key identical
before and after.

## Independent review - ACCEPT

Checked by reading: the item fields from the wide find data, the enumerator
handing UTF-8 names to the packer, the external packer's UTF-16 list file,
critical shutdown (a kept item prevents the deletion of the copies), no loop
(the list is destroyed at the end; a kept unreadable item asks once per
leave), the handle-tracker pattern, BOM and CRLF. Done after it: the wider
"not there" error set, sane values for a never-seen kept item, the list-box
buffer.

Handed to feature 097 (they become reachable only when archive paths over
259 bytes are let through): `strcpy(ZIPFile, zipFile)` into `char
ZIPFile[MAX_PATH]` (`CFileTimeStamps::AddFile`), and the external packer's
buffers in `pack2.cpp`.

Not driven: the RAR external packer with an accented name; a critical
shutdown with an edited accented file; an accented `%TEMP%` (the probe row
could not redirect the temporary folder).
