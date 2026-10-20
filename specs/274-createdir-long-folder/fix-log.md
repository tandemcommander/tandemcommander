# Fix log - 274-createdir-long-folder

Backlog item `create-directory-refuses-a-relative-name-in-a-folder-whose`.

## Measured before (main at 449f35fc, Debug x64 build of HEAD)

New probe `probe/createdir274_probe.ps1` (model: `specs/259-long-name-refusals/probe/editnew259_probe.ps1`),
F7 = `CM_CREATEDIR` (730) posted to the main window, run on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\createdir274_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib E:\Projects\tandemcommander\specs\098-long-path-overruns\probe\fix_probe_lib.ps1"
```

(Run from a scratch copy before the branch existed; the copy in `probe/` finds the library by its
relative path. Result copied to `probe/result_before.txt`.)

| Row | Case | Before |
|---|---|---|
| SHORT | "nd" in a 45-byte folder | PASS - created |
| REL | "nd" in a 288-byte folder | FAIL - "The path specified is too long." |
| CJK | 100 CJK letters (300 bytes) in the 288-byte folder | FAIL - the same |
| U255 | 255 CJK letters (765 bytes) in a 44-byte folder | FAIL - the same (a valid name) |
| U256 | 256 CJK letters in a 44-byte folder | FAIL - "path too long" instead of "too long name" |
| LIMIT | a 98,244-byte relative path in the 288-byte folder | PASS - "The path specified is too long." |

8 PASS / 4 FAIL (with the END rows); registry restored and identical; fixture removed.

Finding beyond the item's words: the defect is any joined path of 260+ bytes (U255 in a short
folder), not only folders of 260+ bytes.

## Callers of SalGetFullName with the default nameBufSize (fix protocol: enumerated)

`grep -n "SalGetFullName(" src/*.cpp` - callers that take a typed name and the default limit:
Pack and Unpack (fileswn7.cpp), Make File List (mainwnd4.cpp), File List dialog OK and Browse
(dialogs.cpp). Their buffers are `char[MAX_PATH]`: the default limit equals the buffer - not
this defect (research.md R3). Only `CreateDir` paired a `SAL_MAX_PATH_UTF8` buffer with the
`MAX_PATH` join limit. Not changed.

## Decisions

- `nameBufSize = SAL_MAX_PATH_UTF8` in CreateDir's `SalGetFullName` call (as 259 for Edit New File).
- The new folder's own name over 255 UTF-16 units -> `IDS_TOOLONGNAME`, checked before anything
  is created (rule of 259; no new string).

## speckit-analyze

One run: 0 CRITICAL, 0 HIGH. Two LOW accepted: C1 - no probe row for a typed absolute path (the
absolute branch of the join is not touched by the change); F1 - quickstart row count wording.

## Change

`src/fileswn5.cpp` `CFilesWindow::CreateDir` (disk branch): `SalGetFullName(..., nextFocus, NULL,
SAL_MAX_PATH_UTF8)`; after a successful join the last component is judged with
`SalNameTooLongForFileSystemU8` - over 255 UTF-16 units -> `IDS_TOOLONGNAME` in the existing
pre-creation message box (`IDS_ERRORCREATINGDIR`), `goto CREATE_AGAIN`, before `CheckPath` and
`CheckAndCreateDirectory` (nothing is created, no missing parent either). No new string.

## Checks

- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Build: `.\build.cmd` -> `BUILD SUCCEEDED`, exit 0.
- saltests: `saltests: 24859 checks, 0 failed` (no new rule; `SalNameTooLongForFileSystemU8` has
  checks since 259).
- Probe after (`probe/result_after.txt`):

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log specs\274-createdir-long-folder\probe\result_after.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\274-createdir-long-folder\probe\createdir274_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label after"
  ```

  12 PASS / 0 FAIL: REL, CJK (300-byte name in the 288-byte folder) and U255 (765 bytes) created
  under exactly the typed name; U256 refused "Cannot finish operation because of too long name.";
  LIMIT refused "The path specified is too long."; registry restored and identical; fixture
  removed. Before: 8 / 4.
- Negative control (`probe/result_negative_control.txt`): the name check disabled
  (`FALSE &&`), rebuilt, rows U255 + U256: U256 FAIL - Windows answers "(123) The filename,
  directory name, or volume label syntax is incorrect." (Czech system text on this machine), so the
  check is what gives the true reason; reverted and rebuilt (`BUILD SUCCEEDED`).

## Traps met

- `$PSScriptRoot` is empty inside a `param()` default in Windows PowerShell 5.1 - the probe's
  library default moved into the body (the first after-run stopped at the Join-Path).
- A Bash here-document collapsed `\\` while repairing that line and put a NUL byte and a form
  feed into the probe (the trap of feature 123); repaired with a script file written by the
  editor; the probe is checked pure ASCII (0 bytes outside printable ASCII / tab / CR / LF).

## Limits left

- A created folder whose name is 260+ bytes (CJK row) is not focused after the refresh (the
  focus slot holds 259 bytes) - the same limit as Edit New File (259).
- An intermediate component over 255 units in a multi-component typed name keeps the system's
  answer; a full path between 32,767 UTF-16 units and `SAL_MAX_PATH_UTF8` bytes keeps the
  system's answer from the creation step (as a typed absolute path already did).
- Pack, Unpack and Make File List stay limited to 259 bytes by their own buffers (not this defect).
