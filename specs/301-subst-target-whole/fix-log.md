# Fix log - 301-subst-target-whole

Backlog item `a-subst-drive-whose-target-is-long-or-outside-the-code-page` (source review:289).

## Measurement at 0f7bd140 (before any change)

Build: `.\build.cmd` (Debug x64) at HEAD; ACP 1250.

1. Reachable lengths (PowerShell P/Invoke, scratch script): a target folder of 80 CJK letters
   (138 UTF-16 units incl. `\??\`, 298 UTF-8 bytes) - `subst.exe` rc 0, `DefineDosDeviceW` ok,
   `QueryDosDeviceW(260)` returns it. A folder of 359 units - `subst.exe` "Invalid parameter",
   `DefineDosDeviceW` ok, `QueryDosDeviceW(260)` fails with 122 (ERROR_INSUFFICIENT_BUFFER),
   `QueryDosDeviceW(1024)` returns it.
2. Probe `probe/subst_probe.ps1` (then in the scratch folder), on the hidden desktop:
   `powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\subst_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before"`
   - first run with the Recycle Bin on: the shell's own delete dialog came up (no discrimination);
     the probe now turns the Recycle Bin off (as 197's probe) and matches the Czech or English
     word of `IDS_QUESTION_JUNCTION`.
   - result (`probe/result_before.txt`): SHORT DEL PASS / INFO PASS; **CJK DEL FAIL** ("Are you
     sure you want to delete directory "J"?"), **CJK INFO FAIL** (drive type line empty); LONG
     DEL PASS (the target is not read at all, the path stays unresolved and works through the
     subst) / INFO PASS ("local drive"). 7 PASS / 2 FAIL; registry restored identical, subst
     definitions removed.
3. By reading:
   - `MyQueryDosDevice` falls back to `QueryDosDevice` (A) when the UTF-8 form does not fit 260
     bytes - the '?' target; `GetSubstInformation` copies with `lstrcpyn`.
   - `ResolveSubsts` (also the plug-in API `CSalamanderGeneral::ResolveSubsts`, MAX_PATH contract)
     splices the '?' target; consumers: `fileswn8.cpp` delete question of a link (the FAIL above),
     `MyGetDriveType`, `MyGetDiskFreeSpace`, `MyGetVolumeInformation` (Drive Information - the
     empty line), `ResolveLocalPathWithReparsePoints`, `HasTheSameRootPathAndVolume`,
     `PathsAreOnTheSameVolume`, `GetResolvedPathMountPointAndGUID`, undelete plug-in.
   - `fileswn9.cpp` Copy as UNC: `GetSubstInformation(.., target, MAX_PATH)` into a 520-byte buffer -
     the '?' path would be copied to the clipboard.
   - `drivelst.cpp` `BuildData`: the menu text of a subst drive = the '?' target.
   - `drivelst.cpp` `drvtRemote` `l = min(l, MAX_PATH - 1)`: `netRemotePath` is `char[26][MAX_PATH]`,
     so `l <= MAX_PATH - 1` always - **never cuts**; no change.
   - `bugreprt.cpp`: "Device: %s" of `MyQueryDosDevice` - the '?' text.

## Decisions

See spec *Clarifications*.

## Analyze

`speckit-analyze`: 0 CRITICAL, 0 HIGH; fixed U1 (FR-005 names the subst-to-UNC case - the only
one the menu shows), U2 (the Copy as UNC person step needs a shared folder), I1 (FR-004 "fewer
than 260 units"); C1 accepted (FR-009 is a constraint, checked by build and review).

## Implementation

- `src/common/salsubst.h` (new, header-only): `SalSubstTargetToPathU8` + `SAL_SUBST_TEXT_U8_MAX`.
- `src/salamdr2.cpp`: `QueryDosDeviceWholeW` (heap, grows on ERROR_INSUFFICIENT_BUFFER up to
  64 Ki units); `MyQueryDosDevice` without the code-page fallback (refuses a text that does not
  fit); `GetSubstInformation(.., BOOL* tooLong = NULL)` through the rule; `ResolveSubsts` returns
  FALSE with the path unchanged on a refused target.
- `src/dialogs3.cpp` Drive Information: `substTarget[SAL_SUBST_TEXT_U8_MAX]`, the line composed only
  when it fits `volumeName[1000]`; `substInfo` TRUE also for a refused target (no link text).
- `src/fileswn9.cpp` Copy as UNC: the real buffer size (`2 * MAX_PATH`), a refused target -> 101's
  "too long".
- `src/drivelst.cpp` remote (subst to UNC) menu text: `SAL_SUBST_TEXT_U8_MAX` + `static_assert`
  that the '&'-doubled text fits `DRIVE_MENU_NAME_MAX`.

### Fix attempts during the build

1. saltests: `char small[MAX_PATH]` - `small` is a macro of `rpcndr.h` (C2632) -> renamed `shortBuf`.
   (`sed -i` dropped the CRLF line ends of saltests.cpp and the probe - restored with Python.)
2. saltests: 81 failures - my test was wrong twice: `SalWToU8(.., 1, ..)` counts a terminator (4,
   not 3), and 80 CJK letters after `C:\Temp\` are 248 bytes (fit 260) -> 90 letters (278 bytes),
   a per-letter conversion with `-1`. Then 26559 checks, 0 failed.

## Callers (T009) - every one, and what a refusal does now

| Caller | Buffer | On a refused target |
|---|---|---|
| `salamdr2.cpp` `ResolveSubsts` (+ plug-in `CSalamanderGeneral::ResolveSubsts`, `zip.cpp`) | MAX_PATH | FALSE, the path unchanged (a valid path through the subst) |
| `salamdr2.cpp` `ResolveLocalPathWithReparsePoints` (4 calls), `MyGetDiskFreeSpace`, `MyGetVolumeInformation` (2), `MyGetDriveType` | MAX_PATH | ignore the result: work on the unresolved `Z:\...` path - Windows resolves it; the reparse walk sees the link (probe CJK DEL) |
| `salamdr1.cpp` `HasTheSameRootPathAndVolume` | MAX_PATH | p1 and p2 on the same subst root: both volume names "fail" -> "same" (as for any unresolvable path) |
| `salamdr1.cpp` `PathsAreOnTheSameVolume` (also the plug-in API, used by Undelete) | MAX_PATH | one volume unreadable -> "different" (estimation) - the limit of spec *Assumptions*; the `ResolveSubsts(..) && ResolveSubsts(..)` same-path shortcut is skipped (FALSE) |
| `salamdr7.cpp` `GetResolvedPathMountPointAndGUID` | MAX_PATH | works on the unresolved path |
| `fileswn8.cpp` delete question of a link | MAX_PATH (via ResolveSubsts) | `Z:\J` used as is -> "junction" (probe) |
| `plugins/undelete/fs2.cpp` `ResolveSubsts(resolvedPath)` | MAX_PATH | the path stays unresolved |
| `fileswn9.cpp` Copy as UNC | 2 * MAX_PATH | `*tooLong` -> 101's message |
| `dialogs3.cpp` Drive Information | SAL_SUBST_TEXT_U8_MAX | no subst text, no link text |
| `drivelst.cpp` remote drive text | SAL_SUBST_TEXT_U8_MAX | empty text (as "no subst") |
| `bugreprt.cpp` "Device:" line (`MyQueryDosDevice`) | MAX_PATH | the line omitted |

## Verification

- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Build: `.\build.cmd` -> `BUILD SUCCEEDED` (the `consts.h` change rebuilds everything: the old
  C4018 / C4244 warnings of `salamdr2.cpp:1067`, `zip.cpp:5989` show up - not this feature's lines).
- saltests: `saltests: 26559 checks, 0 failed` (with `TestSubstTarget301`).
- Negative control: the rule's fit test replaced by "accept what was converted" (the old cut) ->
  `saltests: 26559 checks, 4 failed` (the one-byte-short / MAX_PATH refusal checks); restored ->
  0 failed.
- Imports (`dumpbin /imports`): the installed older build `C:\Program Files\Tandem
  Commander\tandemcommander.exe` imports `QueryDosDeviceA` and `QueryDosDeviceW`; the new Debug
  build only `QueryDosDeviceW`.
- Probe after (`probe/result_after.txt`): **9 PASS, 0 FAIL** - CJK DEL "junction", CJK INFO the
  whole CJK path (141 chars, no '?'), LONG INFO now the whole 341-unit target (it is read whole and
  fits the line); registry restored identical; subst left defined 0; fixture removed. (The
  before run used the scratch copy of the same probe with the fixture root `tcsubst` instead of
  `tc301` - the CJK folder 282 vs 280 bytes, both over 259.)

## Inbox item

- `undelete-skips-its-same-partition-warning-when-the-target` - Undelete skips its same-partition warning when the target volume cannot be told (bug, 7, data-safety, measure:301).
