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
