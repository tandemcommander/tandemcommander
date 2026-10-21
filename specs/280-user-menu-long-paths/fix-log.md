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
