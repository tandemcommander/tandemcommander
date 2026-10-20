# Fix log - 264-remembered-drive-reconnect

Backlog item `remembered-network-drive-with-a-non-code-page-or-long-path`.

## 2026-10-20 - measured before (HEAD 7bd36b89, on main)

- `build.cmd` (Debug x64, up to date) -> BUILD SUCCEEDED.
- Hidden desktop: `tools\run_on_hidden_desktop.ps1` running
  `specs\246-network-drive-labels\test-independent\itest246_pickcp.ps1 -Fixed <HEAD exe> -Baseline <HEAD exe>`.
  Fixture: `Z:` -> `\\localhost\C$\Users\pavel\AppData\Local\Temp\tc246test\fx\unnamed_<CJK>_<Cyrillic>`,
  `Y:` -> `...\named_<Cyrillic>` (name "Named CP"); both remembered and disconnected
  (`WNetGetConnectionW` 1201, letter not in `GetLogicalDrives`).
  Result: `PK-Q1 reconnected exactly: False; seam 'RESTORE Z \\localhost\C$\...\unnamed_???_?????';
  listed after False; [#32770 'Error'] The path or file name "Z:\" is invalid.`; `PK-Q2` the same
  (`...\named_?????`). Registry restored identical (SHA-256 equal), cleanup verified.
- Long paths: by reading - `GetNetworkDrivesBody` cuts `lpRemoteName` to `MAX_PATH - 1` bytes;
  `NonBlockingWNetAddConnection3` copies it again with `lstrcpyn(..., MAX_PATH)`.

## Sites and consumers (enumerated with Grep)

- `RestoreNetworkConnection(parent, name, remoteName, ...)` callers:
  - `CDrivesList::ExecuteItem` (drive menu / drive bar pick, `name` = "X:") - in scope.
  - `CheckAndRestoreNetworkConnection` (panel path change; `salamdr5.cpp` x2) - in scope; its
    "letter listed" branch also passes the code-page `netPath` to `SalCheckPath`, which takes
    UTF-8 - in scope (same remembered path).
  - `CheckAndConnectUNCNetworkPath` (`name` NULL, UNC root) - out of scope.
  - `zip.cpp` `CSalamanderGeneral` (`lpNetResource`, Network plug-in) - out of scope.
- `GetNetworkDrives(..., netRemotePath)` users: the two above, `ExecuteItem`, `BuildData`
  (fallback text only when `WNetGetConnectionW` gives nothing - drive texts, related item
  `drive-list-code-page-texts`), `mainwnd3.cpp` (mask only), `bugreprt.cpp` (mask only).
- `NonBlockingWNetAddConnection3`: `RestoreNetworkConnection` and `CheckAndConnectUNCNetworkPath`.
