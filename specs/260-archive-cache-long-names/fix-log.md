# Fix log: 260 - F3 / F4 of long archive member names, the gzip name read whole

Backlog item `archive-long-names-cache-folders-tar` (source review:222).

## Measured at HEAD (b8d1f7d0, on `main`, before the feature)

- `specs/222-name-length-units/probe/editname222_probe.ps1` on the hidden desktop on the current
  Debug build (`%TEMP%\tc262scratch\result_222_at_head.txt`, 10 / 0): row LONG - F4 of a ZIP member
  of 90 CJK letters + `.txt` (274 bytes, 94 UTF-16 units) shows "Unable to unpack file from archive
  to temporary directory because resulting filename is too long." Row DIRLONG - a folder of 90 CJK
  letters: "Cannot add 1 or more files to the list. The total path is too long. Some directories or
  files may be missing in the archive listing.", `keep.txt` extracted.
- By reading: `src/cache.cpp` `CCacheDirData::GetName` / `ContainTmpName` - `char
  tmpFullName[MAX_PATH]`, refused when folder + name bytes + 1 > MAX_PATH (DCGNE_TOOLONGNAME).
  Reachable: F3 (`fileswn5.cpp`) and F4 (`fileswn6.cpp`) of every archive member.
- By reading: `src/plugins/tar/gzip/gunzip.cpp` ORIG_NAME into `char buffer[MAX_PATH]`, the rest of
  the name dropped; listed (`ListStream` - `AddFile(NULL, ...)` checks no length) and extracted
  (`UnpackStream` builds the target on the heap) under the cut name.
- Long folders: every route reports (ZIP, 7-Zip, uniso HFS / ISO 9660 / UDF, tar, uncab, the core's
  external packers - each shows a message). Not present: no change.

## Consumers enumerated (fix protocol)

`DiskCache.GetName` callers: `fileswn5.cpp` (F3, archive), `fileswn6.cpp` (F4, archive),
`mainwnd4.cpp` (User Menu batch, short fixed name), `zip.cpp` x4 (plug-in services - keep the byte
rule, plug-ins may copy into 260 bytes). Holders of the copy's path after F4:
`CFileTimeStamps::AddFile` (heap), `CheckAndPackAndClear` (`buf[2 * MAX_PATH + 100]`, `_TRUNCATE`
- a cut), `CopyFilesTo` (`name[MAX_PATH]` - refuses), `FileTimeStampsEnum2` (pointers), PackCompress
(the cache folder + names, the disk-file route).

## Probe before (on the build of b8d1f7d0, no source change)

`probe/cache260_probe.ps1` -> `probe/result_before.txt`: **10 PASS / 4 FAIL** - VIEWLONG and
EDITLONG refused ("...resulting filename is too long."), GZLONG: F5 of the cut name failed with
"Expanded string is too large." (259 bytes ending inside a letter, decoded as code-page text, grew
past the program's buffer), GZOVER: opened without a word (the name cut to 259 letters). OVERLIMIT,
CTL, GZCTL pass (controls). The first run stopped at the probe's own CRC32 (the PowerShell literal
0xFFFFFFFF is -1); fixed (64-bit arithmetic, checked against the "123456789" vector CBF43926).

## Work

- `src/common/salcachename.h` `SalCacheTmpPathFitsU8` (saltests `TestCacheTmpPath260`, 15 checks):
  legacy = bytes + 1 <= MAX_PATH; long = UTF-16 units of folder + name <= MAX_PATH - 1.
- `src/cache.h` / `src/cache.cpp`: `CDiskCache::GetName(..., BOOL longTmpPath = FALSE)` passed to
  `CCacheDirData::ContainTmpName` / `GetName`; the full path is built in a `CSalHeapString`.
  Every existing caller (plug-in services in `zip.cpp`, the User Menu) keeps FALSE.
- `src/fileswn5.cpp` (F3) and `src/fileswn6.cpp` (F4) of archive members: TRUE.
- `src/salamdr3.cpp` `CheckAndPackAndClear`: the copy's path on the heap (was `buf[2 * MAX_PATH +
  100]` with `_TRUNCATE`: a 259-unit path of 3-byte letters would be cut and the edit dropped as
  "unchanged"); on low memory the item is kept. `CopyFilesTo`: names on the heap, "too long" when a
  wide path exceeds MAX_PATH - 1 units (the shell call's limit), the legacy fallback unchanged.
- `src/plugins/tar/gzip/gunzip.cpp`: ORIG_NAME into a growing heap buffer (bounded 64 KiB, beyond:
  too long); `fileio.h/.cpp` flag `OldNameTooLong`; `untar.cpp` `GetStreamHeader` refuses a too-long
  flag or a name over 255 UTF-16 units with `GetErrorText(ERROR_FILENAME_EXCED_RANGE)` under "GZip
  Error" (listing and extraction both go through it).
- Trap met: Bash here-documents collapse doubled backslashes (CLAUDE.md, 123) and MSYS turns a
  leading `//` argument into `/` - the first saltests insertion was garbled; redone with the editor.

## Checks

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED (tandemcommander.exe, tar.spl, saltests.exe rebuilt 11:19).
- saltests -> `saltests: 24559 checks, 0 failed`.
- clang-format: the changed lines match; the differences it shows in these files are older lines.

## Probe after

`probe/result_after.txt`: **14 PASS / 0 FAIL** - VIEWLONG: the viewer opens
`%TEMP%\SAL3AD.tmp\<90 letters>.txt`; EDITLONG: Notepad started, the copy rewritten, leaving the
archive asked the ZIP plug-in's "Confirm File Overwrite" (Yes) - the archive holds ONE member, 274
bytes of name, content "EDITED-CONTENT"; OVERLIMIT refused as before; GZLONG extracted under the
whole name; GZOVER: "GZip Error" "(206) Název nebo přípona souboru je příliš dlouhá." (the system's
text in the OS language), nothing extracted; controls pass.
Regression `specs/222-name-length-units/probe/editname222_probe.ps1` -> `probe/regress_222.txt` 10 /
0 (its LONG row now starts the editor instead of the refusal).
Registry: each run restored identically; the snapshot differed between the 11:12 and 11:20 runs
(CBAC... -> A464...) - written between the runs outside any probe (only the build ran), not by a
probe.
