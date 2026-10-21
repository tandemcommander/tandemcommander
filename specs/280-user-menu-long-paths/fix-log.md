# Fix log - 280-user-menu-long-paths

Backlog item `user-menu-long-paths`. HEAD at the start: d7405c6a.

## Measurement before (d7405c6a)

- `build.cmd` (Debug x64 incremental) at d7405c6a: BUILD SUCCEEDED.
- Probe (PowerShell, hidden desktop):
  `powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\um280_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile <scratch>\rows_before.txt"`
  (the probe was written in the session's scratch folder before the branch existed; copied to
  `probe/um280_probe.ps1`, result `probe/result_before.txt`).
- Result: **15 PASS / 5 FAIL**; registry restored, identical hash; fixture removed.
  - FPRCUT FAIL: `$(FullPathRight)` gave `...\tc280\pc\ppp...\` - the PARENT of the 260-byte
    right panel folder (lstrcpyn cut at 259 bytes ended after a backslash, SalPathAddBackslash
    succeeded). A command acted on a cut path.
  - FPRLONG FAIL: 313-byte right folder - "FullPathRight ... is not defined in this context".
  - MIXDIRECT FAIL: a.txt + 274-byte name selected, item without a shell: ran for a.txt, then
    "too long name".
  - LISTFULL FAIL: "List of selected names with path is too long" for a.txt + 274-byte name.
  - CMPLONG FAIL: the compare dialog opened with empty names.
  - PASS: CONTROL, LDIRFOCUS (225), LDIRSEL, LNAME, MIXBAT - already refused / run correctly.

## Sites at HEAD (by reading)

- `src/mainwnd4.cpp` `GetNextFileFromPanel`: lstrcpyn path/name into MAX_PATH (focus and
  selection branches); 225's refusal for a 260+ byte path without selection.
- `src/finddlg1.cpp` `GetNextItemFromFind`: lstrcpyn path/name into MAX_PATH.
- `src/mainwnd4.cpp` `CMainWindow::UserMenu`: `char path[MAX_PATH], name[MAX_PATH]`;
  `strcpy(firstItemDir/lastCdDir/prevItemDir, path)`; direct route runs ShellExecuteEx per item
  inside the loop.
- `src/mainwnd4.cpp` `ExpandCommand2`: refuses `path` >= MAX_PATH and path + name > 259.
- `src/mainwnd3.cpp` User Menu command: `FullPathLeft/Right` (lstrcpyn + SalPathAddBackslash),
  `ListOfSelFullNames` (lstrcpyn + SalPathAppend MAX_PATH), `CompareName1/2` (lstrcpyn +
  SalPathAppend, emptied).
- `src/finddlg1.cpp` `OnUserMenu`: `CompareName1/2` likewise; FullPath* empty (not defined).
- Callers of `UM_GetNextFileName` / `CMainWindow::UserMenu`: only `mainwnd3.cpp` (panel) and
  `finddlg1.cpp` (Find) - the type is internal to the core (not in `src/plugins/shared`).

## Analyze

- Run 1: HIGH I1 - FR-003 (the route without a shell starts nothing after any refusal while
  preparing) contradicted FR-007 (short values exactly as before) for a refusal of another kind
  (Cancel at a missing environment variable on a later item: before, the earlier items ran).
  Fixed: FR-007 names the intended exception, an edge case and Clarification Q2 say "any
  refusal". LOW L1 (MVP text vs phase order) fixed in tasks.md.
- Run 2: no CRITICAL / HIGH / MEDIUM / LOW findings; coverage 100 % (7 FR, 3 SC, 21 tasks).

## Decisions per route (spec Clarifications)

| Route / value | Choice | How |
|---|---|---|
| panel focus / selection, Find results (item folder + name) | refuse ("too long name") from whole values | `UM_GetNextFileName` returns `UMNEXT_ITEM / END / TOOLONG`, buffers `UM_ITEM_TEXT_SIZE` (heap); `UserMenu` refuses a folder or name of `MAX_PATH`+ bytes before the item's command is prepared; `ExpandCommand2` still refuses folder + name over 259 |
| route without a shell | prepare all, then start | `CUserMenuPreparedRun` list; started after the loop only without an error (any refusal - also Cancel at a missing environment variable - leaves all unrun, as the batch file) |
| `$(FullPathLeft/Right/Inactive)` | refuse | `SalUMPathWithBackslash`; `*TooLong` flags -> "too long name" instead of "not defined" |
| names to compare | refuse | `SalUMJoinWhole`; `CompareName*TooLong` -> "too long name" before the "files or folders" question and the dialog; cleared names asked as before |
| panel's `$(ListOfSelectedFullNames)` | work | `CSalPathBuf` Set + AppendComponent (as Find since 004) |

## Implementation

- `src/common/salumvalue.h` (new): `SalUMCopyWhole`, `SalUMPathWithBackslash`, `SalUMJoinWhole`.
- `src/saltests/saltests.cpp`: `TestUserMenuValue280` - includes the negative control
  `lstrcpynA(old, <260-byte folder whose 259 bytes end with '\'>, MAX_PATH)` == its parent (the
  old copy), refused by the new rule.
