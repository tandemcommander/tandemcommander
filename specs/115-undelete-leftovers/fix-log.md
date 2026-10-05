# Fix log: feature 115 - Undelete's leftovers (Restore Encrypted Files of any depth, true duplicates, one name for Windows)

Branch `115-undelete-leftovers` (from `114-undelete-names`, HEAD b06ff2b9). Pre-change build
preserved as `build\tandemcommander\Debug_x64_pre115` (a copy of `Debug_x64` = HEAD, made before
the first build, without its `Intermediate` folders - compiler intermediates only; robocopy `/XD
Intermediate`, 0 such folders left). `Debug_x64_111` .. `_114` not touched. Not committed.

**Working constraint today**: the maintainer used the installed program during the day (pid of
`C:\Program Files\Tandem Commander\tandemcommander.exe` running at 10:48) and it shares
`HKCU\Software\Tandem Commander` with every GUI probe - so **no GUI run** was made: no
`tandemcommander.exe` started, no registry import/export. The research is by code reading; the
pure rule is proven by saltests; the probe is written and its runs are pending (`quickstart.md`, on
the maintainer's copy `Debug_x64_115`). The only probe invocation made was a check that it refuses
while a `tandemcommander.exe` runs (exit 99, nothing started).

## T001 - measured first (code reading; details in `research.md`)

- **EFS on this machine (read-only)**: `cipher.exe` present, **no user EFS certificate**
  (`Cert:\CurrentUser\My`, EKU 1.3.6.1.4.1.311.10.3.4: 0) - `cipher /e` would generate one, so it
  was not run: real EFS backups are NOT DRIVEN. C:\ and D:\ report FILE_SUPPORTS_ENCRYPTION
  (flags 0x03E72EFF), so the command itself - and its walk, the defect - is drivable with plain
  files (their copy route never encrypts: `SafeFileCreate` masks the attribute, `SetFileAttributesW`
  cannot set it).
- **(a) Restore Encrypted Files**: the source panel's path read into MAX_PATH bytes unchecked - a
  panel in a 260+ byte folder gave `""` and the selection was used as RELATIVE names (an error,
  empty folders); `GetDirSize` (runs first) appends into that 260-byte buffer unchecked - a name that
  does not fit leaves the parent's path, `strcat("\\*")` overruns by 2 bytes and the function calls
  itself with the same arguments: **a stack overflow at 259 bytes**. `RestoreDir` / `RestoreFile`
  have the same unchecked appends at 520 bytes (would list the parent again and restore its files
  into the target folder of the level) - in the build before not reachable on their own, the
  estimate crashes first. Also unbounded: a directory junction back to an ancestor, and a target
  folder inside the selection.
- **(b) `RemoveDuplicateFiles`**: `DATA_POINTERS` is 44 bytes (pack 4; `Runs` at offset 20);
  `memcmp(..., DSSize)` with the FILE size: up to 20 bytes only StartVCN / LastVCN / DPFlags (all
  0 for a one-cluster file) - **every two small files of one name were "duplicates"** and one left
  {All Deleted Files}; above 20 bytes the `Runs` pointers differ - **a true duplicate was never
  removed** (above 44 bytes: read past the block). Duplicates come from `LoadDeletedDirectories`
  reading a directory cluster again for a second deleted directory entry (deliberately).
- **(c)** `_stricmp` / `StrICmp` (A-Z only) in `namecmp`, the restore list's numbering, the FAT
  listing's numbering and the duplicate removal: `<C-caron>.txt` / `<c-caron>.txt` two names -
  not numbered, the second restore asked to overwrite the first (Yes = the first restored file lost).
- **Sweep**: F3 on a deleted file with a long name - the disk-cache copy's full name cut at
  MAX_PATH bytes (`CopyFile` view branch, every file system); a failed backup-form restore of an
  encrypted file deleted `<name>`, not the `<name>.bak` it created; `UndeleteGetResolvedRootPath`
  `strcpy` into MAX_PATH of a target / disk-cache name that can be longer; `AppendPath` cut a long
  target; `CloseEncryptedFileRaw` on an uninitialised context (both files); a `.bak` shorter than
  the signature counted as a real backup; the source left open when the target could not be
  created; progress labels kept the head of a long path.

## Decisions (spec.md Clarifications)

- Make it work, never stay in the parent: heap paths of `SAL_MAX_PATH_UTF8`, an iterative walk
  (heap stack of open searches - no depth limit on the thread's stack), reports via `DialogError`
  Skip / Skip all / Cancel with the system's text (`ERROR_FILENAME_EXCED_RANGE`, the listing's
  error, `ERROR_CANT_RESOLVE_FILENAME` for a folder the walk is already in) - no new string.
- Folder identity = volume serial + file index of the folder a path leads to; refused: an
  ancestor of the walk (link cycle), the target folder, a folder the restore created (target inside
  the selection; also when the target did not exist at the start - looked up again). Other links
  are followed as before (not following them would drop data the build before restored).
- A file restored onto itself (target = source) is not refused: restoring backups in place is
  legitimate and the source's share mode already makes the create fail (nothing lost).
- Duplicates: equal name (092) + equal size + every data-runs block equal; compared with every kept
  item of a run of equal names; zero-size files never (as before).
- Name rule: header-only port `src/common/salnameorder.h`, used through `String<char>::NameCmp`.

## Changes

- `src/common/salnameorder.h` (new, BOM + CRLF): `SalNameOrderCompareCI` / `SalNameOrderEqualCI`
  - the core's `SalNameCompareOrdinalCI` / `SalNameEqualOrdinalCI` (ASCII prefix fold, tails by
  `CompareStringOrdinal(..., TRUE)` on WTF-8 -> UTF-16, legacy bytes after valid text by the
  `CharLowerA` fold; stack 520 units, heap above).
