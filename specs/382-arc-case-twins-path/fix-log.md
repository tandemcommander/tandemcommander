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

## Analyze

speckit-analyze (two passes): no CRITICAL, no HIGH. LOW F1 (FR order) fixed. MEDIUM C1 accepted:
FR-007 (the panel already inside the same archive) is served by the same single call placed
before the "same path" check for both routes; the probe drives the fresh open (command line)
only - a typed path change inside an open archive needs a keyboard on the hidden desktop.

## Implementation

- `src/common/salarcpathspell.h`: `SalArcPathResolveCase` (contract `contracts/arcpath-resolve.md`).
- `src/zip.h` / `src/zip.cpp`: `CSalamanderDirectory::ResolvePathCase`, accessor
  `CSalDirResolveCaseAccess` (folder flag; `StrICmpEx`; `StrICmpEx` or `SalNameCompareOrdinalCI`).
- `src/fileswn2.cpp` `ChangePathToArchive`: called only for a listing with
  `SALDIRFLAG_CASESENSITIVE`, right after the typed path is stripped and before the "same path"
  check; taken only when it differs and has the same length (into `char[MAX_PATH]` as `path`).
- `src/saltests/saltests.cpp`: `TestArcPathResolveCase382` (fake listing of 252/273).
- Trap: a clang-format of the changed lines only (`--lines`), never whole files (273's trap).

## Measurement after

- `.\build.cmd` -> BUILD SUCCEEDED (the C4244 warning at `zip.cpp(5991)` is pre-existing, not
  this feature's lines).
- `saltests.exe` -> `saltests: 30434 checks, 0 failed`.
- Probe `arctwins382_probe.ps1` -> **20 PASS / 0 FAIL** (`probe/result_after.txt`): MIXED,
  MIXDEEP, MIXMISS now open `\Docs` / `\Docs\Sub` / `\Docs` and copy only `f.txt` / `g.txt`
  ("Copy file ... from archive"), TAR and 7z; EXACT and AMBIG unchanged. Registry identical.
- Regression probes: `specs/273-tar-case-root/probe/arccase273_probe.ps1` 12 / 0;
  `specs/252-archive-case-sensitivity/probe/arc252_probe.ps1` 16 / 0.
- Encoding guard `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).

## Negative control

Step 2 of `SalArcPathResolveCase` disabled (`if (false && found < 0 && ...)`), rebuilt:
saltests 12 failed (the unique-fold rows), probe 14 PASS / 6 FAIL (exactly the before state:
MIXED, MIXDEEP, MIXMISS, TAR and 7z). Restored, rebuilt, results above re-measured.

## Translations

No UI string, menu or dialog changed - no `.slt` refresh needed.
