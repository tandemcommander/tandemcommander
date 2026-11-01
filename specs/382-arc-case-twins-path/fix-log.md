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

## Review

Review 1 (independent agent, refute-first): **no MUST**. It rebuilt the branch (BUILD SUCCEEDED,
saltests 30434 / 0), built the old core from a worktree of `main` 59053ae5 into its own folder,
and ran an extended copy of the probe on both: old 26 PASS / 6 FAIL / 2 NOT DRIVEN (the fix-log's
before reproduced), branch 32 / 0 / 2; 273's probe 12 / 0.
- SHOULD 1 - an exact FILE name lost to a folder of another case: `Docs\f.txt` and the file
  `DOCS` (twins, so the listing is case-sensitive), opened at `<archive>\DOCS`, F5 without Select
  All: `main` focused the file `DOCS` and copied it; the branch opened `\Docs` and copied nothing.
  **Fixed**: the loose step also looks at the folder's files - a file equal to the typed component
  exactly or ignoring case makes it ambiguous (not resolved). `SalArcPathResolveCase` accessor
  gained `FileCount` / `FileName` (core: `GetFilesCount` / `GetFile`); saltests rows (file `DOCS`
  beside folder `Docs`: `DOCS`, `docs`, `DOCS\x` unresolved, `Docs` exact, a file of another name
  irrelevant); probe row FILEX (TAR, 7z): panel at the root, F5 copies `DOCS` = 'D'. The
  reviewer's branch build (without the file check) is the negative control of FILEX (copied
  nothing).
- SHOULD 2 - the ambiguous case (`Docs` / `DOCS`, typed `docs`) still opens the root silently and
  Select All + F5 copies the whole root (same on `main`); the item's *Expected* allowed "or the
  user is told", the spec chose the unambiguous folder and kept the old shortening (conservative).
  -> Inbox `a-path-typed-into-an-archive-that-matches-two-case-twins` (leftover:382). The probe's
  AMBIG row checks only that no twin is opened.
- NOTE 1 - the accepting rule is the legacy byte fold (`StrICmpEx`): in code page 1250 the UTF-8
  names `Ú` (C3 9A) and `Ê` (C3 8A) fold equal, so typed `\Ú` opens the folder `Ê` (7z row
  LEGACYFOLD; TAR NOT DRIVEN - tar.exe cannot read the name). The same archive without twins does
  so already since 273 (row LEGACYFOLD0, both builds) - as designed (FR-003), recorded in the
  feature history.
- NOTE 2 - FR-007 (panel already in the archive) is proven by reading only (accepted, Analyze C1).
- NOTE 3 - the rule covers every case-sensitive listing (Unix-made ZIP, UnISO) - intended (spec
  *Assumptions*), not probed.
- NOTE 4 - T009 named "the call disabled", the fix-log disabled step 2 of the rule: equivalent (the
  call then keeps the typed path); tasks.md wording aligned.
- NOTE 5 - standing rules hold (nothing cut, UTF-8, one caller).
- NOTE 6 - old reviewer worktrees of earlier features are registered (`%TEMP%\rev325` ...) -
  housekeeping, not this feature.

After the SHOULD 1 fix: `.\build.cmd` BUILD SUCCEEDED; saltests **30439 checks, 0 failed**; probe
**24 PASS / 0 FAIL** (`probe/result_after.txt`); 273's probe 12 / 0; 252's probe 16 / 0.
Only SHOULD findings -> no second review (SKILL step 7).