- `library/miscstr.{h,cpp}`: `String<char>::NameCmp`.
- `fs2.cpp`: `namecmp`, `compare_items`, `RenameDuplicateFiles` on `NameCmp`; `AppendPath`
  refuses a target of MAX_PATH+ bytes; `CopyFile` path on the heap sized by the target (View: the
  full disk-cache name), `SourcePath` restored on the early returns, backup-form cleanup deletes
  the `.bak` it created, `CloseEncryptedFileRaw` only after a successful open;
  `UndeleteGetResolvedRootPath` bounded (`lstrcpyn`, only the root is wanted).
- `library/fat.h`: `compare_names` / `RenameDuplicateDirectories` on `NameCmp`;
  `FATSameStreamData`; `RemoveDuplicateFiles` per run of equal names.
- `restore.cpp`: `CWalkPath`, `CDirId` / `GetDirId`, `CWalkStack`, `WalkError`, `StartListing`,
  `NextEntry`; `RestoreFileAt` (the old body; signature really read; context and source handle
  fixes), `RestoreFile`, `EnterDir`, `LeaveDir` (attributes as before, also on cancel), iterative
  `RestoreDir` / `GetDirSize` (estimate: unlistable / too long / already-walked folders count 0,
  the restore reports them); `RestoreEncryptedFiles` reads the panel path whole (refused only on
  low memory), top-level items count +1 in the estimate (as the restore counts them).
- `dialogs.cpp`: progress labels show `...` + the END of a path that does not fit (whole UTF-8
  characters).
- saltests `TestUndeleteLeftovers115` (14,383 -> 14,401): parity with the core over a corpus
  (the 7 different-length case pairs, Kelvin / dotless i / long s against ASCII, lone surrogates,
  legacy code-page bytes, 600-byte names on the heap path), both length forms, equality vs order,
  20,000 random pairs, and a sort that keeps every group of equal names together.

## Gates

