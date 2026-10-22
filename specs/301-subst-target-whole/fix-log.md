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

## Review

### Review 1 (independent agent, refute-first)

Re-ran build, saltests (26559 / 0), the guard (0), imports (only `QueryDosDeviceW`), the probe
(9 / 0, registry identical); enumerated the callers itself (the table above complete).

- **MUST M1**: the refusal made the volume checks fail open for subst drives whose target passes
  259 UTF-8 bytes - before, the `?` path kept the right drive root, so `PathsAreOnTheSameVolume`
  reached `C:\` and Undelete showed `IDS_SAMEPARTITION`; now `Z:\x` -> no volume -> "different" ->
  no warning. The spec's "no whole-path alternative" was wrong: the whole wide target works with
  `GetVolumePathNameW` + `GetVolumeNameForVolumeMountPointW`.
  **Fixed**: measured first (scratch `volpath2.ps1`: the CJK target path 136 / 148 chars, a 357 /
  361-char path with and without `\?\` -> `C:\` and the C: volume GUID); new
  `GetSubstPathVolume` (`salamdr2.cpp`, `consts.h`): the "\??\X:" target + the rest of the path,
  on the heap, `\?\` when >= MAX_PATH, outputs written only on success; called when the volume
  walk fails in `HasTheSameRootPathAndVolume` (both loops), `PathsAreOnTheSameVolume` (both loops)
  and `GetResolvedPathMountPointAndGUID` (Drive Information's mount point / GUID, `IsPathOnSSD`).
  Spec Q5 re-answered, FR-010 added, Assumptions updated; the Inbox item rewritten to the
  remaining general fail-open, severity 7 -> 5 (no reachable case known).
- **SHOULD S1**: the probe did not cover the volume results. **Fixed**: rows VOL (571 mount point =
  the target's root, 572 = `\?\Volume{...}\`) and MOVE (a second start, F6 of `Z:\a\f.txt` into
  `Z:\J`: the same file id = a rename). First run 15 / 3: the VOL rows read the controls after the
  dialog was closed (probe bug) -> fixed -> 18 / 0.
- **SHOULD S2**: a too-long subst-to-UNC target makes `ResolveSubsts` return FALSE (was TRUE over a
  `?` path). **Documented** (spec edge case): FALSE = not resolved is accurate; the only consumer of
  the value is the same-path shortcut of `PathsAreOnTheSameVolume`, which is then skipped (the
  estimation stays) - the conservative side.
- NOTE heap on hot paths / in the bug report: **fixed** - `QueryDosDeviceWholeW` reads into a
  caller's MAX_PATH stack buffer first and allocates only on ERROR_INSUFFICIENT_BUFFER.
- NOTE orphaned comment in saltests: **fixed** (the 289 comment back above `TestDriveText289`).
- NOTE probe header numbers: **fixed** (the fixture path: about 120 units / 280 bytes).
- NOTE CHANGELOG / FEATURE-HISTORY: at closing.

Measurements of the round:

| Run | Build | Result |
|---|---|---|
| `probe/result_before_installed_0.1.10.txt` | installed 0.1.10 (Release; the subst code as at HEAD) | 14 / 4: CJK DEL, CJK INFO, LONG VOL, LONG MOVE (copy + delete: the file id changed) |
| `probe/result_negctl_no_volume.txt` | Debug, `GetSubstPathVolume` returning FALSE at once | 14 / 4: CJK VOL, CJK MOVE, LONG VOL, LONG MOVE - the M1 regression made visible |
| `probe/result_after.txt` | Debug, the fix | **18 / 0**; registry identical; subst left 0; fixture removed |

saltests after the round: 26559 checks, 0 failed; guard `TOTAL: 0 finding(s)`; build succeeded
(source restored after the negative control, `grep -c "NEGATIVE CONTROL" src/salamdr2.cpp` = 0,
rebuilt).
