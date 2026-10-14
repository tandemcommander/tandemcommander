# Fix log: 172 - the core's code-page file dialogs

Backlog: NEXT-WORK item 19, "configuration export's start folder" (the A dialog of the export),
widened by measuring to every code-page file dialog of the core.

## Measured (before)

Probe `probe/save_dialogs_probe.ps1` on the hidden desktop, ACP 1250, the build at 168
(`Debug_x64_pre169`; these dialogs had not changed since): 16 PASS / 10 FAIL
(`probe/result_before.txt`).

- **Options > Export Configuration**: an ASCII name and a Czech name (inside 1250) were saved; a
  Cyrillic name and an ASCII name in a Cyrillic folder failed - "Unable to export configuration to
  the file ... `??????.reg`" (the A dialog turned the letters into '?').
- **The viewer's Copy to File**: refused EVERY name with a letter outside ASCII - also Czech - with
  "(123) The file name is incorrect": the A dialog returns code-page bytes, the consumers are
  UTF-8. A Cyrillic folder failed the same way; the overwrite of an existing Czech name and a name
  of 280 UTF-8 bytes too. The suggested name of a source `žluťák.dat` was shown as `Ĺžluĺ...`
  (the viewer's UTF-8 name through the code-page dialog).
- **The viewer's Open File**: a file with a Czech name (or in a Cyrillic folder) failed with 123
  and the viewer was left without its file (title "Viewer").

First runs of the probe (before it knew the Vista dialog's name field) took the save dialog for
a question and clicked Save: `%APPDATA%\Tandem Commander\config_.reg` was written (the folder was
created by the export, 22:02:26). Both removed (the folder held only that file); the probe now
answers only the two known boxes, cancels anything else and checks the folder at the end
("APPDATA: unchanged / removed").

## Work

- `src/mainwnd3.cpp` CM_EXPORTCONFIG: `SafeGetSaveFileNameW`, the start folder UTF-8 -> wide (the
  roaming folder; the pre-Vista branch from `SalGetModuleDirU8` - item 19's A
  `GetModuleFileName`), the result UTF-8, `SalGetFullName` with the buffer size, `SalDeleteFile`.
- `src/reglib/src/reginmem.cpp` `CMemoryRegistry::Dump`: `SalCreateFileNH` in the core's build
  (`INSIDE_SALAMANDER`, not `_UNICODE`); `regparse.h` says the name is UTF-8.
- `src/salamdr2.cpp` `ShowFileError`: the message on the heap (`CSalHeapString::Printf`), the
  whole name.
- `src/viewer3.cpp` CM_COPYTOFILE: the wide dialog, the viewed file's name as the suggestion,
  `fileName` / `tmpFile` / `path` of `3 * 2 * MAX_PATH + 1` bytes (the UTF-8 of anything the
  dialog returns), `SalGetTempFileName` with the size, the "already exists" text on the heap, the
  change notification's folder never cut. CM_OPENFILE: the wide dialog, `CurrentDir` to wide.
- `src/execute.cpp` `BrowseCommand` (the *Browse...* item of the execute menus, the compare
  names, Change Icon): `GetOpenFileNameW`, the field read and written as UTF-8; a name of
  `MAX_PATH` bytes or more is refused (`IDS_TOOLONGPATH`) - the fields keep `MAX_PATH` bytes
  (review). `BrowseDirCommand` (review): the field as UTF-8 both ways (`GetTargetDirectory` takes
  and returns UTF-8 - a folder with accents came back garbled).

No string, interface or registry change. Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Measured (after)

The same probe on the fixed build: 26 PASS / 0 FAIL (`probe/result_after.txt`), registry
identical, `%APPDATA%` unchanged. Not driven: `BrowseCommand` / `BrowseDirCommand` (reached
through popup menus) - a person step: Configuration > User Menu > Command > Browse..., a program
in a folder with accents and one in a Cyrillic folder.

## Review

Independent refute-first review (read-only): nothing CRITICAL; buffer lengths after
`SalGetFullName`, `goto ENTER_AGAIN` across the new declarations, `defDirW` on every path,
`SafeGetSaveFileNameW`'s retry, `LoadStrW` lifetimes, stack (smaller than before) checked.
- SHOULD-FIX, taken: `BrowseCommand` could hand a `MAX_PATH` field a longer name that its reader
  cuts - refused now.
- NIT, taken: `BrowseDirCommand`; the stale comment in `dialogs4.cpp`; the guard in
  `reginmem.cpp` (`INSIDE_SALAMANDER` - the standalone `REGLIBA.vcxproj` keeps compiling).
- Recorded in NEXT-WORK (older, reached by more names now):
  - the viewer's Copy to File overwrites by deleting the user's file and then moving the
    temporary file in - a failed move loses the original (rule 105: `SalReplaceWithTempW`);
  - a failed export deletes the user's existing `.reg` file even when nothing was written
    (`CopyBranch` failed), and `Dump` truncates it with `CREATE_ALWAYS` before writing;
  - the export writes values outside the code page as '?': reglib reads with A registry
    functions (`RegEnumValueA` / `RegQueryValueExA`, `registry.cpp`) while the core stores UTF-16
    (`SalRegSetValueExW8`), and writes a REGEDIT4 (code-page) file.
- Accepted: no `OFN_NOCHANGEDIR` on the export dialog (as before); the retry after
  `FNERR_INVALIDFILENAME` drops the suggested name (as the A wrapper did).
