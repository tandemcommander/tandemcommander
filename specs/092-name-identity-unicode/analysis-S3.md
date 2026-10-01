# Feature 092, stage S3 — "only a change of case" / "the target is the source": conversion plan

Read-only analysis at the working tree of `092-name-identity-unicode` (S1 committed, S2 in the
working copy). Nothing was built or run. Every statement about run-time behaviour is **by
reading the code**; where it depends on what a file system returns, it says so.

Abbreviations: `EQ(a,b)` = `SalNameEqualOrdinalCI(a, -1, b, -1)`. "Pair C" = `Článek.txt` /
`článek.txt` (byte fold: different, ordinal: equal). "Pair H" = `ĥ.txt` / `Ĺ.txt` (byte fold on
CP1250: equal, ordinal: different).

## 0. Headline findings

1. **The lossy direction is the false "different" (pair C), not the false "equal" (pair H).**
   In all three "only a change of case" gates (`fileswn5.cpp:2191/2256`, `worker.cpp:5817/5906`)
   a false "equal" only *withholds* the overwrite prompt and ends in an error box. A false
   "different" lets the code offer to overwrite a file **with itself** and then
   `SalDeleteFile(target)` — which is the source. Reachable only when `MoveFile` reports
   `ERROR_ALREADY_EXISTS`/`ERROR_FILE_EXISTS` for a case-only rename; local NTFS does not
   (the rename succeeds first). Which redirectors do was **not determined**.
