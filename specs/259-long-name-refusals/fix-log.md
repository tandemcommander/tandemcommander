# Fix log: 259 - long names: Paste copy name, Edit New File, simple-selection conversion

From backlog item `core-long-name-wrong-refusals` (review:215 / 222 leftovers). HEAD0 `7a13bdee`.

## Measured before (7a13bdee, the build of HEAD - `build.cmd` "0 min 3 sec", up to date)

- **Edit New File**: `probe/editnew259_probe.ps1` (new; hidden desktop; editor of the run
  `rundll32.exe` without arguments, registry backed up / restored). Result `probe/result_before.txt`:
  SHORT PASS (control), **REL FAIL** (panel in a 288-byte folder, "n.txt" - "The path specified is
  too long."), **ABS FAIL** (294-byte path typed - same), **CJK FAIL** (100 CJK letters + ".txt",
  304 bytes, short folder - same), OVER PASS (256 letters refused). 7 PASS / 3 FAIL; registry
  restored identical (SHA-256 CBAC630F...).
  Causes: `strlen(path) >= MAX_PATH` (feature 141's guard, the routine "still works with paths up
  to MAX_PATH - 1") and `SalGetFullName`'s default `nameBufSize = MAX_PATH` for a relative name.
- **Paste "- Copy"** (by reading; clipboard not driven): `BuildScriptMain2` writes the candidate
  into `targetName` with `lstrcpyn(..., 1 + MAX_PATH - offset)` and keeps it only when
  `strlen(targetName) < MAX_PATH`; else `mapName` stays NULL -> `BuildScriptFile` gets target ==
  source -> "Cannot copy a file to itself." (fileswn6.cpp, the `_VISTA_NEXT_1` loop and the three
  pre-Vista loops alike). 84 CJK letters + ".txt" (256 B) -> " - Copy" makes 263 B / 95 units:
  refused although valid; 250 ASCII + ".txt" -> 261 units: should be "too long".
- **IsSimpleSelection** (by reading): wide branch - `SalWToU8Alloc` NULL for the folder ->
  `WideCharToMultiByte(CP_ACP, ..., MAX_PATH)`; a name not fitting 780 B -> CP_ACP cut at 259;
  folder >= SAL_MAX_PATH_UTF8 -> `SrcPath = ""`, `DragDropToArcOrFS` says IDS_SRCPATHUNICODEONLY.
  ANSI branch - failed conversion keeps raw code-page bytes; a too long folder `lstrcpyn`-cut.
  Real Windows paths never reach these (a component <= 255 units = <= 765 B; a path <= 32767 units
  = <= 98301 B < SAL_MAX_PATH_UTF8): only low memory or a crafted drop list.

## Consumers (T002)

- `BuildScriptMain2`: only `CFilesWindow::DropCopyMove` (fileswn6.cpp) <- `DoCopyMove`
  (shellsup.cpp) <- `CImpDropTarget::ProcessClipboardData` (shellib.cpp) <- `TryCopyOrMove`
  (our data object: Paste fileswn9.cpp `ClipboardPaste`, drop fileswn0.cpp). `MakeCopyOfName` =
  copy without a name map. A FALSE result cancels the operation (`DropCopyMove` `if (res)`).
- `EditNewFile`: only `CM_EDITNEW` (mainwnd3.cpp, disk panels). Inside: `SalGetFullName`,
  `CheckPath`, `FileNameInvalidForManualCreate`, `SalCreateFileEx` (W, long path), `EditFile`
  (feature 012, SAL buffers), `PostChangeOnPathNotification`; `NextFocusName` is 780 B and
  `SalGetFullName` fills it only for a bare name under 260 B.
- `IsSimpleSelection(.., namesList != NULL)`: `ClipboardPasteToArcOrFS` (fileswn9.cpp) and
  `CImpDropTarget::Drop` (shellib.cpp ~1195); `namesList` goes to `DoDragDropOper` ->
  `DragDropToArcOrFS` (fileswna.cpp) - the only reader of `SrcPath` (checks `[0] == 0`). The other
  calls pass NULL (only the yes/no answer; unchanged).

## Decisions

- Copy name limit: 255 UTF-16 units (`SalNameTooLongForFileSystemU8`); too long -> BuildName's
  existing question (feature 141 route), no new string.
- Edit New File accepts long paths (Create Directory's way, 027).
- IsSimpleSelection: no code page for wide data; a failed conversion refuses; too long folder ->
  `SrcPathTooLong` -> "The path specified is too long.".

## Implementation

- `src/common/salcopyname.h` (new, header-only): `SalMakeCopyNameU8` - the Explorer-style copy
  name, a port of the old Vista branch, built whole into the caller's buffer; TOOLONG when over
  255 UTF-16 units or the buffer. Listed in saltests.vcxproj.
- `fileswn6.cpp` `BuildScriptMain2`: the Vista branch asks the rule for attempt 1, 2, ... into
  `copyName[SAL_FIND_NAME_U8 + 200]`; TOOLONG or a full path reaching SAL_MAX_PATH_UTF8 sets
  `copyNameTooLong`. The pre-Vista patterns (never on Windows 11) set it where they dropped the
  result, and are skipped (too long) when their 260-byte writes could pass the end of
  `targetPath` or the name is 260+ bytes. `copyNameTooLong` -> `BuildName(targetDir, name, NULL,
  &skip, &ErrTooLongTgtNameSkipAll, sourcePath, TRUE)`: Skip / Skip all -> the next item; Focus /
  Cancel -> FALSE (DropCopyMove does nothing).
- `fileswn5.cpp` `EditNewFile`: the `strlen(path) >= MAX_PATH` refusal removed; `SalGetFullName(...,
  SAL_MAX_PATH_UTF8)`; `checkPath[SAL_MAX_PATH_UTF8]`; a new name over 255 UTF-16 units ->
  `IDS_TOOLONGNAME` (the dialog comes back).
- `shellib.h` `CDragDropOperData::SrcPathTooLong`; `shellib.cpp` `IsSimpleSelection`: wide folder
  and names by `SalWToU8Alloc`, NULL refuses (`ret = FALSE`), both CP_ACP calls and `mulbyteName`
  gone; an empty name component of a malformed list stays "" (as before); ANSI branch: a failed
  conversion refuses (no raw bytes), a too long folder sets the flag (no `lstrcpyn` cut).
- `fileswna.cpp` `DragDropToArcOrFS`: `SrcPathTooLong` -> "The path specified is too long."
  (title Copy / Move error), before the Unicode message.
- No new UI string.

## Attempts and findings while implementing

1. First after-run of the probe: 8 PASS / 2 FAIL.
   - ABS: a probe defect - REL had left n.txt in the same deep folder; ABS now has its own folder
     (`$Deep2`, 289 bytes). The before verdict is unaffected (ABS was refused before any file
     appeared).
   - OVER: a real finding - without the byte guard Windows answers error 123 "invalid name"
     (Czech system text "Název souboru či adresáře nebo jmenovka svazku je nesprávná.") for a
     256-unit name, not "too long"; the clarification's first answer (the file system's own
     error) was wrong. Fix: the 255-unit check with IDS_TOOLONGNAME; the OVER row now accepts
     only "too long" (it caught the gap - a working negative control of that row).
2. Second after-run: 10 PASS / 0 FAIL.
3. After the review (OVER requires "too long name", rows U255 / U256 added): 14 PASS / 0 FAIL.

## Measured after

- Probe `probe/result_after.txt`: SHORT, REL, ABS, CJK, OVER all PASS (10 / 0), registry
  restored identical (SHA-256 CBAC630F...), fixture removed, nothing left running.
- `saltests`: 24,543 checks, 0 failed (`TestCopyName259`, 28 checks; 29 after the review). Negative control: the
  rule's limit replaced by the old `strlen(out) >= MAX_PATH` -> 5 failed (84 CJK + attempt 2,
  245 + ".txt", 244 + ".txt" attempt 2, ...); restored, 0 failed.
