# Fix log: feature 095 - archive path buffers

Branch `095-archive-path-buffers`, from `094-plugin-password-encoding`.
Decisions by the author (maintainer away): `spec.md` *Clarifications*.
Independent review: ACCEPT; its findings S1-S3 and the nits are worked in below.

## What was wrong, in user terms

**Enter and F4 did not work on a file that lies deep inside an archive.** When
the archive's path, the folder inside the archive and the file name together
came to 518 bytes or more (for example: an archive at a path of 180 bytes, a
folder of 200 bytes inside it, a file name of 150 bytes - accented letters
count twice), pressing Enter (open / run) or F4 (edit) on that file showed the
ZIP plug-in's message **"File not found."** and did nothing. F3 (view) worked on
the same file. The name was short enough for everything else - nothing was
"too long".

Cause: `CFilesWindow::ExecuteFromArchive` (`src/fileswn6.cpp`) built the
disk-cache name in `char dcFileName[2 * MAX_PATH]` with two
`SalPathAppend(..., 2 * MAX_PATH)` calls and **ignored their results**. When
`archive + 1 + inner path + 1 + name >= 520`, the second append refused and the
name was left as `archive\folder`. That string was then used as the cache key,
and its tail - the **folder** - was handed to the archiver as the file to
unpack (`PackUnpackOneFile`, `pack1.cpp` -> the plug-in's `UnpackOneFile`,
`zip/main.cpp`). The reviewer's differential hit this in 474,172 of 2,000,000
random inputs.

Now the name is built in storage of exactly the needed size, so the append
cannot fail: Enter runs the right file and F4 edits it (probe cases S150 and
SU75: fail before, pass now).

**What the feature's premise claimed - a write past a stack buffer - was not
reachable** (proof below). The four sites are nevertheless converted to
exact-size heap storage, so they no longer depend on limits enforced elsewhere.

## Design

`CSalHeapString`, new header-only `src/common/salheapstr.h`:

- `Copy(src, reserve, byteTable)` allocates `strlen(src) + 1 + reserve` bytes;
  with the core's `LowerCase` table the result is **byte for byte what
  `StrICpy(dest, src)` writes**. The fold is not changed (features 092/093 left
  it alone on purpose: the key and the comparison in `PrepareCloseCurrentPath`
  must agree). The caller completes the name in the reserve with the same
  `SalPathAppend` / `strcat` / `sprintf` calls as before, so the content of every
  cache name that was built correctly before is unchanged.
- `Printf(fmt, ...)` sizes with `_vscprintf`: for the messages that name the
  archive.
- Pure (the byte table is a parameter): covered by `TestHeapString095` in
  saltests. The exported `StrICpy` is untouched.

The core's own pattern for long paths is a `char[SAL_MAX_PATH_UTF8]` on the
stack (74 such arrays in `src/*.cpp`); a ~96 KB stack array, or
`CSalMaxPathBuffer`'s fixed 96 KB heap block, was not used: the name is the sum
of three parts and an exact allocation needs no limit at all.

## T002 - inventory and proof that the stack overrun was not reachable

### The limits that feed the four functions (all in BYTES of the stored UTF-8)

| value | limit | where |
|---|---|---|
| `GetZIPArchive()` | **259** | one non-empty writer: `SetZIPArchive(archive)` at `fileswn2.cpp` ~2273, where `archive` is `backup1[MAX_PATH]` filled by `lstrcpyn(backup1, archive, MAX_PATH)` at ~2080; the other writer stores `""` (~1499). All ten callers that open an archive pass through `ChangePathToArchive` |
| `GetZIPPath()` | **259** | `backup2[MAX_PATH]` (`fileswn2.cpp` ~2082), then `path[MAX_PATH]` -> `SetZIPPath` |
| path of a folder that holds files | **255** | `CSalamanderDirectory::AddFile` refuses `strlen(path) > MAX_PATH - 5` (`zip.cpp` ~5999); `AddDir` the same (~6097) |
| file name `f->Name` | **255** | `AddFile`: `NameLen > MAX_PATH - 5` refused - only when `path != NULL` |
| temporary file name from `DiskCache.GetName` | **259** | `CCacheDirData::Path[MAX_PATH]` + `PathLength + strlen(tmpName) + 1 <= MAX_PATH`, else `DCGNE_TOOLONGNAME` (`cache.cpp`); the tmp root comes from `GetTempPathW(MAX_PATH)` / `SalGetTempFileName` (bounded) / the plug-in's `GetCacheInfo` (`MAX_PATH` by contract, `spl_arc.h`) |