2. **A site the research put in S4 is the upstream gate of S3 for directories and must move
   with it: `salamdr5.cpp:1143`** (`SalSplitGeneralPath`, `StrICmp(dirName, name) == 0 &&
   IsTheSamePath(path, curPath)` = "renaming a directory to the same name except for letter
   case"). With the byte fold, F6 on directory `Článek` with target `článek` is *not* recognised
   as a rename; the target is taken as an existing directory to move *into*. Without this site
   the conversions at `fileswn6.cpp:1773/1776` cannot be reached by the rename-by-mask route.
   It is inside a function exported to plug-ins (`CSalamanderGeneral::SalSplitGeneralPath`,
   `zip.cpp:2848`) — a decision for the maintainer against FR-008 (see note N-A).
3. **A second partner is missing from the list: `cache.h:89` `TmpNameEqual`** (used only at
   `cache.cpp:384`, three lines above the listed `cache.cpp:399`). Both answer "is this tmp
   name already in this tmp directory"; converting 399 alone leaves the first check on the
   byte fold.
4. **`worker.cpp:3215` cannot be a drop-in replacement of the whole condition**: the byte-length
   test there is not a guard in front of the comparison, it is the capacity of an in-place
   `memcpy` into an exact-size heap string (`BuildName`). It must stay.
5. **8.3 names are not always ASCII** (research §2.3 says they are): on FAT the short name is
   stored in the OEM code page and may hold accented letters; on NTFS only with
   `NtfsAllowExtendedCharacterIn8dot3Name`. So the first half of the DOS-collision test can see
   non-ASCII text. Consequence below (group D) — churn, no loss.
6. **Case-sensitive directories** (per-directory flag, WSL): there `A.txt` and `a.txt` are two
   files and "only a change of case" is already wrong for ASCII. After S3 accented names join
   ASCII: an overwrite that works today for pair C in such a directory becomes a refusal
   ("cannot copy file to itself" / plain error). Safe direction, but a visible change — record it.
7. No `StrICmp(...) == 0 && strcmp(...) != 0` pattern exists in these files (tree-wide grep: 0
   hits). The case-sensitive halves that exist are separate statements and **stay `strcmp`**:
   `fileswn6.cpp:1751`, `:2648`, `:1428`, `:2383`, `:3105`, `fileswn5.cpp:2845`.

## 1. Table

| # | site (current) | function | operands | decision | rec. | risk |
|---|---|---|---|---|---|---|
| A1 | `fileswn5.cpp:2191` | `CFilesWindow::RenameFileInternal` | full path of the item vs full path of the typed name; same directory bytes | "not just change-case" → try DOS-collision workaround | CONVERT with A2, A3, A4 | medium |
| A2 | `fileswn5.cpp:2204-2205` | same | typed name vs DOS name / long name of what `FindFirstFile(target)` found | DOS-name-only collision → move the other file aside | CONVERT (both halves) | low |
| A3 | `fileswn5.cpp:2256` | same | as A1 | overwrite prompt → `SalDeleteFile(tgtPath)` | CONVERT with A1 | **high value**, medium |
| B1 | `worker.cpp:5817` | `DoMoveFile` | `op->SourceName` vs `op->TargetName`, full paths | as A1 | CONVERT with B2, B3 | medium |
| B2 | `worker.cpp:5832-5833` | same | as A2 | as A2 | CONVERT (both halves) | low |
| B3 | `worker.cpp:5906` | same | as B1 | overwrite prompt (or none when confirmations are off / Overwrite All) → `SalDeleteFile(op->TargetName)` | CONVERT with B1 | **high value**, medium |
| C1 | `fileswn6.cpp:1773` | `CFilesWindow::BuildScriptDir` | `sourcePath` vs `targetPath` (both with the directory name appended) | "only a rename" → `sameDisk` | CONVERT with C2 **and `salamdr5.cpp:1143`** | medium |
| C2 | `fileswn6.cpp:1776` | same | same | rename the directory (`ocMoveDir`) vs merge into the existing target | CONVERT with C1 | medium |
| C3 | `fileswn6.cpp:2649` (2648 is the `strcmp` half) | `CFilesWindow::BuildScriptFile` | `op.SourceName` vs `op.TargetName`, full paths | copy: "cannot copy file to itself" | CONVERT; `strcmp` at 2648 stays | medium |
| C4 | `fileswn6.cpp:2697` | same | typed target name vs long name found on disk | overwrite-older pre-test: found by its long name (not by DOS name) | CONVERT with E2 | low |
| D1 | `worker.cpp:3002-3003` | `SalCreateFileEx` (also exported) | as A2 | as A2 | CONVERT (both halves) | low |
| D2 | `worker.cpp:6424-6425` | `SalCreateDirectoryEx` (also exported) | as A2 | as A2 | CONVERT (both halves) | low |
| D3 | `safefile.cpp:154-155` | `CSalamanderSafeFile::SafeFileCreate` (exported) | as A2; `fileName` comes from a plug-in | as A2 | CONVERT (both halves) | low |
| E1 | `worker.cpp:3215` | `CorrectCaseOfTgtName` | tail of the target path vs long name on disk | copy the on-disk case into the target name | CONVERT the comparator, **keep the length test** | medium |
| E2 | `worker.cpp:4526` | `DoCopyFile` | as C4 | overwrite-older: skip without opening | CONVERT with C4 | low |
| F1 | `cache.cpp:399` | `CCacheDirData::ContainTmpName` | new tmp name vs long name found in the tmp directory | "directory holds an unknown file of this name" → pick another directory | CONVERT with F2 and `cache.h:89` | medium |
| F2 | `cache.cpp:406` | same | new tmp name vs DOS name found | DOS-name clash → pick another directory | CONVERT with F1 | low |
| G1 | `pack2.cpp:501` | `PackUniversalCompress` | generated `PACK<hex>.<ext>` (pure ASCII) vs found name | which found file gets the archive's own name | CONVERT (no behaviour change) or leave annotated | low |

Missed by the research's S3 list, found in or around the same functions:

| # | site | kind | recommendation |
|---|---|---|---|
| M1 | `salamdr5.cpp:1143` (+ `IsTheSamePath` at 1145) | case-only **directory** rename gate | convert the `StrICmp(dirName, name)` half in S3 together with C1/C2 (decision N-A); the `IsTheSamePath` half in S4 |
| M2 | `cache.h:89` `TmpNameEqual` → `cache.cpp:384` | partner of F1 | convert with F1/F2 |
| M3 | `cache.h:88` `NameEqual` | no caller found (`grep`) | leave for S5 (cache keys) |
| M4 | `cache.cpp:662`, `:667` `DetachTmpFile` | tmp path prefix + tmp name identity | S4 (prefix helper with `pathBytes`); list it there |
| M5 | `fileswn5.cpp:2153` (same function as A1) | path prefix, **with a byte-length guard** (`otherPanelPathLen >= pathLen`, `GetPath()[pathLen]`) | S4, `SalPathHasPrefixOrdinalCI` + `pathBytes`; guard goes away there |
| M6 | `fileswn6.cpp:689` | "same source directory as last time" (cached ADS/flags) | S4; plain `EQ` |
| M7 | `fileswn6.cpp:698` | `IsTheSamePath(sourcePath, targetPath)` → "Copy of…" names | S4 |

## 2. Per-site notes

### Group A — `RenameFileInternal` (`fileswn5.cpp:2109-2333`), Quick Rename on disk

```cpp
2191  if (StrICmp(path, tgtPath) != 0 && // if it isn't just change-case
2192      (err == ERROR_FILE_EXISTS ||   // check whether it's only rewriting the DOS name of the file
2193       err == ERROR_ALREADY_EXISTS))
...
2204  if (StrICmp(tgtName, dosNameU8) == 0 && // match only for DOS name
2205      StrICmp(tgtName, nameU8) != 0)      // (full name differs)
...
2254  if ((err == ERROR_ALREADY_EXISTS ||
2255       err == ERROR_FILE_EXISTS) &&
2256      StrICmp(path, tgtPath) != 0) // overwrite the file?
```

- **Operands.** `path` = `GetPath()` + `\` + `f->Name` (panel item, UTF-8 from the directory
  listing); `tgtPath` = the same `GetPath()` bytes + `finalName` (`MaskName` of what the user
  typed, then `MakeValidFileName`). The directory part is byte-identical, so the comparison is
  really name vs name. Both UTF-8 (disk panel); no legacy text. `dosNameU8`/`nameU8` come from
  `SalFindFirstFile(tgtPath)` through `SalConvertFindDataW` (always valid WTF-8).
  Edge: when `f->NameLen + l >= sizeof(path)` the code builds `path` from `f->DosName`; then the
  two strings name one file and differ under every comparator — pre-existing, not addressed.
- **Reached only when `SalMoveFile(path, tgtPath)` failed** (twice: long name, DOS name).
- **Pair C, before**: if the file system answers "already exists" for the case-only rename:
  2191 true → `FindFirstFile(target)` finds the source itself → A2 false (unless the FAT case
  of group D) → 2256 true → both are files → **overwrite prompt for the file against itself**
  → on *Yes*: `ClearReadOnlyAttr(tgtPath)`, `SalDeleteFile(tgtPath)` (this **is** the source),
  `SalMoveFile` fails → **file lost**. On local NTFS the first `MoveFile` succeeds and none of
  this runs. **After**: 2191 and 2256 false → the error text is shown, nothing is touched.
- **Pair H, before**: renaming `ĥ.txt` to `Ĺ.txt` while `Ĺ.txt` exists: 2191 false, 2256 false →
  only "already exists"; the user is not offered the overwrite. No loss. **After**: the
  prompt appears, as for any other two files.
- **Partners.** 2191 and 2256 are one decision taken twice — convert together. Quick Rename's
  "name unchanged" test `fileswn5.cpp:2845` is `strcmp` and stays. The worker's twin is group B.
- **Replacement.**
  ```cpp
  if (!SalNameEqualOrdinalCI(path, -1, tgtPath, -1) && // if it isn't just change-case (feature 092: the file system's rule)
  ...
  if (SalNameEqualOrdinalCI(tgtName, -1, dosNameU8, -1) && // match only for DOS name
      !SalNameEqualOrdinalCI(tgtName, -1, nameU8, -1))     // (full name differs)
  ...
      !SalNameEqualOrdinalCI(path, -1, tgtPath, -1)) // overwrite the file?
  ```
  Use the *name* helper on the whole strings (drop-in for `StrICmp`), not
  `SalPathEqualOrdinalCI` — that one also forgives leading/trailing backslashes, which the old
  code did not.
- **Byte-length guards**: none.

### Group B — `DoMoveFile` (`worker.cpp:5609-…`), worker thread, files and directories

```cpp
5817  if (StrICmp(op->SourceName, op->TargetName) != 0 && // provided this is not just a change of case
5818      (err == ERROR_FILE_EXISTS || err == ERROR_ALREADY_EXISTS) &&
5820      targetNameMvDir == op->TargetName)
...
5832  if (StrICmp(tgtName, fndDosNameU8) == 0 && // match only on the DOS name
5833      StrICmp(tgtName, fndNameU8) != 0)      // (the full name is different)
...
5904  if ((err == ERROR_ALREADY_EXISTS || err == ERROR_FILE_EXISTS) &&
5906      !dir && StrICmp(op->SourceName, op->TargetName) != 0 &&
5907      sourceNameMvDir == op->SourceName && targetNameMvDir == op->TargetName)
```

- **Operands.** `op->SourceName` / `op->TargetName`: full paths built by `BuildName` in
  `BuildScriptFile`/`BuildScriptDir` (exact-size heap strings). UTF-8; source from the panel
  listing or a directory enumeration, target from the typed path + mask. Producers of a
  case-only pair: F6 with a new name, F6 to the same directory typed in another case,
  *Change Case* (`fileswn6.cpp:1419-1428`, `2374-2383`, `3096-3105`).
- **Pair C, before** (again only if `MoveFile` says "exists"): 5817 true → B2 false → 5906 true →
  handles on source and target (one file) → prompt **only if** `CnfrmFileOver` or
  `OverwriteOlder` is on and *Overwrite All* was not chosen; with `OverwriteOlder` the times are
  equal → skip (safe); with confirmations off or after *All* **no prompt at all** →
  `SalDeleteFile(op->TargetName)` = the source → **file lost, possibly silently**.
  **After**: both false → `NORMAL_ERROR` dialog (Retry/Skip/Cancel).
- **Pair H, before**: moving `ĥ.txt` onto an existing `Ĺ.txt`: 5817 and 5906 false → error
  dialog, no overwrite offered. No loss. **After**: normal overwrite handling.
- **Partners.** B1/B3 are one decision; must agree with C1/C2 (which chose `ocMoveDir` for "only
  a rename") — if C says rename and B says "not just case", B only runs the harmless DOS
  check for a directory (`!dir` blocks the overwrite). Convert B and C in the same commit
  anyway. `HasTheSameRootPath` at 5628 is root-only (S4/exported), untouched.
- **Replacement.** `!SalNameEqualOrdinalCI(op->SourceName, -1, op->TargetName, -1)` at 5817 and
  5906; B2 as A2.
- **Byte-length guards**: none.
- **Review focus.** This is the site whose old behaviour can delete a file without asking.
  The reviewer should confirm the `after` body cannot reach `SalDeleteFile` for any pair the
  helper calls equal, including legacy (tier 3) text and the 7 unequal-length case pairs.

### Group C — script building (`fileswn6.cpp`)

**C1/C2, `BuildScriptDir` 1749-1811**

```cpp
1751  if (strcmp(sourcePath, targetPath) == 0) // nothing to do, bail out      <- stays strcmp
...
1773      sameDisk = (StrICmp(sourcePath, targetPath) == 0); // jen rename
1774  if (sameDisk)
1776      if (StrICmp(sourcePath, targetPath) == 0 ||
1777          targetPathState == tpsEncryptedNotExisting || targetPathState == tpsNotEncryptedNotExisting)
          -> ocMoveDir (one rename)
      otherwise: create/merge into the target, recurse, then ocDeleteDir of the source
```

- **Operands.** Full paths of the source directory and of the target directory (target path
  + masked name), UTF-8, stack buffers.
- **Pair C, before** (directory `…\Článek\x` moved to the same place typed as `…\článek`, or the
  rename route once M1 lets it through): 1773/1776 false; the target "exists" (it is the
  source) → **merge of the directory into itself**: files are `MoveFile`d onto themselves,
  then `ocDeleteDir` is queued for every source directory. By reading: directories that hold
  files fail to delete (error dialog), **empty directories are removed**. Not executed.
  **After**: 1776 true → one `ocMoveDir`, i.e. what happens for `A` → `a` today.
- **Pair H, before**: `ĥ` moved onto an existing `Ĺ`: taken for a rename → `MoveFile` fails →
  B1 false, `!dir` → error; the merge the user asked for does not happen. No loss.
  **After**: normal merge.
- **Partner.** M1 (`salamdr5.cpp:1143`), group B. 1751 stays `strcmp` (identical spelling =
  nothing to do; a case difference = a rename).
- **Replacement.** `SalNameEqualOrdinalCI(sourcePath, -1, targetPath, -1)` at both lines.

**C3, `BuildScriptFile` 2648-2663**

```cpp
2648  if (type == atMove && strcmp(op.SourceName, op.TargetName) == 0 ||
2649      type == atCopy && StrICmp(op.SourceName, op.TargetName) == 0)
          -> "cannot move/copy file to itself", return FALSE (script building stops)
```

- **Pair C, before**: copy of `Článek.txt` to `článek.txt` in its own directory (or a
  directory copied onto its own other-case spelling: every file in it) is **not** refused →
  `ocCopyFile` of a file onto itself. In `DoCopyFile` the source is open
  (`FILE_SHARE_READ|WRITE`), `CREATE_NEW` fails, overwrite prompt (or none), then
  `CREATE_ALWAYS` with share mode 0 — by reading this should fail with a sharing violation
  while the source handle is open, and the delete-then-create fallback likewise, ending in an
  error dialog. **Whether any file system/redirector lets the truncation through was not
  determined**; the ASCII check exists precisely to keep this path from being entered.
  With *Overwrite older* the times are equal and the file is skipped.
  **After**: refused with the message, as for `A.txt` → `a.txt`.
- **Pair H, before**: copying `ĥ.txt` to a new name `Ĺ.txt` is **wrongly refused** ("cannot
  copy file to itself"). **After**: allowed.
- **Replacement.** line 2649 only: `type == atCopy && SalNameEqualOrdinalCI(op.SourceName, -1, op.TargetName, -1)`.
  **2648 stays `strcmp`**: a move to the same name in another case is the rename.
- Cost: once per file of the script; the helper leaves on the byte-equal/first-byte fast paths
  or after one ASCII pass; non-ASCII paths pay two UTF-16 conversions per file — negligible
  next to the `FindFirstFile` calls around it, but it is the only S3 site inside a per-file loop.

**C4, `BuildScriptFile` 2697** and **E2, `DoCopyFile` 4526** (twins: the panel-thread pre-test
sets `OPFL_OVERWROLDERALRTESTED`, which makes the worker skip its own test)

```cpp
2697  if (StrICmp(tgtName, tgtNameU8) == 0 &&   // if it's not just a DOS-name match ...
4526  if (StrICmp(tgtName, tgtFndNameU8) == 0 && // ensure it is not just a DOS-name match ...
```

- **Operands.** last component of the target path vs the long name `FindFirstFile(target)`
  returned. Equal → the file was found by its long name → "skip when the source is not newer".
- **Pair C, before**: false → no early skip; the copy goes on to the general overwrite code,
  which applies *Overwrite older* again by time. Outcome the same, slower. **After**: early skip.
- **Pair H**: the file system would not return `ĥ.txt` for `Ĺ.txt` except through a DOS-name
  match, which cannot produce this pair. No scenario.
- **Replacement.** `SalNameEqualOrdinalCI(tgtName, -1, tgtNameU8, -1)` / `…tgtFndNameU8…`.
  Convert both in one commit.

### Group D — DOS-name-only collision (`A2`, `B2`, `D1`, `D2`, `D3`)

All five are the same two lines: `tgt == dosName && tgt != longName` on what
`SalFindFirstFile(target)` found; TRUE means "a *different* file blocks the name only through its
8.3 alias" → that file is renamed to `salXXX`, the operation is repeated, the file is renamed back.

- **Operands.** `tgtName` = `SalPathFindFileName(target)`; in D1/D2/D3 the target may come from a
  plug-in (`CSalamanderGeneral::SalCreateFileEx`/`SalCreateDirectoryEx`, `zip.cpp:4369-4382`;
  `SafeFileCreate`). Legacy (non-UTF-8) text takes the helper's tier 3 = today's answer; an ANSI
  name that happens to be valid UTF-8 is trap T10 of the research (accepted there).
  Found names: always valid WTF-8.
- **Pair C, before, on FAT** (short name `Č.TXT`, long name `č.txt`, target typed `Č.txt`): first
  half TRUE (identical bytes for `Č`, ASCII folded), second half TRUE (byte fold) → the
  existing file is taken for a DOS-alias bystander, moved aside, the target is created, the
  move back fails because the new file holds the name, the new file is deleted and the old one
  restored. Net: no loss, a window in which the file has a temporary name, then the normal
  "exists" handling. **After**: second half FALSE → straight to the normal handling.
  On NTFS with default settings short names are ASCII and the first half is exact under both
  rules, so nothing changes.
- **Pair H**: would need a file whose long name is `ĥ.txt` and whose short name equals the
  target `Ĺ.txt` — not producible by short-name generation. No scenario.
- **Both halves must use one relation** — never convert one line of a pair.
- **Replacement** (same at all five, variable names differ):
  ```cpp
  if (SalNameEqualOrdinalCI(tgtName, -1, fndDosNameU8, -1) && // match only for DOS name
      !SalNameEqualOrdinalCI(tgtName, -1, fndNameU8, -1))     // (full name differs)
  ```
- **FR-008.** D1–D3 sit in services exported to plug-ins. The change is internal to the service
  and identical for ASCII and for non-UTF-8 text; say so in the fix log rather than leave three
  of five identical tests on the old rule.

### E1 — `CorrectCaseOfTgtName` (`worker.cpp:3196-3217`)

```cpp
3213  int len = (int)strlen(foundNameU8);
3214  int tgtNameLen = (int)strlen(tgtName);
3215  if (tgtNameLen >= len && StrICmp(tgtName + tgtNameLen - len, foundNameU8) == 0)
3216      memcpy(tgtName + tgtNameLen - len, foundNameU8, len);
```

- **Operands.** `tgtName` = `op->TargetName` (whole path, exact-size heap block);
  `foundNameU8` = long name on disk. Callers: `worker.cpp:4522` (before E2) and `:5362`
  (before delete-and-recreate, so the new file keeps the on-disk case).
- **Pair C, before**: no correction → an overwritten `Článek.txt` is recreated as `článek.txt`
  on the delete-and-recreate path (cosmetic). **After**: on-disk case kept.
- **The length test must stay**: it bounds the in-place copy. For the 7 case pairs whose UTF-8
  lengths differ (`ⱥ`/`Ⱥ`…) the tail of `len` bytes is not the name; the tail is then either not
  equal or not valid UTF-8 (cut inside a character → legacy tier, which cannot match a string
  that starts on a lead byte or ASCII — continuation bytes 0x80-0xBF never fold to ≥ 0xE0 or to
  ASCII on CP125x). Result for those pairs: no correction, typed case kept. Correct and safe;
  growing the buffer is not worth it.
- **Replacement (minimal, bit-identical for ASCII).**
  ```cpp
  // feature 092: the length test is the capacity of the in-place copy, not a guard in front
  // of the comparison - an equal name of another UTF-8 length is left as typed
  if (tgtNameLen >= len && SalNameEqualOrdinalCI(tgtName + tgtNameLen - len, len, foundNameU8, len))
      memcpy(tgtName + tgtNameLen - len, foundNameU8, len);
  ```
  Optional hardening (changes nothing for real inputs, but is a theoretical ASCII delta, so
  decide in review): also require `tgtNameLen == len || tgtName[tgtNameLen - len - 1] == '\\'`.
- **Partner.** E2 runs right after it on the same pair; any order works (after a correction the
  names are byte-identical).

### Group F — `CCacheDirData::ContainTmpName` (`cache.cpp:358-416`)

```cpp
384   if (Names[i]->TmpNameEqual(tmpFullName))     // cache.h:89: StrICmp(TmpName, tmpName) == 0
          return TRUE;
...
399   if (StrICmp(tmpName, foundNameU8) == 0)
      { TRACE_E("...tmp-directory contains unknown file!"); *canContainThisName = FALSE; }
      else
406       if (foundDosNameU8[0] != 0 && StrICmp(tmpName, foundDosNameU8) == 0)
              *canContainThisName = FALSE;
```

- **Operands.** `tmpName` = the file name the caller wants in the tmp directory (an archive
  member's name, or a plug-in's name — may be legacy text); `tmpFullName` = cache directory +
  that name; `foundNameU8`/`foundDosNameU8` = what `SalFindFirstFile(tmpFullName)` found.
  Caller `CDiskCache::GetName` (`cache.cpp:1182`): a directory is used only when the function
  returns FALSE **and** `canContainThisName` is TRUE.
- **Pair C, before**: tmp directory already holds `Článek.txt` (registered for another cache
  entry — e.g. two members of one archive that differ only in case). 384: byte fold → not
  found. `FindFirstFile` finds `Článek.txt`. 399 FALSE, 406 FALSE → **the directory is accepted**
  → the new entry gets a tmp path that is the **same file on disk** as the other entry's:
  the second extraction overwrites the first one's cached file (wrong content shown for the
  first; for *edit from archive* possibly the wrong file packed back). **After**: 384 returns
  TRUE (or 399 refuses) → another tmp directory. This is the second "old behaviour can damage
  data" site and it is reachable on plain NTFS.
- **Pair H, before**: a registered `ĥ.txt` makes 384 report "already here" for `Ĺ.txt` → a new tmp
  directory is used needlessly. Harmless. 399 cannot see pair H (the file system would not find it).
- **Partner.** `cache.h:89` (M2) — convert together, otherwise 384 keeps missing what 399 now
  catches (still safe, but then the `TRACE_E` "unknown file" fires for a perfectly known
  file). `cache.h:88` and the key producers are S5 and independent of this (tmp paths are
  not keys). `DetachTmpFile` (`cache.cpp:662-667`) compares the same tmp names — S4/S5.
- **Replacement.**
  ```cpp
  // cache.h:89
  BOOL TmpNameEqual(const char* tmpName) { return SalNameEqualOrdinalCI(TmpName, -1, tmpName, -1); }
  // cache.cpp:399 / 406
  if (SalNameEqualOrdinalCI(tmpName, -1, foundNameU8, -1))
  ...
      if (foundDosNameU8[0] != 0 && SalNameEqualOrdinalCI(tmpName, -1, foundDosNameU8, -1))
  ```
  `cache.h` must see the declaration (`salunicode.h` is in the precompiled header set — verify
  when building).
- **Byte-length guards**: none.

### G1 — `pack2.cpp:501`

```cpp
501   if (StrICmp(tmpOrigName, findNameU8) == 0)
502       dst = archiveFileName;
```

`tmpOrigName` is the file-name part of the generated substitute name `PACK<hex>` + up to three
ASCII extension characters (`pack3.cpp:958-986`, the copy loop stops at a byte ≥ 128), passed
through `SalGetShortPathName`. Pure ASCII, and no non-ASCII name equals an ASCII one under
either rule → both rules give the same answer for every input. Convert for uniformity
(`SalNameEqualOrdinalCI(tmpOrigName, -1, findNameU8, -1)`) or leave with a guard annotation; no
scenario, no partner. Whether this branch is still reachable after feature 084 (which
archiver still asks for a substitute DOS name) was not checked.

### N-A — decision needed: `salamdr5.cpp:1143`

```cpp
1143  if (StrICmp(dirName, name) == 0 &&
1144      (isTheSamePathF != NULL && isTheSamePathF(path, curPath) ||
1145       isTheSamePathF == NULL && IsTheSamePath(path, curPath)))
      { // renaming a directory to the same name (except for letter case, identity is possible)
```

`dirName` = the one selected directory's name, `name` = last component of the typed target that
*exists*. TRUE → split into path + mask (a rename). FALSE → "simple target path with a universal
mask": the source is copied/moved **into** the existing directory — for pair C, into itself
(not traced to the end; no explicit "into its own subdirectory" test was found in
`fileswn6.cpp`). Core callers: `fileswn8.cpp:567`, `fileswna.cpp:182`; plug-ins reach the same
body through `CSalamanderGeneral::SalSplitGeneralPath` with their own `isTheSamePathF` (FTP).
Recommendation: convert the name half in S3 (`SalNameEqualOrdinalCI(dirName, -1, name, -1)`) —
identical for ASCII and for non-UTF-8 text — and record it as a plug-in-visible refinement;
leave the path half to S4. If the maintainer reads FR-008 as forbidding it, then C1/C2 still
convert (they are also reached by "same directory typed in another case") and the F6
case-only rename of an accented **directory** is recorded as still broken.

## 3. Suggested order (one commit, reviewable in this order)

1. **D group + A2/B2** (five identical two-line pairs) — mechanical, lowest risk, makes the
   pattern uniform before the gates move.
2. **A1+A3** (`RenameFileInternal`) — smallest gate, UI thread, easy to reason about.
3. **B1+B3** (`DoMoveFile`) — the high-value fix; review against step 2.
4. **C1+C2 (+ M1 if approved), C3** — script building, same pairs as B.
5. **C4+E2, E1** — overwrite-older twins and the case correction.
6. **F1+F2+M2** — disk cache tmp names.
7. **G1** — no-op.

Guard: after the commit add `fileswn5.cpp`, `worker.cpp`, `safefile.cpp`, `pack2.cpp`,
`cache.cpp`/`cache.h` to the `byte-fold-on-name` file list only if their remaining
`StrICmp`/`StrNICmp` lines are annotated or converted (`fileswn5.cpp:2153`, `cache.cpp:365,
662, 667`, `fileswn6.cpp:455, 689` remain until S4/S5).

## 4. Evidence probe (the 075 pattern): predicates and pairs

Predicates to compile verbatim, pre and post, each as a pure function of strings (+ the
error code / flags it reads):

- `P_onlyCase(src, tgt)` — A1/A3/B1/B3/C1/C2/C3.
- `P_dosOnly(tgt, dos, long)` — A2/B2/D1/D2/D3.
- `P_foundByLongName(tgt, long)` — C4/E2.
- `P_correctCase(tgtPath, long)` → resulting buffer (and a canary after the terminator) — E1.
- `P_tmpClash(tmpName, registered[], foundLong, foundDos)` → (returns, canContain) — F.
- `P_dirRenameGate(dirName, name)` — M1, if approved.
- derived outcome columns: "reaches `SalDeleteFile(target)`" for A and B = `exists-error &&
  !P_onlyCase && bothFiles`.

Name pairs (expected post answers must come from the helper/NTFS, pre answers from
`CharLowerA` at run time — do not hard-code CP1250):

1. ASCII parity: `a.txt`/`A.TXT`, `a.txt`/`b.txt`, `a_b`/`A_B`, `a[1].txt`/`A[1].TXT`, empty
   name, name vs name + one char, identical strings.
2. Pair C family: `Článek.txt`/`článek.txt`, `ŽLUŤ`/`žluť`, `ÄÖÜ`/`äöü`, Greek `Ω`/`ω`,
   Cyrillic `Ж`/`ж`; full paths differing in the case of a *directory* component
   (`C:\Dokumenty\Článek\a.txt` / `c:\dokumenty\článek\a.txt`).
3. Pair H family, generated at run time: every pair of 2-byte UTF-8 letters whose bytes fold
   alike under `CharLowerA` but which differ ordinally (on CP1250 the nine pairs of
   `verdicts-V2.md`, incl. `ĥ`/`Ĺ`, `Č`/`Ĝ`); the row must be skipped, not failed, on a code
   page with no such pair.
4. Unequal UTF-8 lengths: the 7 BMP pairs (`ⱥ` U+2C65 / `Ⱥ` U+023A, …) as names and as the
   last component of a path — for `P_correctCase` the expected result is "buffer unchanged,
   canary intact".
5. Not equal for the file system although close: `straße`/`strasse`, `ı`/`I`, `ſ`/`S`,
   `K` (U+212A)/`k`, NFC `č` / NFD `c`+U+030C, soft hyphen, `σ`/`ς`.
6. WTF-8: a lone surrogate name vs itself, vs its ASCII-case variant, vs another lone surrogate.
7. Legacy text: CP1250 bytes that are not valid UTF-8 on one side and on both sides
   (post must equal pre exactly); a CP1250 string that *is* valid UTF-8 (`Ă©`).
8. DOS-name rows: (`PROGRA~1`, dos `PROGRA~1`, long `Program Files`) → TRUE both;
   (`Č.txt`, dos `Č.TXT`, long `č.txt`) → pre TRUE, post FALSE; (`a.txt`, dos empty, long
   `A.TXT`) → FALSE both; (`ABC~1.TXT`, dos `ABC~1.TXT`, long `abc~1.txt`) → FALSE both.
9. `P_correctCase` rows: tail equal and same length (corrected), tail equal ASCII
   (bit-identical to pre), found name longer than the whole path (untouched), tail that would
   start inside a multi-byte character (untouched), found name that is a proper suffix of the
   last component (pre == post).
10. `P_tmpClash` rows: registered `…\Článek.txt` + new `článek.txt` (pre: accepted, post:
    refused); registered `…\ĥ.txt` + new `Ĺ.txt` (pre: refused, post: accepted when the disk
    has no such file); unknown file on disk with the same name in another case; DOS-name clash.
11. Long paths (> 260 and > 520 UTF-16 units, to cross `SAL_IDENT_STACK_UNITS`) differing only in
    the case of one accented letter near the end.

What the probe cannot show and a person or a file-system test must: whether any file system
returns "already exists" for a case-only rename (the precondition of the A/B loss), and what
`DoCopyFile` does with a file copied onto itself (C3).
