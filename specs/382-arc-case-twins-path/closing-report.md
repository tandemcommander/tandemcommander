# Closing report - 382-arc-case-twins-path
Backlog item: a-path-typed-in-another-case-into-an-archive-with-case-twins - A path typed in another case into an archive with case twins elsewhere opens its root
Outcome: closed

## What changed

- `src/common/salarcpathspell.h`: `SalArcPathResolveCase` - a typed path resolved in a
  case-sensitive listing: each leading component exactly first (the listing's comparison, first
  match), else by the only sub-folder equal ignoring case (accepted by the legacy byte fold,
  counted by the legacy fold or the ordinal rule, and by any file of the folder with that name);
  the rest from the first unresolved component kept as typed; the typed length; refused (never
  cut) when the output does not fit.
- `src/zip.h` / `src/zip.cpp`: `CSalamanderDirectory::ResolvePathCase` and its accessor.
- `src/fileswn2.cpp` `CFilesWindow::ChangePathToArchive`: called for a case-sensitive listing
  right after the typed path is stripped, before the "same path" check and the shortening loop.
- `src/saltests/saltests.cpp`: `TestArcPathResolveCase382`.
- Probe `specs/382-arc-case-twins-path/probe/arctwins382_probe.ps1` (rows MIXED, MIXDEEP, MIXMISS,
  EXACT, AMBIG, FILEX for TAR and 7z).

## Measurements (before / after, commands)

- Before (main 59053ae5): `powershell -File tools\run_on_hidden_desktop.ps1 ... arctwins382_probe.ps1`
  -> 14 PASS / 6 FAIL (MIXED, MIXDEEP, MIXMISS, TAR and 7z: panel at the archive root, F5 copied
  `Docs/...`, `X/a.txt`, `X/A.txt`) - `probe/result_before.txt` (rows FILEX added later by the review).
- After: 24 PASS / 0 FAIL - `probe/result_after.txt` (`\Docs`, `\Docs\Sub`, only `f.txt` / `g.txt`
  copied; EXACT, AMBIG, FILEX as before).
- Negative control (loose step disabled): saltests 12 failed, probe 14 / 6.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED (Debug x64). No UI string changed - no `.slt` refresh, no
  `build.cmd full` needed.
- `saltests.exe` -> 30439 checks, 0 failed.
- Probes: `arctwins382_probe.ps1` 24 / 0; `specs/273-tar-case-root/probe/arccase273_probe.ps1`
  12 / 0; `specs/252-archive-case-sensitivity/probe/arc252_probe.ps1` 16 / 0. Registry restored
  and identical after every run.

## Reviews (findings and what was done)

One refute-first review: no MUST. SHOULD 1 (an exact file name lost to a folder of another case)
fixed - files take part in the ambiguity, saltests rows and probe row FILEX added. SHOULD 2 (the
ambiguous case still opens the root silently) -> Inbox item. NOTEs: legacy fold `Ú`/`Ê` (as 273,
recorded in the history), FR-007 by reading, ZIP / UnISO covered but not probed, T009 wording
aligned. Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below: `CHANGELOG.md` has no `## [Unreleased]` section after 0.2.0, and
  versions / sections are the maintainer's.

  ```text
  - **A folder of an archive typed in another case opened the archive's root when another folder held names differing only in case** (feature 382).
    - **Before:** opening `archive.tar\DOCS` (command line, Change Directory, a hot path) for the folder `Docs` of a TAR or 7z archive in which some other folder holds two names that differ only in case (`X\a.txt` and `X\A.txt`) showed the archive's root without a message; Select All and Copy (F5) then copied the whole root.
    - **Now:** the folder opens under the archive's own spelling (`archive.tar\Docs`, also deeper paths such as `dOCS\SUB`) when exactly one folder of that name exists ignoring case; an exactly typed name always wins, and a file with the typed name stays focused as before.
    - **Limitation:** when the typed name fits two folders that differ only in case (`Docs` and `DOCS`, typed `docs`), the archive's root is still shown without a message (recorded for a later fix).
  ```

## New Inbox items (slug - title)

- `a-path-typed-into-an-archive-that-matches-two-case-twins` - A path typed into an archive that
  matches two case twins opens the root silently (leftover:382).
