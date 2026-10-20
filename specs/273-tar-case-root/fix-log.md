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

## Analyze

speckit-analyze (two passes): 0 CRITICAL, 0 HIGH. MEDIUM C1 (FR-002 named Move, not tested) fixed:
FR-002 now names Copy. MEDIUM C2 accepted: FR-004 (shortening of a missing tail unchanged) has no
probe row - the shortening loop is not touched, the re-spelling runs after it on the found path,
and the rule's NOTFOUND case is checked in saltests. LOW U1 (T010 wording) accepted. Second pass:
no new findings.

## Implementation

- `src/common/salarcpathspell.h` (new, header-only): `SalArcPathRespell` walks the components of
  the path through the listing (first sub-folder equal by the listing's comparison - the lookup of
  `GetFiles` / `GetDirs`), writes the folders' own names; OK / NOTFOUND (also an empty component or
  a component below an empty folder) / TOOLONG (output too small - nothing cut).
- `src/zip.h`, `src/zip.cpp`: `CSalamanderDirectory::GetPathSpelling` - the rule over `GetDirsCount`,
  `GetDirEx`, `GetSalamanderDir(int)`, `SalDirStrCmpEx`.
- `src/fileswn2.cpp` `ChangePathToArchive`: after the shortening loop, `ZIPPath` re-spelled into a
  `CSalMaxPathBuffer` (SAL_MAX_PATH_UTF8 is ~96 KB, not for the stack) and stored when it differs;
  failure or low memory keeps the typed path.
- `src/saltests/saltests.cpp` `TestArcPathRespell273` (+ project entry).

Build attempts: 1 - saltests C2632: a local named `small` (a Windows macro, rpcndr.h) - renamed; 2 -
BUILD SUCCEEDED. clang-format reformatted unrelated lines of saltests.cpp / zip.h / zip.cpp /
fileswn2.cpp - reverted, only the new code formatted.

## Measurements after

- `.\build.cmd` -> BUILD SUCCEEDED (exit 0).
- `saltests.exe` -> `saltests: 24859 checks, 0 failed`. Negative control: the rule copying the
  typed component instead of the listed name -> 7 of the 273 checks FAIL (restored).
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Probe `arccase273_probe.ps1` (hidden desktop) -> `probe/result_after.txt`: PASS 12, FAIL 0
  (TAR-COPY panel `t.tar\Docs`, f.txt = F; TAR-DEEP `t.tar\Docs\Sub`, g.txt = G; 7Z rows likewise;
  TWINS rows `\DOCS`, only g.txt). Before (main ff3cd942 = the same build without the change, the
  negative control of T008): 8 / 4 (`probe/result_before.txt`). Registry restored, identical.
- 252's probe `arc252_probe.ps1` on the new build: PASS 16, FAIL 0 (TAR-CONTROL / 7Z-CONTROL now
  report the panel at `...\Docs`).