| Gate | Result |
|---|---|
| Debug x64 build | OK (0 errors; the one undelete warning, C4267 `fs2.cpp(457)` `fd.NameLen = strlen(...)`, is the unchanged line of the build before) |
| full Release x64 build | OK (`undelete.spl` 11:10:25; plugins.ver 20 registered; runtime closure OK) |
| saltests | 14,401 / 0 (was 14,383) |
| `tools\check_encoding.py --strict` | TOTAL 0 |
| touched sources | BOM + CRLF kept (C++), new header BOM + CRLF; saltests.cpp / .vcxproj no BOM + CRLF as before; probe files ASCII + CRLF; specs ASCII, LF (as 114's); no control characters |
| probe | `make_images115.py --selftest` OK (OEM 852; two deleted directory entries share cluster 7; tiny files 12 bytes, distinct); 7-Zip lists the FAT image (`KEEP.TXT`); `undelleft_probe.ps1` parses (0 errors) and refuses while a `tandemcommander.exe` runs (exit 99) |

## Hostile re-read of the diff

- Walk paths: every `Append` failure leaves the path unchanged and is reported - no caller uses a
  path after a failed append; every level records its parent's lengths and `LeaveDir` cuts back,
  also on cancel (the loop leaves all levels with `ret` FALSE). `EnterDir` returning -1 after the
  push (listing failed, Cancel) leaves the level for the caller - `RestoreDir` then pops it.
- `level` pointers are not used after `EnterDir` (realloc of the stack) - the loop re-reads `Top()`.
- `FindFirstFileW` through `HANDLES_Q`: the tracker restores the last error (`CheckCreate` saves /
  restores it), so the error read after it is the API's; `FindClose` through `HANDLES` in `Pop` and
  the destructor (registered handles).
- `GetDirId` opens a folder with access 0 and backup semantics (no privilege needed for that);
  unknown identity never matches, so a failure only disables the cycle check for that folder.
- A refused folder is not created in the target (the check runs before `SafeFileCreate`).
- `SetFileAttributesW(attr | FILE_ATTRIBUTE_ENCRYPTED)` and `SafeFileCreate` unchanged - neither
  encrypts (the probe also checks that no restored file is encrypted and that the user's EFS
  certificates did not change).
- `CopyFile` view path: `pathSize = targetLen + 1 + 780 + 8` - room for ':' + a 765-byte stream
  name or ".bak" after the full name; non-view `MAX_PATH + 789` as before (+9).
- The `.bak` cleanup: for `encrypted && BackupEncryptedFiles` `path` still holds the `.bak` the
  create used; `deleteTargetOnError` is FALSE when the create itself failed (unchanged).
- `NameCmp` changes the order of the FAT listing's internal sort and of the restore list (both
  sorted again by the panel / irrelevant to the user) and numbers more pairs (only pairs that are
  one name for Windows - the overwrite prompt the build before showed).
- `FATSameStreamData` compares the `Runs` bytes, `RunsSize` included the terminator - equal runs
  of two records decoded from one entry are byte-identical; NTFS / exFAT never call it.
- `UndeleteGetResolvedRootPath` now may cut the copy inside a UTF-8 character - only its root is
  used (the subst / reparse resolution of the core reads at most MAX_PATH bytes anyway).

## Code-only review: ACCEPT pending GUI - SF1, SF2 and the NITs applied

The reviewer compiled the real walk into an ASan harness (junction loops refused once, target
inside the selection refused, a 3,117-byte accented tree fully restored, Skip / Skip all / Cancel
clean, deletions only of files this restore created) and checked name parity against the core on
3,000,000 random pairs and exhaustive BMP sets (0 mismatches).