The cache itself has no limit on the key: `CCacheData` stores `Name` with
`DupStr`; `FlushCache`, `NamePrepared`, `AssignName`, `ReleaseName` only compare.
The only real limit behind `DCGNE_TOOLONGNAME` is the temporary file's path.

### The reviewer's table: what reaches each buffer

| site | old buffer | maximum reaching it | result |
|---|---|---|---|
| `fileswn9.cpp` `OfferArchiveUpdateIfNeededAux`: `buf` | 260 | 259 + NUL | fits exactly |
| `fileswn2.cpp` `PrepareCloseCurrentPath`: `buf` | 620 | 259 + NUL (key); 259 + format (question) | fits |
| `fileswn6.cpp` `ExecuteFromArchive`: `dcFileName` | 520 | 259 by `StrICpy`; the appends are bounded by `SalPathAppend(..., 520)` | never written past - but the name was **silently left incomplete** (the defect above) |
| `fileswn5.cpp` `ViewFile`: `dcFileName` | 830 | 259 + 1 + 255 + 1 + 255 = 771, + 19 for `":0x%p"` = 790, + NUL = 791 | fits |
| `fileswn5.cpp` `ViewFile`: `nameInArchive` | 520 | 255 + 1 + 255 = 511, + NUL = 512 (copied before the suffix is appended) | fits |

The `":0x%p"` suffix is live: an archive can list two entries with
byte-identical names, and then `strcmp(f2->Name, f->Name) == 0`.

### Every fixed buffer in the four functions

| function | buffer | size | written by | bounded? | consumers | mark |
|---|---|---|---|---|---|---|
| fileswn9 `OfferArchiveUpdateIfNeededAux` | `text` | 760 | `sprintf(fmt, archive)` | no | `SalMessageBox` | SAFE (259 + format); now `Printf` |
| | `buf` | 260 | `StrICpy(archive)` | no | `DiskCache.FlushCache` | SAFE (fits exactly); now heap |
| fileswn2 `PrepareCloseCurrentPath` | `buf` | 620 | `StrICpy(archive)`; `sprintf(IDS_ARCHIVEFORCECLOSE, archive)` twice; `sprintf(IDS_FSFORCECLOSE, path)` | no | `FlushCache`; `SalMessageBox` | SAFE; key and the two archive questions now heap. The FS question: NOT ON THIS PATH, unchanged |
| | `text` | 760 | `sprintf(IDS_ARCHIVECLOSEEDIT, archive)` | no | `SalMessageBoxEx` | SAFE; now `Printf` |
| | `title[100]`, `checkText[200]` | | `LoadStr` texts | | | NOT ON THIS PATH |
| | `path[2*MAX_PATH]` (FS branch) | 520 | `GetGeneralPath(path, 520)` | yes | | NOT ON THIS PATH |
| fileswn6 `ExecuteFromArchive` | `dcFileName` | 520 | `StrICpy(archive)`, `SalPathAppend` x2 (results ignored) | appends yes | `GetName` / `NamePrepared` / `ReleaseName` / `AssignName` (key); tail -> `PackUnpackOneFile` | no overrun; **WRONG NAME when the sum >= 520** - fixed (heap, exact) |
| | `arcCacheTmpPath[MAX_PATH]` | 260 | plug-in `GetCacheInfo` | by contract | `GetName` | NOT ON THIS PATH |
| | `tmpPath[MAX_PATH]`, `buf[MAX_PATH]` | 260 | `memcpy` of the directory part of the tmp name | no | `PackUnpackOneFile` target; `ExecuteAssociation`, `AddFile` | SAFE (tmp name <= 259) |
| | `dosName[SAL_FIND_DOSNAME_U8]` | | `SalConvertFindDataW(..., sizeof)` | yes | `AddFile` | SAFE |
| fileswn5 `ViewFile` | `dcFileName` | 830 | `StrICpy`, `strcat` x4, `sprintf(":0x%p")` | no | cache key | SAFE (791); now heap |
| | `nameInArchive` | 520 | `strcpy` of the tail | no | `PackUnpackOneFile` | SAFE (512); now heap + explicit limit |
| | `validTmpName[MAX_PATH]` | 260 | `lstrcpyn(f->Name, MAX_PATH)` | yes | `GetName`, `PackUnpackOneFile` | SAFE |
| | `arcCacheTmpPath[MAX_PATH]`, `tmpPath[MAX_PATH]` | 260 | as in fileswn6 | | | SAFE |
| | `path[SAL_MAX_PATH_UTF8]` | 98,302 | disk / Find branch | | | NOT ON THIS PATH |

