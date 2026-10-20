# Fix log - 273-tar-case-root

From backlog item `copying-from-a-tar-folder-opened-in-another-case-extracts` (review:252): copying
from a TAR folder opened by a path typed in another case extracts nothing.

## Measurement before (main at ff3cd942)

- `build.cmd` (Debug x64): up to date, nothing rebuilt.
- Probe `probe/arccase273_probe.ps1` (built on 252's `arc252_probe.ps1`; TAR by Windows tar.exe,
  7z by 7-Zip with `-ssc`, fixtures in case-sensitive folders under %TEMP%), run on the hidden
  desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ... -CommandLine "powershell ... -File arccase273_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"`
  -> `probe/result_before.txt`: PASS 8, FAIL 4 (6 END rows PASS).
  - TAR-COPY (Docs\f.txt, opened `t.tar\DOCS`): FAIL - panel at `t.tar\DOCS`, the Copy dialog
    "Copy file f.txt", target **empty**, no error. The item's defect.
  - TAR-DEEP (Docs\Sub\g.txt, opened `t.tar\dOCS\SUB`): FAIL - target empty.
  - 7Z-COPY / 7Z-DEEP: the file arrives (7-Zip extracts by item); FAIL only on the new
    expectation that the panel path is spelled `Docs` (`Docs\Sub`).
  - TAR-TWINS / 7Z-TWINS (folders Docs and DOCS, listing case-sensitive since 252, opened
    `DOCS`): PASS - control.
  - Registry restored, SHA-256 identical.

## Reading (sites and consumers)

- The panel's path inside an archive is set only by `CFilesWindowAncestor::SetZIPPath`; callers:
  `src/fileswn2.cpp` - `ChangePathToArchive` (the typed path, then its shortenings) and one reset
  to "" (closing the archive). Every other path change into an archive (Enter on a folder, `..`,
  history, hot path, command line, Change Directory, refresh) goes through `ChangePathToArchive`.
- The path is resolved in the listing by `CSalamanderDirectory::GetFiles` / `GetDirs` /
  `GetSalamanderDir` (`src/zip.cpp`) with `SalDirStrCmpEx`: `StrCmpEx` when the listing is
  `SALDIRFLAG_CASESENSITIVE`, else `StrICmpEx` - a byte-by-byte fold through `LowerCase`, so names
  it finds equal have equal byte length.
- `GetZIPPath()` reaches the archive plug-ins as `archiveRoot` (UnpackArchive, UnpackOneFile,
  PackToArchive, DeleteFromArchive) and is shown in the directory line, Change Directory and the
  history. TAR builds `archiveRoot\name` and matches bytes (the defect); UnCAB / UnISO also take it
  (not measured); 7-Zip and ZIP use it when packing into the folder.

## Decision

The core stores the path inside the archive in the listing's own spelling after a successful
case-insensitive path change (the item's first Approach; fixes all plug-ins, no interface change).
Recorded in spec.md *Assumptions*.
