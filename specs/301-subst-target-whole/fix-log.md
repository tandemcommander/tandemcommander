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
