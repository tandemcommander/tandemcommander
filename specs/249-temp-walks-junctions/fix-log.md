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

## Work

- `src/pack1.cpp` `PackUniversalUncompress`, the archive-path walk: after a found directory is
  appended to `srcDir`, a directory with `FILE_ATTRIBUTE_REPARSE_POINT` that `DeleteAsDirLink` takes
  for a link (feature 197, fail closed; a cloud placeholder is a folder) refuses the unpack before
  anything is moved: `IDS_PACKERR_GENERAL` ("System error: %1") with `<path>: GetErrorText(
  ERROR_REPARSE_POINT_ENCOUNTERED)` composed on the heap (`CSalHeapString::Printf`, never cut),
  `RemoveTemporaryDir(tmpDirNameBuf)` (212 removes the link as a link), the handler's `FALSE`
  returned. No new UI string. The message names the temporary path (`...\PACK8F.tmp\top`) - the
  archive path is its tail.
- `src/plugins/zip/selfextr/selfextr.cpp` `_RemoveTemporaryDir`: a directory with
  `FILE_ATTRIBUTE_REPARSE_POINT` is removed with `RemoveDirectory` (the entry only) and never walked
  (no 197 helper there: every reparse directory counts as a link, fail closed).
- Probe: rows UNPACK / DEEP also require the refusal message; PLAIN requires none; row DEEP added
  (`t.arj\a\top`, the fake makes a real `a` and the junction `a\top`); `-Lib` resolved in the body
  (PowerShell 5.1 leaves `$PSScriptRoot` empty in a param default).

### Callers of the `FALSE` (T004)

- `CFilesWindow::UnpackZIPArchive` (`src/fileswn7.cpp`, F5 / drag & drop to a panel): on `FALSE` only
  `RemoveEmptyDirs(newDirs)` (the target folders it created for this unpack - empty, nothing moved)
  and no selection change. The core has no Move out of an archive through `PackUncompress`: the only
  `PackDelFromArc` of `fileswn7.cpp` is Delete (F8). FR-007 holds by construction.
- `salshlib.cpp` (drag & drop to another application): the result is ignored; it only posts change
  notifications. Nothing deleted.
- `CUnpackerConfig::ExecuteUnpacker` (custom unpackers) passes `archiveRoot = NULL` - the walk does
  not run there.

## Checks

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |
| build | `.\build.cmd` | `BUILD SUCCEEDED` |
| unit rules | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 24319 checks, 0 failed` |
| self-extractor | `cl /nologo /Zs /TP /DWIN32 /D_WINDOWS /DENGLISH_VERSION /I. /I.. /I..\..\shared /I..\..\..\common selfextr.cpp` (vcvarsall x86, in `src\plugins\zip\selfextr`) | no diagnostics (x86, the self-extractor's target). x64: two old errors at `DialogBoxParam` (lines 681 / 706, a `BOOL` dialog procedure) - unrelated, not this change |

### Probe after (`probe/result_after.txt`)

`powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\249-temp-walks-junctions\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\249-temp-walks-junctions\probe\tempjunction249_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"`

| Row | Before | After |
|---|---|---|
| SWEEP | PASS | PASS |
| PLAIN | PASS | PASS (no message) |
| UNPACK | FAIL (keep.txt moved into out) | PASS - "System error: ...\PACK8F.tmp\top: (4395) ..." (the system text, Czech on this machine), keep.txt kept, nothing in out, no PACK*.tmp |
| DEEP | (new row) | PASS - "...\PACKBE5.tmp\a\top: (4395) ...", keep.txt kept |

Rows: PASS 8 (4 RUN + 4 END), FAIL 0, NOT DRIVEN 0; registry restored and identical (SHA-256
98A53651...24D4 before and after).

### Negative control (T009) - `probe/result_control_unfixed.txt`

The revised probe on a build with `src/pack1.cpp` as at HEAD (the change copied aside, the file
restored from git, built, the change copied back and rebuilt): UNPACK FAIL and DEEP FAIL (keep.txt
moved into out, no message), SWEEP / PLAIN PASS - the rows detect the defect at both levels. After
the rebuild with the fix, the probe was run again: 8 / 0 as above.
