# Implementation notes: feature 141 - a name built from a mask is never cut

Session 2026-10-14, source changes only. **Nothing was built, the program was not run, nothing
was committed.** Everything under "measured" is measured by reading the code; the checks are
standalone programs and syntax-only compiles (section 6). The GUI rows are owed to the probe.

## 1. Measured by reading: before -> now

The test name is 250 CJK letters = 750 bytes of UTF-8 = 250 UTF-16 units (legal on NTFS).

| Site | Before | Now |
|---|---|---|
| `MaskName` (`src/masks.cpp`) | NULL mask: `lstrcpyn` - a byte cut at `bufSize - 1`. Other masks: the loops stop at `endBuf` without a word. `?` copies one BYTE of the name, every BYTE of a literal skips one BYTE of the name (`x*.*` on `šabc.txt` = `x` + the second byte of `š` + ... = invalid UTF-8). | Wrapper of `SalMaskNameLegacyU8` (`src/common/salmaskname.h`): same contract for the plug-in interface (cut result, returns the buffer). New `MaskNameChecked(buffer, bufSize, name, mask, BOOL* cut)`: whole result, or `*cut = TRUE` and an EMPTY buffer. `?` and a literal work on whole characters (decision D1). |
| Quick Rename on a disk, `RenameFileInternal` (`src/fileswn5.cpp`) - the typed name is the MASK | `finalName[2 * MAX_PATH]`: a typed name of 250 letters is cut at 519 bytes = 173 letters (a boundary by chance: 519 = 173 x 3), `SalMoveFile` renames the file to the 173-letter name. **Really cut, no message.** With one ASCII letter in front the cut is inside a letter: the Sal* file API refuses invalid UTF-8 with error 123, shown. | `finalName[SAL_FIND_NAME_U8]` + `MaskNameChecked`. 250 letters: renamed whole. A result that does not fit (780 bytes = at least 260 units) or has more than 255 UTF-16 units: "Cannot finish operation because of too long name." (`IDS_TOOLONGNAME`, title `IDS_ERRORRENAMINGFILE`), `*tryAgain` stays TRUE - the dialog / the edit line comes back with the text. |
| - the dialog's buffer (caller `RenameFile`) | `editName[SAL_FIND_NAME_U8]` (780), `CB_LIMITTEXT` 779 UTF-16 units; text over 779 bytes is cut at a whole character by `SalGetWindowTextU8` (`SalWToU8Truncate`). Such a cut text has >= 259 units. | Unchanged. The cut text can no longer become a name: >= 259 units is refused by the 255-unit check above (before: the file system refused it with a system error). |
| - the in-place line (`HandeQuickRenameWindowKey`) | 137: `newNameW[MAX_PATH]`, `newName[SAL_FIND_NAME_U8]`, 260 units or more refused. A typed 250 letters reached `RenameFileInternal` whole - and was cut THERE at 519 bytes. | Unchanged code; the cut behind it is gone. 256-259 units: `IDS_TOOLONGNAME`, the line stays. |
| - the rest of `RenameFileInternal` | `tgtPath[SAL_MAX_PATH_UTF8]` guarded by a length check (else `IDS_TOOLONGNAME`); `NextFocusName[SAL_FIND_NAME_U8]` receives `tgtPath + l` by `strcpy` (at most 765 bytes now that longer names are refused). A file-system error of `SalMoveFile` IS shown (`GetErrorText(err)`, title `IDS_ERRORRENAMINGFILE`), not swallowed. | No further cut found. |
| Copy / Move, directory (`BuildScriptDir`, `src/fileswn6.cpp`) | `finalName` is `malloc(SAL_MAX_PATH_UTF8)`, declared at the top of the function (holder `CFinalNameBuf`), but `MaskName` was told `2 * MAX_PATH + 200` (720). Default mask `*.*` becomes a NULL mask = `lstrcpyn`: 750 bytes are cut at 719 = 239 letters + 2 bytes of the next: invalid UTF-8 - the directory cannot be created (error 123 at the worker, by reading). A name whose byte 719 is a boundary (e.g. two ASCII letters in front) **is created under the shorter name** - and with Move the content goes there. Affects names of 240-255 three-byte letters; also every NESTED directory (they pass a NULL mask). | `MaskNameChecked(finalName, SAL_MAX_PATH_UTF8, ...)`. Never cut with the default mask. A result that does not fit, or (with a real mask) has more than 255 units, goes into the site's existing route: `IDS_TOOLONGNAME2` with Skip / Skip all (`ErrTooLongTgtDirNameSkipAll`) / Focus, the source name in the text. |
| Copy / Move, file (`BuildScriptFile`) | `finalName[2 * MAX_PATH + 200]` on the stack: the same cut at 719 bytes, then `BuildName` builds the target from the cut name. Same two outcomes (error 123 per file, or a file under a shorter name; Move: the source is renamed away). Nested files too. | `finalName[SAL_FIND_NAME_U8]` + `MaskNameChecked`; refused names go through `BuildName`'s existing "too long name" question (`IDS_NAMEISTOOLONG`, Skip / Skip all `ErrTooLongTgtNameSkipAll` / Focus) with the SOURCE name - new parameter `nameTooLong` of `BuildName` (D4). |
| Copy / Move with a typed new name (`BuildScriptMain`) - found on the way | `char nameMask[2 * MAX_PATH]; lstrcpyn(nameMask, mask, ...)`: the mask (= the last component typed in the Copy dialog, it lives in the dialog's `SAL_MAX_PATH_UTF8` buffer) is cut at 519 bytes BEFORE `MaskName` sees it. F5 on one file + target `D:\t\<250 letters>` = a copy named by the first 173 letters. **Really cut, no message.** `SalSplitGeneralPath` has no length check for the mask. | `nameMask[SAL_FIND_NAME_U8]`; a mask of 780 bytes or more: `IDS_TOOLONGNAME` (title `IDS_ERRORTITLE`), the script is not built (`return FALSE`), nothing is copied. |
| `BuildName` (`src/salamdr1.cpp`) | Heap result, refuses a full path of `SAL_MAX_PATH_UTF8` or more with the Skip question. Does not cut. | The same + `nameTooLong`. |
| Edit New File (`CFilesWindow::EditNewFile`) - found by the sweep | `path[MAX_PATH]` is the dialog's buffer: a typed name over 259 bytes (87 CJK letters) is cut at a whole character by the dialog's transfer and **the file is created under the cut name**. | The dialog's buffer is `SAL_MAX_PATH_UTF8`; a text of `MAX_PATH` bytes or more is refused (`IDS_TOOLONGPATH`) and the dialog comes back. The routine itself still works with paths under 260 bytes (not made long-path capable here). |
| FTP Quick Rename with a mask (`fs5.cpp` ~554) | `targetName[2 * MAX_PATH]`, then `strlen >= MAX_PATH` -> refused (feature 131). A cut at 519 is still >= 260: **refused, never used.** | Not changed. |
| FTP download (`fs4.cpp` ~1121, ~1130) | Source = a server name (`CFileData::Name`). `lstrcpyn` / `MaskName` into `targetName[2 * MAX_PATH]`: a name over 519 bytes is cut (possibly inside a letter). It cannot become a file: the local name goes through `DiskWork.Name[MAX_PATH]` and `SalPathAppend(..., MAX_PATH / PATH_MAX_PATH)` - 260 bytes or more = "name too long" for the item, or the user's "rename automatically" shortens it (137, whole characters). Leftover: with a real mask + automatic rename the mask's extension is lost in the cut; the queue shows a torn name. | **Not changed** (D9) - recorded for NEXT-WORK. |
| FTP upload (`fs5.cpp` ~1154) | Source = a disk name, up to 765 bytes. `useMask` is TRUE for `*.*`, so `MaskName(targetName, 2 * MAX_PATH, ...)` cuts a 750-byte name at 519 bytes (173 letters). What follows refuses it anyway, cut or whole: a directory by `FTPPathAppend(..., FTP_MAX_PATH = 301)`; for a file `PrepareFTPCommand` cannot build `STOR` in its 501-byte buffer (see NEXT-WORK N3). So no file under a cut name was found - but the cut name travelled through the queue. | `targetName[3 * MAX_PATH]`: a disk name is never cut; a buffer filled to its last byte (`strlen == size - 1`) is taken for a cut: `IDS_TOOLONGPATH` / `IDS_FTPERRORTITLE` (the message feature 131 uses for the Quick Rename mask), `ok = FALSE` - nothing is uploaded. Nested items (`operatsa.cpp`) always passed whole names; top-level items now behave the same. |
| PictView Rename (`render1.cpp` ~2851) | Not `2 * MAX_PATH`: `finalName[3 * MAX_PATH]`, `newName[3 * MAX_PATH]`. The check `_tcslen(finalName) >= SizeOf(newName)` can never be true. A result cut at 779 bytes has >= 260 units - the file system refuses it (shown). **No reachable cut name.** | A full buffer is taken for a cut and refused with the site's `IDS_TOOLONGNAME` (the dead check made live). |
| Demo plug-in (`demoplug/fs2.cpp`) | `2 * MAX_PATH` and `3 * MAX_PATH + 100` buffers. | Not changed (sample code, `demoplug=off` in `plugins.cfg`). |
| FTP upload automatic rename (`FTPGenerateNewName`, `ftputils.cpp`) | Every shortening is at a byte: the copy loops stop at `end` (255 / `MAX_PATH - 4`) in the middle of a character; "shorten the name" removes `cut` bytes in front of the dot; "just trim the end" sets `n = newName + LIMIT - suffixLen`; the Windows phase takes the name with `lstrcpyn(..., MAX_PATH)` and the core's `SalMakeValidFileNameComponent` cuts it again at byte 256. In the standalone harness the old code produced invalid UTF-8 in 82,665 of 321,848 rounds with long UTF-8 names. | All of these cut at a whole character (`SplU8WholePrefixLen`; the bytes in front of the dot through the new pure `SalFtpCutBeforeExt`, `src/common/salftpautoren.h`). New code: 0 invalid, 0 over the limit, ASCII results identical (section 6). VMS phase 1 and Tandem / AS/400 produce ASCII only - not touched. |

Wrong premises of the brief, recorded:

- **`ErrTooBigFileFAT32SkipAll` at the directory site**: no slip exists. `BuildScriptDir` uses
  `ErrTooLongTgtDirNameSkipAll` in both places (test and set); `ErrTooBigFileFAT32SkipAll` is
  used only in the FAT32 block of `BuildScriptFile`, correctly. Nothing changed.
- **PictView** has `3 * MAX_PATH` buffers, not `2 * MAX_PATH`.
- **"nothing of the name is left" in the FTP generator** cannot happen: the limits are 255 and
  `MAX_PATH - 4` bytes, a suffix is at most 13, a character at most 4 bytes. When rounding
  would remove the whole name part, the generator falls to its own next way ("trim the end").
  The fuzz found 0 empty names. So `FTPGenerateNewName` stays `void` and **the two callers
  (`operatsa.cpp` ~501, `operatsb.cpp` ~1184) are unchanged** - no failure route was added.
  (For the record: the callers have no check for an empty name; their terminal error for a
  failed automatic rename is `ITEMPR_UPLOADFILEAUTORENFAILED` / `ITEMPR_UPLOADCRDIRAUTORENFAILED`.)

## 2. Decisions where the brief left room

- **D1 - `?` and a literal take whole characters, on BOTH sides. One deviation from the
  brief's condition.** A `?` copies one whole UTF-8 character of the name; a literal character
  of the mask is copied whole and replaces one whole character of the name. Shown by checks:
  ASCII name + ASCII mask is byte-identical to the old routine (400,000 random pairs, every
  buffer size from 1 to result + 3; 12.2 million checks), and masks of `*` and `.` only are
  identical for any UTF-8 name (about 100,000 cases). **Not identical: an ASCII name with a
  NON-ASCII literal in the mask in front of a wildcard** - `é*.*` on `abc.txt` was `éc.txt`
  (the two bytes of `é` skipped two letters), now `ébc.txt`. The brief asked for identity for
  pure-ASCII names; the name-side-only variant that keeps it makes `é*` on `žlutý` worse than
  today, so the mask side went with it. To revert: in `Build`, default branch, copy one byte
  of the mask per round. Also note this reaches plug-ins through `CSalamanderGeneral::MaskName`
  (same routine) - FR-004 says "unchanged behaviour"; for multi-byte text it changed for the
  better, for ASCII not at all. The maintainer / the review should confirm.
- **D2** - `MaskNameChecked` leaves an EMPTY buffer on a cut (a caller that forgets the flag
  gets no name instead of another file's name). The legacy form reports the cut too
  (`SalMaskNameLegacyU8(..., BOOL* cut)`), used by `MaskName` with NULL.
- **D3 - a 255-unit check beyond the brief** (`SalNameTooLongForFileSystemU8`): the spec's test
  says a 256-letter name is refused "with the name too long message"; without the check the
  file system's error 123 / 206 would be shown instead. Used in `RenameFileInternal` always and
  in the two Copy / Move sites only when a real mask was applied (with the default mask the
  result is the source name, which exists). Invariant that makes the buffers sufficient:
  780 bytes of UTF-8 are at least 260 UTF-16 units, so whatever does not fit
  `SAL_FIND_NAME_U8` is no name of a Windows file system.
- **D4** - `BuildName` got a trailing default parameter `BOOL nameTooLong = FALSE` instead of a
  copy of its Skip / Skip all / Focus box in `fileswn6.cpp`.
- **D5** - a mask of 780 bytes or more in `BuildScriptMain`: one message, the operation is not
  started (no Skip - it concerns every item).
- **D6** - Edit New File fixed although it was not in the list (it is a Create route and it
  really cut).
- **D7** - the pure FTP step lives in `src/common/salftpautoren.h` (precedent:
  `salftpsecret.h`, `salftpanon.h`) so that saltests includes it without FTP headers.
- **D8** - FTP upload: the full-buffer refusal cancels the whole operation with a message (the
  site has no per-item error state at queue-building time; reachable only with a mask that
  makes a result of 779 bytes or more).
- **D9** - `fs4.cpp` (download) left alone: the cut cannot reach a file and the site has no
  error route but "cancel everything".
- **D10** - the two new headers are listed in `src/vcxproj/saltests/saltests.vcxproj`.

Text that is not UTF-8 (the contract of `SplU8WholePrefixLen` / `SalFtpCutBeforeExt`): both
step back over bytes `0x80-0xBF`. On code-page text they therefore cut EARLIER than asked (a
run of such bytes is dropped), never later and never over the limit - not "exactly the old
byte cut". Upload names come from the disk (UTF-8 by the interface), so the generator does not
see code-page text. `salmaskname.h` treats a lead byte without its continuation bytes as a
single character (checks in saltests).

## 3. For `specs/NEXT-WORK.md`

- **N1 (medium) - `CCopyMoveDialog::Transfer` cuts a typed text that does not fit the caller's
  buffer** (`SalGetWindowTextU8` -> `SalWToU8Truncate`, whole character, no word):
  `CB_LIMITTEXT` counts UTF-16 units, the buffer bytes. Reachable: **Create Directory on a
  plug-in file system** (`fileswn5.cpp`, buffer `2 * MAX_PATH`): 174 or more CJK letters typed
  -> the plug-in receives the first 173. 137's review called this route "no cut" - it looked
  at the limit, not at the conversion. Rule of 104: a value that does not fit is refused.
  (Quick Rename's dialog: harmless since 141 - the cut text is refused as too long.)
- **N2 (low) - Paste into the same folder ("name - Copy")**, `BuildScriptMain2`
  (`fileswn6.cpp` ~864-1081): the new name is built with `MAX_PATH` limits; for a name whose
  "- Copy" form is 260 bytes or more (about 83 CJK letters) no name is made and the paste ends
  with "cannot copy to itself". Not a cut - a refusal with a misleading text.
- **N3 (medium, FTP) - upload of a file whose name has about 494 bytes or more**:
  `PrepareFTPCommand` (`ctrlcon2.cpp`) fails in its `200 + FTP_MAX_PATH` buffer, returns FALSE
  with length 0, and the callers ("cannot report an error") send the empty command and wait.
  By reading only. Directories fail cleanly (`FTPPathAppend`, `ITEMPR_...`).
- **N4 (low, FTP) - download, `fs4.cpp`**: `targetName[2 * MAX_PATH]` is cut at a byte for a
  server name over 519 bytes (see the table): torn text in the queue, the mask's extension lost
  with automatic rename. `FTPOpenedFiles` (`operats9.cpp` ~1849) keeps names cut at 259 bytes.
- **N5 (already recorded by 137)** - the core's `SalMakeValidFileNameComponent` cuts at byte
  256, possibly inside a character; `fileswn5.cpp` ~882 feeds it `lstrcpyn(validTmpName,
  f->Name, MAX_PATH)` (view / edit of a file from an archive or a server).
- **N6 (cosmetic)** - no focus on the new item after Create Directory / Copy with a name of 260
  bytes or more (`nextFocus` guards `< MAX_PATH`); `lstrcpyn(NextFocusName, newName, MAX_PATH)`
  after a plug-in's Create Directory may end inside a character.
- **N7 (low)** - Edit New File is limited to paths under 260 bytes (`checkPath[MAX_PATH]`,
  `SalGetFullName` default size).
- **N8** - the demo plug-in's `MaskName` buffers.

## 4. Not done

- No build, no `saltests` run as a whole (only `TestMaskName141` extracted verbatim), no GUI
  probe (T002, T007), no review (T008), no `fix-log.md` / `CHANGELOG.md` /
  `FEATURE-HISTORY.md` / `NEXT-WORK.md` edits (T009), `tasks.md` not ticked.
- `src/plugins/sftp/**` not touched. `CSalamanderGeneral::MaskName` (`src/zip.cpp`) not touched.
- `fs4.cpp`, the demo plug-in, the FTP callers of `FTPGenerateNewName`: unchanged (reasons above).
- No FTP-side test harness exists (`src/plugins/ftp/test` is not there); the generator as a
  whole is checked only by the scratch harness, the shortening step by saltests.

## 5. Places to look at first when building

All changed translation units passed a syntax-only compile, so these are behaviour, not
syntax, doubts:

- `src/fileswn6.cpp` `BuildScriptMain`, the new `return FALSE` for a too long mask: it runs
  while the "analysing" wait window is up and the main window is disabled (as the existing
  message box a few lines above it does) - not driven.
- `src/fileswn5.cpp` `EditNewFile`: `path` is now a `SAL_MAX_PATH_UTF8` stack array (as in
  `CreateDir`); the `continue` after the refusal re-creates the dialog with the typed text.
- `src/salamdr1.cpp` `BuildName(..., nameTooLong)`: with `nameTooLong` the Focus button posts
  the SOURCE name (the caller passes it as `name`) - intended.
- `src/plugins/ftp/fs5.cpp` ~1152: `break` out of the enumeration with `ok = FALSE` (the
  existing error exit of that loop).
- `src/saltests/saltests.cpp` compiled with `/Zs` only; the expected count of checks rises by
  467.

## 6. Checks

Scratch directory: `%TEMP%\claude\E--Projects-tandemcommander\3cc3c426-...\scratchpad\impl141`.

| Check | Result |
|---|---|
| `t_mask.exe` - the old `MaskName` (copied from HEAD) against `salmaskname.h`: 400,000 random ASCII name / mask pairs, every buffer size 1 .. result + 3 (old cut text == legacy form, cut told exactly when the text is not the whole one, checked form whole or empty, nothing written behind the buffer); 300,000 UTF-8 pairs (result valid UTF-8; masks of `*` and `.` only identical to old) | 12,221,081 checks, 0 failed (1,680,338 cut cases seen) |
| the table in `TestMaskName141` | printed by the OLD code (`t_mask.exe table`), 73 rows taken |
| `t_saltest141.exe` - `TestMaskName141` extracted verbatim from `saltests.cpp` | 467 checks, 0 failed |
| negative control: the same with `CharLen` returning 1 and `SalFtpCutBeforeExt` not stepping back | 32 failed |
| `t_ftp.exe` - `FTPGenerateNewName` of HEAD and of the working tree side by side (generated from the sources, stand-ins for the core's two services), 600,000 cases, all 9 server types, up to 3 rounds each | ASCII names: 0 differences in result, phase and index. UTF-8 names, 321,848 rounds: new invalid 0, old invalid 82,665, identical to old 239,033, the rest shorter; over the limit 0; empty 0; nothing written behind `MAX_PATH`. 651,577 checks, 0 failed |
| measured case in `t_ftp.exe`: 125 x `š` + `a.txt` (255 bytes), UNIX | old: 255 bytes, invalid UTF-8; new: 254 bytes, ends `šš (2).txt` |
| `cl /Zs` (Debug x64 defines of `salamand.vcxproj`): `masks.cpp`, `fileswn5.cpp`, `fileswn6.cpp`, `salamdr1.cpp`, `zip.cpp` | clean (one old warning C4244 in `zip.cpp`) |
| `cl /Zs` `saltests\saltests.cpp` | clean |
| `cl /Zs` (plug-in defines) FTP `ftputils.cpp`, `fs5.cpp`; PictView `render1.cpp` | clean |
| `python tools/check_encoding.py` | `TOTAL: 0 finding(s)` |
| BOM / line endings of the changed files against HEAD | kept (new headers: BOM + CRLF) |

## 7. Files

New: `src/common/salmaskname.h`, `src/common/salftpautoren.h`.
Changed: `src/masks.cpp`, `src/masks.h`, `src/consts.h`, `src/salamdr1.cpp`, `src/fileswn5.cpp`,
`src/fileswn6.cpp`, `src/saltests/saltests.cpp`, `src/vcxproj/saltests/saltests.vcxproj`,
`src/plugins/ftp/ftputils.cpp`, `src/plugins/ftp/fs5.cpp`, `src/plugins/pictview/render1.cpp`.

## 8. After the review (2026-10-14)

The independent review found no critical or medium defect (its ASan differential harnesses
agree with section 6; the GUI probe passed 14 / 0 on a build of this code). Its low findings,
all taken. Same limits as before: no product build, the program was not run.

| # | Finding | Change |
|---|---|---|
| 1 | The FTP generator could return an EMPTY or much shorter name for text that is not UTF-8: `SplU8WholePrefixLen` (and the first `SalFtpCutBeforeExt`) step back over every byte `0x80-0xBF` - a 267-byte name of bytes `0x80-0xAF` became "". Not reachable from today's callers (upload names come from the disk), but the header promised "never worse than before". | New `SalFtpWholePrefixLen` in `src/common/salftpautoren.h`: at most 3 bytes back, and only when the byte found there is a UTF-8 lead byte (`>= 0xC0`) whose sequence reaches over the cut; otherwise the plain byte cut. `SalFtpCutBeforeExt` is built on it, and `FTPGenerateNewName` uses it in all 10 places instead of `SplU8WholePrefixLen`. **`SplU8WholePrefixLen` (`splunicode.h`, feature 137) is not changed** - its contract is "UTF-8 text" and says nothing about a bound; the header comment of `salftpautoren.h` states the difference. For valid UTF-8 the two return the same (checked). |
| 2 | A cut moved back to a whole character could leave the dot in front of the dropped character at the very end of the name (UNIX phase 0, MVS: `<252 bytes>.` + a CJK letter). | In those two copy loops: when the step back really shortened the name and it now ends with a dot, the dot goes too (UNIX: `dot = NULL` when it was that dot). Only after a step back - a name that ends with a dot itself, or is cut right behind one at a byte that is a boundary, is as in HEAD (ASCII identity kept). |
| 3 | The "name too long" boxes lost their second line for long names (fixed buffers `2 * MAX_PATH + 100`): `BuildName` (`src/salamdr1.cpp`), now reached with names up to 765 bytes, and `IDS_TOOLONGNAME2` in `BuildScriptDir` (`src/fileswn6.cpp`). | Both texts are built with `CSalHeapString::Printf` (exact size, freed by its destructor on every way out); the fixed buffer stays as the fallback when memory is low (cut at a whole character, as before). |
| 4 | **Old defect, identical in HEAD, fixed on the way**: OpenVMS automatic rename, phase 0, the `alreadyRenamedFile` block: removing `_number` moved `n` and `dot` but not `semicol`; without a dot `dot = semicol` was then stale and `memmove(dot + suffixLen, dot, (n - dot) + 1)` got the size -1. | `if (semicol != NULL) semicol -= end2 - s2;` - what the phase-1 twin already does. Input that fails on HEAD: OpenVMS, a file, already renamed, `a_123;1` - HEAD's code run in its own process ends with exit code 0xC0000409 (`t_ftp.exe oldcrash`); now `a_124;1`. With a longer version (`a_1;12345`) HEAD did not crash but inserted the suffix inside the version. |
| 5 | (record only) The `?` / literal whole-character rule of `salmaskname.h` also applies to plug-in callers that hold names in a code page. | No code change. **Known deviation**: through `CSalamanderGeneral::MaskName` the FTP plug-in (`fs4.cpp`, `fs5.cpp`) may pass names of a server that is not UTF-8; two or more code-page bytes that happen to have the shape of a UTF-8 sequence (a byte `0xC0-0xF7` followed by the right number of bytes `0x80-0xBF`) are taken by `?`, and replaced by a literal, as ONE character where the old routine took one byte. Text without such pairs, and all ASCII, is as before. |

This replaces the paragraph on text that is not UTF-8 at the end of section 2 for the FTP
generator: it now keeps the plain byte cut for such text (at most 3 bytes shorter when a lead
byte's sequence reaches over the cut), never an empty name.

Checks after these changes:

| Check | Result |
|---|---|
| `t_mask.exe` (mask routine against HEAD's; unchanged code, run again) | 12,221,081 checks, 0 failed - ASCII identical for every buffer size |
| `t_ftp.exe`, 900,000 cases (ASCII / UTF-8 / code-page names by thirds), 9 server types, up to 3 rounds. Reference for identity: HEAD + only the one line of finding 4 (generated from `git show HEAD`); HEAD itself is run in every round that cannot reach that line (960,356 rounds) and agrees with the reference in all of them | **ASCII names: 0 differences** in result, phase and index. UTF-8, 321,750 rounds: new invalid 0 (HEAD invalid 83,067), identical to HEAD 238,556, none longer, 0 ending with a dot left by the cut. Code-page names, 325,752 rounds: empty 0, none more than 8 bytes shorter than HEAD, identical to HEAD 313,974. Over the limit 0, empty 0, nothing behind `MAX_PATH`. 1,877,146 checks, 0 failed |
| finding 2 in `t_ftp.exe`: 252 x `a` + `.` + CJK (UNIX), 253 x `a` + `.` + CJK (MVS, limit 256) | HEAD: 255 / 256 bytes, invalid UTF-8; new: 252 / 253 bytes, no dot at the end |
| finding 1 in `t_ftp.exe`: 267 bytes `0x80-0xAF` | the same result as HEAD for every server type that keeps such bytes |
| finding 4 in `t_ftp.exe`: `a_123;1`, `a_1;12345`, `NAME_9;2`, `a_123.txt;1`, `a_123` | `a_124;1`, `a_2;12345`, `NAME_10;2`, `a_124.txt;1`, `a_124`; `t_ftp.exe oldcrash` (HEAD): exit code 0xC0000409 |
| `t_saltest141.exe` - `TestMaskName141` verbatim, with the new checks of `SalFtpWholePrefixLen` (valid UTF-8 = `SplU8WholePrefixLen`; the 267-byte run; stray and complete sequences; 2,000 random byte strings: never more than 3 back) | 3,020 checks, 0 failed (section 5's "rises by 467" is now 3,020) |
| `cl /Zs`: `masks.cpp`, `fileswn5.cpp`, `fileswn6.cpp`, `salamdr1.cpp`; `saltests.cpp`; FTP `ftputils.cpp`, `fs5.cpp`; PictView `render1.cpp` | clean |
| `python tools/check_encoding.py` | `TOTAL: 0 finding(s)` |

Not changed, said for completeness: OpenVMS phase 0 and z/VM keep a dot in front of a dropped
character (there the dot is the separator of the extension the branch tracks); the trailing-dot
drop removes one dot, as the neighbouring "trim the end" branches do.