Bookkeeping reached from `ExecuteFromArchive`: `CFileTimeStamps::AddFile`
copies the archive name with `strcpy` into `ZIPFile[MAX_PATH]` (259 + NUL: fits);
its items are `DupStr` copies. `CheckAndPackAndClear`: `buf[MAX_PATH + 100]` <-
tmp directory + `\` + name (<= 259).

## T003 - what changed

- `src/common/salheapstr.h` - new.
- `src/fileswn6.cpp` `ExecuteFromArchive` - **the fix**: the name is built in a
  `CSalHeapString` of `archive + inner path + name + 3` bytes; the same
  `StrICpy`-fold and the same two `SalPathAppend` calls, which now always fit.
  The name handed to the archiver is refused with the existing
  `IDS_UNPACKTOOLONGNAME` message at 520 bytes or more (the limit of the view
  path; cannot be reached with the limits above).
- `src/fileswn5.cpp` `ViewFile` - `dcFileName` and `nameInArchive` on the heap;
  the same explicit 520-byte limit before the plug-in call.
- `src/fileswn9.cpp` `OfferArchiveUpdateIfNeededAux`, `src/fileswn2.cpp`
  `PrepareCloseCurrentPath` - the flush key and the messages naming the archive
  on the heap.
- `src/saltests/saltests.cpp` - `TestHeapString095` (70 checks: equality with the
  old fold on ASCII, UTF-8, WTF-8 and raw code-page bytes; the reserve; lengths
  259 / 260 / 261 / 519 / 520 / 619 / 620 / 829 / 830 / 4000 / 98,301; `Printf`).

No UI string added or changed. Plug-in interface unchanged (107).

### What a plug-in receives (`UnpackOneFile(nameInArchive, ..., targetDir)`)

| path | before | after |
|---|---|---|
| F3 (`ViewFile`) | inner path + name, at most 511 bytes | the same strings; 520 bytes or more would be refused before the call |
| Enter / F4 (`ExecuteFromArchive`), sum < 520 | inner path + name | the same |
| Enter / F4, sum >= 520 (inner path + name at most 511) | **the folder** (the name was dropped) | inner path + name, at most 511 bytes: no longer than F3 always delivered |

`targetDir` (the tmp directory, <= 259 bytes) and the archive name (<= 259) are
unchanged.

### Recorded, not changed (behaviour on failure)

- Low memory in `fileswn9` / `fileswn2`: the cache flush is skipped with a trace
  only (the cached copies stay until the cache drops them).
- A failed `Printf` (low memory or a broken format string) shows a message box
  with an empty text.
- Low memory in `ViewFile` / `ExecuteFromArchive`: trace and return, nothing is
  opened.

## T004 - probe

`probe/longarc_probe.ps1` (pure ASCII, hidden desktop, registry key exported,
restored and verified, own pids only). An archive is entered, the panel goes
into a long folder inside it, and on the long-named file:

- I cases: F3 (`CM_VIEW` 742), F4 (`CM_EDIT` 743), leave, update;
- S cases (the defect): archive path 180 bytes, folder 200 bytes, a `.cmd` file
  of 130 or 150 bytes that writes `LONG095` into a marker file (its neighbours
  write `OTHER095`): **Enter** runs it - the marker proves which file ran -
  then F4, leave, update.

The F4 "editor" is configured inside the registry backup as
`cmd.exe /c echo edited095>>"$(FullName)"`; the archive is read back with
python's `zipfile`. END = process alive, answers `WM_NULL`, no other window, no
new crash report, exit code 0 on `WM_CLOSE`.

### Fixed build - `probe/longarc_result.txt`: PASS 60, FAIL 0, NOT DRIVEN 0

| case | archive + folder + name (bytes) | ENTER | NAV | VIEW / EXEC | EDIT | LEAVE | END |
|---|---|---|---|---|---|---|---|
| I10 | 56 + 10 + 10 | PASS | PASS | PASS viewer | PASS | PASS archive updated | PASS |
| I120 | 57 + 120 + 120 | PASS | PASS | PASS viewer | PASS | PASS archive updated | PASS |
| I200 | 57 + 200 + 200 | PASS | PASS | PASS viewer | PASS | PASS archive updated | PASS |
| I251 | 57 + 251 + 251 | PASS | PASS | PASS "too long" message | PASS "too long" message | PASS | PASS |
| IU60 | 57 + 120 + 116 (accented) | PASS | PASS | PASS viewer | PASS | PASS (no update offered, see below) | PASS |
| IU125 | 58 + 250 + 246 (accented) | PASS | PASS | PASS "too long" message | PASS "too long" message | PASS | PASS |
| S130 | 180 + 200 + 130 = 512 | PASS | PASS | PASS ran LONG095 | PASS | PASS archive updated | PASS |
| **S150** | 180 + 200 + 150 = 532 | PASS | PASS | **PASS ran LONG095** | **PASS** | PASS archive updated | PASS |
| SU65 | 180 + 200 + 130 (accented) | PASS | PASS | PASS ran LONG095 | PASS | PASS (no update offered) | PASS |
| **SU75** | 180 + 200 + 150 (accented) | PASS | PASS | **PASS ran LONG095** | **PASS** | PASS (no update offered) | PASS |

### Build before the feature - `probe/longarc_result_pre095.txt`: PASS 56, FAIL 4

Identical to the table above except:

| case | EXEC (Enter) | EDIT (F4) |
|---|---|---|
| **S150** | **FAIL**: nothing executed; message box "ZIP: File not found." | **FAIL**: "ZIP: File not found." |
| **SU75** | **FAIL**: nothing executed; "ZIP: File not found." | **FAIL**: "ZIP: File not found." |

No run-time check, crash or hang on either build at any length - consistent
with the proof above. The "too long" message of I251 / IU125 is the disk
cache's temporary-name limit and is the same on both builds.

### Not driven

- An archive whose own path is 260 bytes or more: it cannot be entered (see S2
  below); tried with 260 and 300 bytes ASCII and 261 / 262 bytes accented.
- Folder names of U+4E00: not representable in code page 1250, the start-up
  parameter `-l` arrived as `?`.
- Two entries with byte-identical names (the `":0x%p"` suffix).
- A second archive type (7-Zip, TAR): the limits are the core's, not the
  plug-in's.
- Release build under the probe (run-time checks exist only in Debug).

## Found, not changed (for the backlog)

1. **`ChangePathToArchive` cuts the archive's path silently at 259 BYTES**
   (`fileswn2.cpp` ~2080, `lstrcpyn(backup1, archive, MAX_PATH)`), possibly in
   the middle of a UTF-8 sequence. With accented folder names that is about 130
   characters. Outcomes:
   - the extension is cut off -> `PackIsArchive` fails, only a trace: **Enter
     does nothing, no message** (probe: 260 and 300 bytes);
   - the containing folder itself is over 259 bytes -> `IDS_FILEERRORFORMAT`
     naming the truncated path;
   - the truncated name still has an archive extension (`x.tar.gz` -> `x.tar`,
     `a.zip.zip` -> `a.zip`) -> "error opening file" for the wrong name (probe:
     261 bytes accented, "(2) The system cannot find the file specified");
   - and if a file with that truncated name EXISTS, **the wrong archive is
     opened**.
   The inner path is cut the same way (`backup2[MAX_PATH]`).
2. **An edited file with a non-ASCII name is never offered for packing back.**
   Probe IU60, SU65, SU75 - on both builds, also for names that fit every
   buffer: the editor changed the temporary copy, the "archive is about to
   close" information appeared, the Archive Update dialog did not, the archive
   kept the old content. Likely cause (read, not proven):
   `CFileTimeStamps::CheckAndPackAndClear` (`salamdr3.cpp` ~3377) looks the
   temporary file up with the ANSI `FindFirstFile` on a UTF-8 path, does not
   find it and drops the item as unchanged. The edit is lost without a word.
3. The ZIP plug-in cannot update an archive whose path is close to 259 bytes:
   "Cannot create temporary back-up file. File name too long" (259-byte ASCII
   path), then the core's "Packing of updated file(s) has failed" question.
4. `CSalamanderDirectory::AddFile` checks the name length only when
   `path != NULL`; the TAR plug-in adds the single file of a compressed stream
   with `path == NULL` (`tar/untar.cpp` `ListStream`). Not followed further.
5. `CFileTimeStamps::AddFile`: `strcpy` into `ZIPFile[MAX_PATH]`, and the
   Archive Update dialog's *Copy Selected To...* `strcpy` into `path[MAX_PATH]`
   (`dialogs5.cpp`): safe only through the 259-byte limit of item 1.
6. `ChangePathToArchive`: `text[MAX_PATH + 500]`, `path[MAX_PATH]`,
   `currentPath[MAX_PATH]` with `sprintf` / `strcpy`: the same dependence.
7. Debug builds, at exit after a view / edit from an archive: "Some monitored
   handles remained opened. Number of opened handles: 1" from a plug-in's
   handle tracker (`plugins/shared/mhandles.cpp`); also on the build before the
   feature and on short paths.
8. After an instance is ended by force its `SAL*.tmp` folder stays and the next
   start asks "Do you want to delete 1 temporary directory used by previous
   instances"; the probe answers No and removes its own folders by name.

## Gates (this session)

- Debug x64 build: exit 0. Full Release x64 build: exit 0 (before the last
  comment-only change in `fileswn6.cpp`; Debug rebuilt after it).
- saltests: **13,102 checks, 0 failed** (13,032 before).
- `python tools/check_encoding.py --strict`: **TOTAL: 0**.
- Changed sources keep UTF-8 BOM + CRLF (`saltests.cpp` has no BOM, as before);
  `git diff --stat`: 5 files, 147 insertions, 24 deletions, plus the new header.
- Registry key SHA-256 identical before and after every probe run.

## Gates

Debug build and full Release build (rebuilt after the last change): no
errors. saltests 13,102 checks, 0 failed. `check_encoding.py --strict`
TOTAL: 0. Probe on the hidden desktop: 60 PASS / 0 FAIL (the build before the
feature: 56 / 4). Independent review: ACCEPT. Registry key identical before
and after every run.

