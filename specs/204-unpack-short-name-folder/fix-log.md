# Fix log: 204 - An archive's folder is never unpacked into another folder by its short name

Found while measuring 203: an archive member whose folder part is only the short (8.3) name of
another folder in the target goes INTO that folder - Windows resolves the path through the short
name, and no create path is asked (the member's folders already "exist").

## Measured (before)

Probe `probe/unpack_dir_probe.ps1` (158's driver; short names are made on C:), F5 out of the
archive, run with `-Expect103`. The build at 203 (`probe/result_before.txt`, 6 / 4 + the TAR row
re-run after a fixture fix, 1 / 1):
- **zip-dir** (ZIP member `LONGDI~1/a.txt`, no folder entry, next to a folder `longdirname` holding
  `keep.txt`): no question - `a.txt` unpacked into `longdirname`;
- **zip-entry** (entries `LONGDI~1/` and `LONGDI~1/a.txt`): the same;
- **zip-deep** (`LONGDI~1/sub/a.txt`): `sub` made inside `longdirname`;
- **zip-same** (`LONGDI~1/keep.txt`): "Confirm File Overwrite" under the member's path, and Yes
  **replaced the content of `longdirname\keep.txt`**;
- **tar-dir** (TAR, `LONGDI~1/a.txt`): into `longdirname`;
- typed (the control: target typed `tgt\LONGDI~1\`, member `x.txt`): lands in `longdirname`, as
  the user's own short name says - this must stay.

## Work

- `src/plugins1.cpp`: `CPluginData::UnpackArchive` / `UnpackWholeArchive` hold a
  `CUnpackRootScope` for the target folder (a heap copy under an SRW lock - plug-ins' worker
  threads read it, 7-Zip's; nesting restores the previous one).
- `src/salamdr3.cpp` `MakeUnpackFoldersOwn`: below that root (`SalPathIsWithinOrdinalCI`), every
  existing component of the path found only as another entry's short name
  (`SalNameIsOnlyShortNameOf`, `salshortname.h`) is created as the member's own
  folder by `SalCreateDirectoryEx` (the other entry moved aside and back - 203); a failure is
  reported with the step's error, never "it exists". Above the root (the typed target) nothing.
- Called at the start of the core's `CheckAndCreateDirectory` (plug-ins' folders - ZIP, 7-Zip,
  UnISO) and of `SafeFileCreate`'s loop (`src/safefile.cpp`, the files' folders; for `isDir` the
  last component too - unrar, tar); a failure shows the create-folder error (Retry / Skip / Skip
  all / Cancel, `SILENT_SKIP_DIR_CREATE`).

Build: BUILD SUCCEEDED; saltests 22,387 / 0 (22,402 after the review).

## Measured (after)

`probe/result_after.txt` 22 / 0 (the final build, after the review; the f9-zip row first failed on
the probe itself - typing the archive into Change Directory opened it - and passed once the probe
focused it instead): every member in a folder
`LONGDI~1` of its own, `longdirname` holds only `keep.txt` with its content - ZIP (zip-dir,
zip-entry, zip-deep, zip-same), TAR, 7-Zip (7z-dir: the folders made on the plug-in's own thread),
Alt+F9 (f9-zip, `UnpackWholeArchive`; its row was added after the review and was not measured on
the build before), a SUBST drive's root as the target (root); zip-held / 7z-held (a file in
`longdirname` held open, so it cannot be moved aside) - an error, nothing unpacked into
`longdirname` (two boxes: ZIP's own "Cannot create directory" from its `errBuf`, then
`SafeFileCreate`'s "(5)" for the member; 7-Zip: two "(5)"); typed - still into `longdirname`.
Regressions: 203's probe 14 / 0 (its zip-dir row now passes), 110's ZIP probe 42 / 0, 113's 37 / 0.

## Review

Refute-first review: sound for the routes measured, no CRITICAL. Checked: every core route into a
plug-in's unpack is scoped (F5 and its drag and drop and the paste to Explorer through
`PackUncompress`, Alt+F9 through `UnpackWholeArchive`); `UnpackOneFile` needs no scope (every
plug-in writes the bare name into `targetDir` - covered by 203); the typed target is created before
the scope; a trailing backslash, `C:\`, `C:` and UNC targets match; the walk cannot loop, closes its
handle, never touches anything above the root; 7-Zip's worker ends before `UnpackArchive` returns;
FAT, case-sensitive folders, NFC / NFD, wildcards and trailing dots fail open to the old handling.
Taken: (1) a directory search per existing folder of every file (ZIP twice) - components that
cannot be an 8.3 name (more than 8 + 3 characters, two dots) are never looked up
(`SalNameCanBeShortName`, 15 saltests checks); (2) the routes not driven - the rows 7z-dir, 7z-held,
f9-zip, root added and passing; `CUnpackRootScope` cannot be copied (it would free the root
twice); (3, from a NIT) the root is process-wide, so a create under it from elsewhere during an
unpack is walked too - with a target `C:\` or `C:\Users` and a `%TEMP%` given in short form, a
plug-in's temporary file would have made the walk try to move the real profile folder aside: the
walk starts below the temporary folder when the path lies in it (not driven - re-measured 22 / 0).
NITs recorded: other creates under the root during an unpack (none found in the tree); ZIP's Skip after its own folder error
still creates the file (the second box - before 204 too); an old archive that stored short names
(`MYDOCU~1/...`) restored over the original now gets a folder of its own instead of merging - the
intent, said in the changelog; the walk splits on `\` only (a third-party plug-in passing `/`
keeps the old handling); fail-open when memory is low or a search fails other than "not found";
`SafeFileCreate`'s box names the file under "Error creating directory"; an external archiver's
unpack (`PackUniversalUncompress` -> `MoveFiles`) relies on 201 / 203, not driven.