- `src/mainwnd.h`: the contract (`UM_ITEM_TEXT_SIZE`, `UMNEXT_*`, int result).
- `src/execute.h`: five `*TooLong` flags in `CUserMenuAdvancedData` (default FALSE).
- `src/mainwnd4.cpp`: `GetNextFileFromPanel` whole; `CMainWindow::UserMenu` heap item buffers,
  the up-front refusal, `CUserMenuPreparedRun` + the start loop after the enumeration, full-path
  and compare refusals.
- `src/mainwnd3.cpp`: full paths, full-name list, compare names.
- `src/finddlg1.cpp`: `GetNextItemFromFind` whole; compare names; full-path flags FALSE.
- Trap: a Python rewrite of `mainwnd4.cpp` turned its CRLF into LF (and `sed -i` did the same
  to `execute.h`); restored to CRLF before the commit.

## Checks after

- `.\build.cmd` (Debug x64): BUILD SUCCEEDED, exit 0.
- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- Probe `um280_probe.ps1` (24 rows - two controls added after the measurement: SHORTTWO, two
  short items without a shell both run; FPRSHORT, a short right panel gives its folder):
  **24 PASS / 0 FAIL**, registry restored identical (`probe/result_after.txt`). Before (20
  rows): 15 / 5.
- Regression probes on the new build: 226 `PASS 28, FAIL 0`; 229 `PASS 34, FAIL 0`; 234 `PASS 5,
  FAIL 0, NOT DRIVEN 3` (the same as its own record: the Find route's popup menu).
- `saltests.exe`: first two runs hung - a run-time check "Stack around the variable 'buf' was
  corrupted" in `TestUserMenuValue280` (the test passed size 300 for a 260-byte buffer - a defect
  of the test, not of the rule). The dialog appeared on the visible desktop (saltests is a
  console program, run outside the hidden desktop); the second run ended with exit 3 (the dialog
  answered Abort). Fixed the test (a 400-byte buffer); rebuilt: `saltests: 24986 checks, 0
  failed`, exit 0, 12 s. The negative control inside the test: `lstrcpynA` of the 260-byte
  folder gives its parent - the old copy - and the new rule refuses that folder.

## Review

### Review 1 (independent agent, refute-first)

No MUST. Re-measured: saltests 24986 / 0; probe 24 / 0; negative control (old `lstrcpyn` +
`SalPathAddBackslash` for FullPathRight and the start loop without `&& !error`, rebuilt): MIXDIRECT,
FPRCUT, FPRLONG FAIL again, FPRSHORT PASS - the rows detect the defects; tree restored.
- SHOULD 1 - a command of the route without a shell that failed to start now cleared the panel's
  selection (the enumeration's end, which clears it, now comes before the starts; before, a launch
  error stopped the enumeration and the selection stayed - FR-007 / Q6). Reproduced by the
  reviewer. **Fixed**: `GetNextFileFromPanel` only records `EndReached`; `UserMenu` returns FALSE
  when a prepared command failed to start; the panel's caller clears the selection when the
  enumeration ended and every command started. Probe row LAUNCHFAIL.
