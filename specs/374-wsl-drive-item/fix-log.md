# Fix log - 374-wsl-drive-item

Backlog item `change-drive-menu-and-drive-bar-have-no-wsl-item-for-the`; run started at
`30268b7c` (main), branch `374-wsl-drive-item`.

## Measurement at 30268b7c (before)

- Read `CDrivesList::BuildData` (`src/drivelst.cpp`): Documents, cloud storages (Google Drive,
  Dropbox, OneDrive), Network, plug-in items, hot paths, As Other Panel; no WSL entry.
  `src/` refers to WSL only in 372 (`salbkgndcheck.h`, `fileswn6.cpp`) and 373
  (`saluncserver.h`). Gap present - `BL verify` recorded.
- This computer: `HKCU\Software\Microsoft\Windows\CurrentVersion\Lxss` holds
  `{46fb5931-...}` `docker-desktop` (v2, State 1, Flags 15) and `{78c7c8d9-...}` `Ubuntu`
  (v2, State 1, Flags 15, the DefaultDistribution); `wsl.exe -l --running` -> no running
  distribution. `Get-ChildItem` of the key: 8 ms in PowerShell.
- `%SystemRoot%\System32\wsl.exe` icon index 0 = Tux (extracted to PNG and looked at), so is
  `%ProgramFiles%\WSL\wsl.exe`.
- The probe seam `TC_PROBE_DRIVES_DUMP` (246, 289) dumps `ALL idx= type= text=` for every built
  item; `specs/289-drive-list-wide-texts/probe/run289.ps1` relies on the type numbers 7
  (Documents), 13 (Network), 14 (As Other Panel), 1..14 for its ALL rows -> the new item types are
  appended at the end of `CDriveTypeEnum`.
- Free string slot 14169 (bundle 885 = 14160-14175, beside IDS_ONEDRIVE*); no other define of
  14169 in `src/`.

## Decisions

See spec *Clarifications*: one item per distribution (`Linux - <name>`), OneDrive pattern on the
drive bar, every installed distribution (State 1 or absent), after the cloud storages and before
Network, icon from `System32\wsl.exe` (fallback: the Network icon).
