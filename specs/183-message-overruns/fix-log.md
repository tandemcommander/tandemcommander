# Fix log: 183 - message texts with long paths composed on the heap

Backlog: NEXT-WORK item 5j (found by 182's sweep of the core: `sprintf` / `strcat` / `strcpy` of a
name or path into a fixed stack buffer).

## Measured (before)

Probe `probe/overrun_probe.ps1`, the build at 168 (`probe/result_before.txt`):
- UNPACK-LONG: the left panel inside `a.zip`, the right panel in a folder of 1,062 bytes (three
  levels of 170 Czech letters), F5 on `x.txt`: **"Debug Assertion Failed!"** - `UnpackZIPArchive`
  `strcpy`-ed the other panel's path into `char[SAL_FIND_NAME_U8 + 200]` (980 bytes).
- EMAIL-DEEP (Email files on a tree with a folder that cannot be listed, 620+ bytes deep): NOT
  DRIVEN - no MAPI client on this machine, the command stops before it lists anything.
- Read, not driven: ViewFile / EditFile "cannot view / edit" (`char[MAX_PATH + 300]`, a full path -
  reached only when no viewer / editor mask matches: the defaults have `*.*`); thin margins in
  Make file list's error, the force close of a plug-in file system, the reinstall prompt, a DOS
  packer's short-name error.

## Work

The texts on the heap (`CSalHeapString::Printf`; low memory - the name / path alone):
`fileswn5.cpp` (ViewFile, EditFile), `fileswn8.cpp` (Email files), `mainwnd4.cpp` (Make file list;
CloseDetachedFS), `fileswn2.cpp` (force close), `plugins1.cpp` (reinstall), `pack2.cpp` (DOS
packer). `fileswn7.cpp` `UnpackZIPArchive`: the other panel's path is offered only when it fits the
dialog (MAX_PATH); a longer one is not offered (never a cut path).

Build: BUILD SUCCEEDED; `check_encoding.py` TOTAL 0.

## Measured (after)

UNPACK-LONG: the dialog "Copy file "x.txt" from archive to" opens, no assertion, clean exit
(`probe/result_after.txt`: 3 PASS, 1 NOT DRIVEN). Registry identical.

## Review

Independent refute-first review: nothing CRITICAL - formats and arguments unchanged at every site,
the fallbacks safe (`PackErrorHandler` reads as many inserts as its template has), the unpack
dialog's later code takes the target only from the dialog. Taken: `fileswn2.cpp`'s unused
`char buf[2 * MAX_PATH + 100]` removed; `UserWorkedOnThisPath` set only when the path was offered.
Recorded in NEXT-WORK: `fileswn7.cpp` ~528 `lstrcpyn(path, tgtPath, MAX_PATH)` cuts a drop target
(drag & drop unpack - check whether it can exceed MAX_PATH); `pack2.cpp` ~323 cuts a long name in
the external packer's list file; `mainwnd4.cpp` ~139 composes an FS path with `strcpy` / `strcat`
(bounded by the plug-in contract).
