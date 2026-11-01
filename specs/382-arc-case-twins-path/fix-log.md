# Fix log - 382-arc-case-twins-path

Backlog item `a-path-typed-in-another-case-into-an-archive-with-case-twins`: a path typed in
another case into an archive with case twins elsewhere opens its root.

## Measurement before (HEAD0 59053ae5, main)

- Build: `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- Probe: `probe/arctwins382_probe.ps1` (written for this run on the model of
  `specs/273-tar-case-root/probe/arccase273_probe.ps1`; run from a scratch copy named
  `arctwins_probe.ps1` with fixture `tctwins`, renamed afterwards to `arctwins382_probe.ps1` /
  `tc382` - rows and checks identical), on the hidden desktop:
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\arctwins_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1"`
- Result `probe/result_before.txt`: **14 PASS / 6 FAIL**. TAR and 7z alike:
  - MIXED (`Docs\f.txt`, `X\a.txt`, `X\A.txt`; typed `\DOCS`) FAIL - panel at the archive root,
    "Copy 2 directories from archive", target `Docs/f.txt, X/a.txt, X/A.txt`.
  - MIXDEEP (typed `\dOCS\SUB`) FAIL - root, whole root copied.
  - MIXMISS (typed `\DOCS\nothing`) FAIL - root, whole root copied.
  - EXACT (`Docs`, `DOCS`, `X`; typed `\DOCS`) PASS - `\DOCS`, only `g.txt`.
  - AMBIG (`Docs`, `DOCS`; typed `\docs`) PASS - root (no guess), nothing copied (copy not run).
  - Registry restored, identical (SHA-256 equal).

## Reachability

Command line `-l <archive>\DOCS` (the probe), Change Directory and hot paths all end in
`CFilesWindow::ChangePathToArchive` (`src/fileswn2.cpp`): the typed path is set by
`SetZIPPath`, the loop `while (path[0] != 0 && GetArchiveDirFiles() == NULL)` shortens it;
`CSalamanderDirectory::GetFiles` (`src/zip.cpp`) compares components with `SalDirStrCmpEx`,
exact when the listing has `SALDIRFLAG_CASESENSITIVE` (7-Zip / TAR keep it when any folder holds
case twins, 252). `DOCS` therefore names nothing and the loop reaches the root, no message.

## Design

Second option of the item's *Approach*: before the shortening loop, when the listing is
case-sensitive, resolve the typed path component by component - exactly first (the listing's
own comparison, first match, as `GetFiles`), else by the only sub-folder equal ignoring case.
Accepted = equal by the legacy byte fold `StrICmpEx` (what a listing without twins accepts, so
the result is what 273 opens for a twin-free archive); counted for ambiguity = equal by either
rule of `salcasetwins.h` (`StrICmpEx` or `SalNameOrderCompareCI`). From the first component that
does not resolve, the rest stays as typed for the existing loop. Pure rule in
`src/common/salarcpathspell.h` (saltests); the listing's comparison rule is not changed.