- `python tools/check_encoding.py --strict`: TOTAL 0. `build.cmd`: BUILD SUCCEEDED.
- Paste in its own folder and the multi-item Skip: NOT DRIVEN (clipboard) - owed to a person.
- IsSimpleSelection: by reading (only low memory / crafted lists reach the changed routes).

## Limits left

- A new file name of 260+ bytes made by Edit New File is not focused afterwards (`SalGetFullName`
  fills `nextFocus` only under MAX_PATH; no data issue).
- `CCopyMoveRecord::AllocChars` (shellib.cpp, the ANSI route of our own copy / move) keeps the
  raw-bytes fallback on a failed conversion - outside this item (only a failed CP_ACP decoding
  or low memory reach it).
- Create Directory takes a relative name in a 260+ byte panel path through `SalGetFullName`'s
  default MAX_PATH as well (`fileswn5.cpp` `CreateDir`) - seen while comparing, not measured.

## Review

Refute-first review 1 (independent agent, at 16c7b517): **no MUST**. It re-ran build, saltests
(24,543 / 0), the encoding guard (0) and the probe (10 / 0, registry identical); its own negative
control (the rule's limit 255 -> 256 units) failed 2 checks, restored -> 0.
- SHOULD 1 - the Paste symptom has no runtime evidence (clipboard): recorded as a person-step item
  with the exact steps (closing).
- SHOULD 2 - `CCopyMoveRecord::AllocChars(const wchar_t*)` (shellib.cpp) keeps a CP_ACP fallback
  on the Paste route itself (only on low memory): outside the item's site -> Inbox item
  (review:259).
- SHOULD 3 - the OVER row accepted the old wrong answer ("The path specified is too long."): it now
  requires "too long name"; rows U255 (251 CJK + ".txt" = 255 units, created) and U256 (refused)
  added. Probe 14 / 0.
- NOTE - "a higher attempt is never shorter" is false for a number with leading zeros: header,
  contract and comment reworded; a check pins it (`"x (001).txt"` attempt 2 -> `"x (2) - Copy.txt"`).
  The only effect is a refusal (as the old code).
- NOTE - stale `shellib.h` comments of `SrcPath` / `Names`: updated.
- NOTE - the question names the source name, and a folder gets the file text / "Skip all" flag
  (`IDS_NAMEISTOOLONG`, `ErrTooLongTgtNameSkipAll`) - accepted: feature 141's route, existing text.
- NOTE - `IDS_SRCPATHUNICODEONLY` in `DragDropToArcOrFS` is no longer reachable - kept as a
  defensive check.
- NOTE - Edit New File's full-path limit is judged in bytes (SAL_MAX_PATH_UTF8), not 32,767 units -
  only extreme ASCII paths get the system's text instead of "too long"; accepted (Create Directory
  does the same).

No MUST -> no second review needed (SKILL.md step 7).