- **SF1 - folder identity**: `GetDirId` took volume serial + 64-bit index and treated an all-zero
  id as known - on a redirector reporting index 0 (some WebDAV / NAS) every subfolder "was" its
  parent and Skip all dropped whole subtrees the build before restored; ReFS 64-bit ids are not
  unique. Now `CDirId` holds 103's `CSalFileIdentity` (`salsamefile.h` - the plug-in includes it:
  128-bit `FileIdInfo` id first, mirrored for 0x0601; an all-zero / all-ones id is NOT an identity;
  FAT / exFAT equal ids also need equal metadata) plus the normalised final path of the opened
  folder (`GetFinalPathNameByHandleW`, links resolved; a 64-bit FNV-1a hash of its exact units +
  length). `SameFolder`: equal final paths, or usable ids equal; neither readable = no claim. Then
  the bound is the length Windows accepts (each level beyond it reported). The open asks only
  `FILE_READ_ATTRIBUTES` (as 103).
- **SF2 - path lookup** (`fs2.cpp ChangePath`): the exact name first, then the file system's rule
  (NTFS / exFAT listings do not number case-only pairs: a deleted `<C-caron>` and a live
  `<c-caron>` folder of one parent resolved to whichever came first).
- NIT: the core's `SalNameCompareOrdinalCI` carries a comment that `salnameorder.h` and
  `salzipname.h` copy it.
- NIT: `GetPanelPath` failing (the buffer holds any path, so not "too long") reports low memory;
  the "does not fit" message names the target or the panel path; a comment states that the
  `SAL_MAX_PATH_UTF8` branch is unreachable in practice (Windows refuses 32,767+ units first and
  the file call reports it).
- Recorded and fixed (contained): `CopyFile` - a record with named streams only (a damaged MFT
  record) creates `<name>:<stream>` inside an EXISTING `<name>` without an overwrite question, and
  the failure cleanup deleted `<name>` itself. When the first stream is named and the base exists
  before the restore, the base is never deleted (a partly written stream may stay in it - recorded).
- Gates after the changes: Debug build OK (the one unchanged C4267, now `fs2.cpp(468)`), saltests
  14,401 / 0, strict guard 0, full Release build OK (`undelete.spl` 11:27:19, plugins.ver 20).

## Targeted re-check of the SF1/SF2 fixes: ACCEPT (pending GUI)

The reviewer's ASan walk harness on the new code: junction loops in other case refused once,
grandparent walked one round, target inside the selection refused, 25 accented levels (3,117
bytes) all restored, 101 folders with 0 false cycles; saltests 14,401/0. Recorded limits:
- Folder identity by final path is a 64-bit FNV-1a hash + length: an accidental collision is
  about depth^2 / 2^64; a crafted one is possible (FNV is not collision-resistant) but only causes a
  reported refusal (Skip / Skip all / Cancel), never a silent skip or lost data. Comparing full
  strings would remove the question (later hardening).
- A share that resolves a junction loop itself and reports neither a usable id nor a stable final
  path nests copies until a path limit refuses (Windows ~6,500 levels for a 5-character name; a
  Linux server stops after 40 hops / 4,096 bytes); each level copies that folder's files again, so a
  large folder could fill a disk first - Cancel in the progress dialog stops it. The build before
  overflowed its stack after ~520 bytes. Possible later hardening: a cap on consecutive levels
  without an identity.

Committed after this check with the GUI runs still owed; the build is preserved as
`build\tandemcommander\Debug_x64_115` (undelete.spl and the exe 11:26:59). Results follow in a
separate commit.

## Found on the way (recorded, not fixed)

1. Numbering can produce a name another listed item already has (`a.txt` twice and `a (1).txt`):
   the restore meets an existing file - an overwrite prompt (every release, ASCII too).
2. `ViewFile`'s disk-cache key (`uniqueFileName[2 * MAX_PATH]`): the name append fails for a long
   name, the key lacks the name - still unique per item by its pointer prefix within a snapshot;
   after a rescan that reuses an address a stale copy is conceivable (not measured).
3. Restore Encrypted Files onto itself (target = source folder) reports a sharing error per file
   (nothing lost) - the old "todo"; not refused because restoring backups in place is legitimate.
