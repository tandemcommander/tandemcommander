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

## Review

### Review 1 (refute-first, independent agent) - 1 MUST, 3 SHOULD, 4 NOTE

- **M1** FR-001 overclaimed: before the cache is asked, F3 / F4 refuse a member whose path inside the
  archive has 520+ bytes (feature 095 - `fileswn5.cpp` / `fileswn6.cpp`, "the longest name a
  plug-in has ever received"); a member of 200 CJK letters (604 bytes, a temporary path of 249
  units) is still refused. Taken: the 095 limit stays (raising it hands archiver plug-ins names they
  never got - an audit, a leftover item); FR-001, the contract, the CHANGELOG and this log state it;
  probe row ARCCAP (604 bytes: refused) added.
- **S1** the probe never reached the `CheckAndPackAndClear` fix (EDITLONG's path is 319 bytes; the
  old buffer cut at 620). Tried: a row with a long CJK %TEMP% given to the started program - the
  copy still went to the system %TEMP% (diagnostics in the row): the program regenerates its
  environment from the user's registry (`RegenerateUserEnvironment`, `salamdr7.cpp`); changing the
  maintainer's real user environment is off-limits. With the system %TEMP% (33 units) the copy path
  is at most about 45 + 519 bytes < 620 - the old cut needs a %TEMP% of about 88+ bytes. The fix
  stays, proven by reading; the row was removed; owed to a person (with `CopyFilesTo`, also not
  driven - the folder browser).
- **S2** longer target paths now reach archiver plug-ins' `UnpackOneFile` from F3 / F4. Taken into
  the contract: the same kind of input F5 has given since 222; ZIP measured, 7-Zip / tar / uniso /
  uncab by reading take it; the disabled unrar `lstrcpy(justName[MAX_PATH], nameInArchive)`
  (reachable before through long folder paths) -> Inbox item; unchm / demoplug refuse silently.
- **S3** the start-up cleanup (`_RemoveTemporaryDir`, `char path[MAX_PATH + 2]`) skipped entries of
  260+ bytes - after a crash a long-name copy and its SAL*.tmp folder would stay for good and the
  question would come back at every start. Fixed: the walk's path on the heap (dir + '\' + the
  longest name), nothing skipped; bounded by SAL_MAX_PATH_UTF8. By reading (driving it would need a
  fake SAL*.tmp folder in the real %TEMP%, where the question could also delete the maintainer's own
  leftovers).
- N1 "Expanded string is too large." twice when a 604-byte member is focused (also seen in ARCCAP;
  probably the information line, `fileswn2.cpp` `char buff[1000]`) - pre-existing -> Inbox item.
  The before-run's GZLONG message is probably the same box (not only F5).
- N2 a .gz with a stored name over 255 units cannot be opened now (the item: refused); gzip itself
  falls back to the archive's name -> a decision item for the maintainer.
- N3 / N4 the gzip reader, the rule, the heap buffers and the low-memory paths hold.

After the fixes: BUILD SUCCEEDED; saltests 24559 / 0; encoding guard 0; probe
`probe/result_after.txt` **16 PASS / 0 FAIL** (VIEWLONG, EDITLONG, ARCCAP, OVERLIMIT, CTL, GZLONG,
GZOVER, GZCTL - RUN and END rows).