- SHOULD 2 - the compare command was refused because of a second name only GUESSED (the same name
  looked up in the other panel) whose folder is 260+ bytes; before, that was no match and the
  dialog asked. Reproduced by the reviewer. **Fixed**: a guessed name that does not fit is no
  match (empty, no "too long" flag); names the user chose (selection, focus) are still refused.
  Probe row CMPGUESS.
- NOTE - `$(ListOfSelectedFullNames)` "works" only when the first item fits (a group command
  still uses item 0's folder + name for `$(FullName)`-like variables and the expansion): existed
  before; recorded as a limit.
- NOTE - low memory for the item buffers returned silently: **fixed** (an error box, then return).
- NOTE - indentation at `GetNextFileFromPanel` (`return UMNEXT_TOOLONG;`): **fixed**.
- NOTE - `salumvalue.h` comment overstated "SalPathAppend's rules" for an empty name: **fixed**.
- NOTE - `probe/result_before.txt` comes from the first version of the probe (a missing output
  printed as `''`; the committed probe prints `missing`, and has more rows); the reviewer's
  negative control above stands for the gap.
- NOTE - not driven: `$(FullPathLeft)`, `$(FullPathInactive)` (by reading: the flag follows the
  inactive panel), the cleared-names path and the "files or folders" question, Cancel at a missing
  environment variable, the Find window's route (by reading).

After the fixes: `.\build.cmd` BUILD SUCCEEDED; saltests `24986 checks, 0 failed`; encoding guard
TOTAL 0; probe **28 PASS / 0 FAIL** (rows CMPGUESS and LAUNCHFAIL added), registry restored
identical (`probe/result_after.txt`). (The program's registry key hash differs from the earlier
runs - the key changed between runs outside this probe; each run restored its own backup
identically.)

### Review 2 (independent agent, refute-first, "Previous findings" given)

No MUST; both fixes of review 1 hold. Re-measured: saltests 24986 / 0; probe at HEAD 28 / 0;
**before re-measured with the committed probe** (main's `mainwnd.h`, `execute.h`, `mainwnd3.cpp`,
`mainwnd4.cpp`, `finddlg1.cpp`): **23 / 5** - exactly FPRCUT, FPRLONG, MIXDIRECT, LISTFULL,
CMPLONG fail (this replaces review 1's NOTE on the earlier probe version); negative control with
review 1's bugs put back: CMPGUESS and LAUNCHFAIL FAIL; regression probes 226 / 229 / 234 as
recorded. Every path where the selection used to be cleared compared with main by reading: the
same (batch route incl. a batch file that cannot be written or started; refusals, 225's early
refusal, group commands, low memory, a failed start without a shell keep it).
- SHOULD - no probe row checked that the selection IS cleared after a successful run (a build
  that never cleared it passed 28 / 0). **Fixed**: row CLEARSEL (s2, a.txt + b.txt selected,
  PERNAME twice: the second run only the focused b.txt). Negative control: `if (FALSE &&
  data.EndReached && started)` in `src/mainwnd3.cpp`, rebuilt, `-Only CLEARSEL`: **FAIL** (the
  second run ran a.txt too); reverted with `git checkout`, rebuilt.
- NOTE - `contracts/um-enumeration.md` and `research.md` still said the enumeration's end clears
  the selection: **fixed**. SC-001 mixed rows and cases: **fixed** (15 cases, 30 rows).
- NOTE - a focused second compare name (one item selected, the cursor on another) counts as
  chosen: refused when it does not fit (before: the dialog asked). Kept - the spec's rule (a name
  the user chose is refused); recorded.
- NOTE - a command using only one compare name: not reachable - `ValidateUserMenuArguments`
  refuses a compare command that does not use both names (`IDS_COMPARENEEDSBOTHARGS`,
  `src/execute.cpp`).
- NOTE - not driven: the Find route, `$(FullPathLeft)` / `$(FullPathInactive)`, the cleared-names
  path, the "files or folders" question (correct by reading).

Final: `.\build.cmd` BUILD SUCCEEDED (from the committed sources after the negative control);
probe **30 PASS / 0 FAIL** (`probe/result_after.txt`), registry restored identical.