4. Without any readable folder identity (no usable id AND no final path - a redirector that
   answers neither), a directory-link cycle is bounded only by the path length Windows accepts:
   the levels up to it are restored as nested copies, each level beyond it reported.
5. A named-stream-only record restored over an existing file leaves a partly written stream in
   that file after a failure (it is no longer deleted - see the review section).

## Pending (GUI, after 18:00 - exact commands in `quickstart.md`)

1. `undelleft_probe.ps1` on `Debug_x64_115` (expected: every row PASS, 2 NOT DRIVEN) and on
   `Debug_x64_pre115` with `-Expect before` (predictions in `quickstart.md`; the enc-deep / enc-loop
   END rows FAIL there - the crash, the control).
2. Regression on `Debug_x64_115`: 114's `undelnames_probe.ps1` (all rows as 114 expects).
3. Registry SHA-256 prefix `1AB614304771DBE0` before / after each run.
4. Person, optional: the Plugins-menu route if the probe's key route is NOT DRIVEN; real EFS
   backups on a machine that already has an EFS certificate.

## CLAUDE.md entry

Proposed for "Recent Changes" (plain text):

- 115-undelete-leftovers: **Undelete's Restore Encrypted Files walks any
  depth, {All Deleted Files} drops true duplicates only, one name for
  Windows is one name.** The three "found by 114" items, measured by code
  reading (no GUI that day) and wider.
  - **Restore Encrypted Files** (`restore.cpp`): the source panel's path
    was read into MAX_PATH unchecked (a deeper panel gave "" - relative
    names); `GetDirSize` appended unchecked into that buffer - a name that
    did not fit left the PARENT's path, the parent was listed again: a
    stack overflow at 259 bytes (also a 2-byte overrun); junctions back to
    an ancestor and a target inside the selection recursed without end.
    Now an iterative walk (heap stack of searches) on heap paths of
    `SAL_MAX_PATH_UTF8`; a name that does not fit, an unlistable folder and
    a folder the walk is already in (103's identity - usable 128/64-bit
    ids only - or the normalised final path: an ancestor, the target, a
    folder the restore created) are reported -
    Skip / Skip all / Cancel with the system's text, no new string.
  - **{All Deleted Files}** (FAT, `fat.h RemoveDuplicateFiles`): the
    memcmp of DSSize bytes of the 44-byte `DATA_POINTERS` never removed a
    true duplicate (a directory cluster read twice) and removed a different
    file of up to 20 bytes with the same name. Now size + every data-runs
    block, against every kept item of a run of equal names.
  - **Name identity**: `src/common/salnameorder.h` - the core's
    `SalNameCompareOrdinalCI` / `SalNameEqualOrdinalCI` header-only for
    plug-ins that cannot compile salunicode.cpp (saltests parity);
    `String<char>::NameCmp` in the restore list's and the FAT listing's
    numbering, the duplicate removal and the path lookup.
  - The plug-in's path lookup: exact name first, then the rule (case-only
    pairs are not numbered on NTFS / exFAT).
  - Sweep: F3 on a deleted file with a long name (disk-cache name cut at
    MAX_PATH - nothing shown), a failed backup-form restore deleted
    `<name>` instead of `<name>.bak` (and a named-stream-only record the
    existing base file), `UndeleteGetResolvedRootPath`
    overrun, the main restore's target cut, uninitialised EFS context
    closed, short `.bak` taken as a backup.
  - saltests 14,383 -> 14,401. Interface stays 107, no string, no registry
    change. Probe `probe/undelleft_probe.ps1` + `make_images115.py` (FAT12
    / exFAT images byte by byte, deep / long / junction folders for the
    encrypted route - plain files, no EFS certificate needed or made; the
    command gets Ctrl+Shift+U through the registry for the session)
    written, **GUI runs pending**; real EFS backups NOT DRIVEN. Records:
    `specs/115-undelete-leftovers/fix-log.md`.
