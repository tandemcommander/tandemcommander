# Fix log: 249 - the external unpacker's walk and the temporary-folder cleanups never go through a link

Backlog item `temp-dir-walks-follow-junctions` (source `review:212`). Measured on `main` at
1c8140a0 before the branch existed.

## Measured before (1c8140a0)

### Reachability of the external unpacker with real 7-Zip 22.01

A fixture `src\top\{a.txt, lnk -> victim (junction)}`, archived by `7z a -snl -snh` as 7z, TAR
(`-ttar`) and WIM (`-twim`), each extracted with `7z x -y -o<out>` (the shape of the default command,
`PackBrowseTable[PACK7ZIPINDEX]`):

| Format | `7z x` result for `top\lnk` |
|---|---|
| 7z | a plain empty folder (no link) |
| TAR | `ERROR: Dangerous link path was ignored : top\lnk : ..\..\victim` - plain folder |
| WIM | a junction, but re-targeted INSIDE the output folder (`<out>\Users\...\victim`) |
| TAR with `-snl -snld` | plain folder (7-Zip stores the junction as content in TAR) |
| Windows `tar.exe` | the junction archived as its content - plain folder on extraction |

So the shipped default command never restores a junction pointing outside its output folder. A
junction appears only with an unpacker that restores one (another or older 7-Zip-compatible
executable configured as the 7-Zip executable). Narrow - but then a silent move.

### Probe `probe/tempjunction249_probe.ps1` (hidden desktop) - `probe/result_before.txt`

```
powershell -File tools\run_on_hidden_desktop.ps1 -Log <...>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <...>\tempjunction249_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib <...>\fix_probe_lib.ps1"
```

(Run from a scratch copy on `main`; the file was moved here unchanged when the branch was made.)

| Row | Verdict | Facts |
|---|---|---|
| SWEEP | PASS | the start-up question "delete 1 temporary directory" answered Yes; `SAL249A.tmp` removed; the junction's target kept `keep.txt` - feature 212 holds |
| PLAIN | PASS | fake `x` makes a real `top\a.txt`; F5 out of `t.arj\top` -> `out\a.txt`, no `PACK*.tmp` left |
| UNPACK | **FAIL** | fake `x` restores `top` as a junction to `victimU`; F5 out of `t.arj\top` -> `victimU\keep.txt` MOVED into `out`, no question shown |

Probe traps met: (1) the start-up question comes several seconds after the main window - the
row waits for it; (2) "Reload Environment Variables" (on by default) calls
`RegenerateUserEnvironment` at start, which rebuilds TMP from the registry - the sweep then looked
into the real `%TEMP%`; the probe turns the option off (the registry is restored afterwards);
(3) the probe answers Yes only when the question counts exactly one folder, so the user's own
`SAL*.tmp` leftovers are never touched.

SWEEP's negative control: a build without 212 is not at hand; the row proves the sweep RAN
(`SAL249A.tmp` with `plain.txt` removed) and that the junction's target survived it. A walk through
the junction would have deleted `keep.txt` (212's fix-log describes that walk).

### The defect (by reading, confirmed by UNPACK)

`PackUniversalUncompress` (`src/pack1.cpp`), archive path not empty: at each level of the archive
path it takes the FIRST directory entry found in the temporary folder (`foundFile.dwFileAttributes &
FILE_ATTRIBUTE_DIRECTORY`) and appends it to `srcDir` - a junction too. `panel->MoveFiles(srcDir,
targetDir, ...)` then lists `srcDir` (= the junction's TARGET) and moves its files: the link is the
root of the move, so `BuildScriptDir`'s link question (`CConfirmLinkTgtCopyDlg`) never comes.
Callers: `PackUncompress` (F5 / F6 / drag out of an archive browsed by the external 7-Zip archiver,
`fileswn7.cpp` unpack routes) - archive path from the panel; `CUnpackerConfig::ExecuteUnpacker`
(custom unpackers) passes `archiveRoot = NULL` - no walk there.

### The self-extractor

`src/plugins/zip/selfextr/selfextr.cpp` `_RemoveTemporaryDir` walks every subdirectory (ANSI
calls, a junction included). No project compiles the file (`zip.vcxproj` includes only
`selfextr\comdefs.h` and the icon; no `selfextr` project in `salamand.sln`); no `.sfx` package is
in the build output or the installer. Unreachable in the product.

`src/sfx7zip/install.c` has the same walk (not named by the item): `sfx7zip.vcxproj` is built only
in the solution's "Utils (Release)" configuration, not by `build.cmd`, and nothing ships it (the
installer is Inno Setup). Unreachable - recorded here, no Inbox item.

## Analyze

`speckit-analyze`: 0 CRITICAL, 0 HIGH. C1 (MEDIUM, a link at a deeper level of the archive path
not driven) fixed: probe row DEEP added to T002. Accepted: U1 (LOW) - an unreadable reparse tag and
a cloud placeholder cannot be driven on the hidden desktop; the decision is 197's
`SalDeleteAsDirLinkDecision`, checked by `saltests`. I1 (LOW) - FR numbering order, cosmetic.
