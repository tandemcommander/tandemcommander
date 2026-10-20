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
