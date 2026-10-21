# Fix log - 285-share-list-sign-in

Backlog item `share-list-offers-sign-in`: a server's share list that needs a password shows only
the Windows error. Autonomous run (`/tandem-backlog-implement`), HEAD0 `eb173f7f`.

## Measurement before (at eb173f7f, on main)

- Read: `CFilesWindow::ChangeDir` (fileswn3.cpp, `IDS_SHARENAMEMISSING` without a Network plug-in)
  -> `PickServerShare` (fileswnb.cpp) -> `CUncSharesJob::Read` (shares.cpp). A refused list
  (`Count == 0`, `Error` e.g. 5) -> `IDS_PATHERRORFORMAT` box, `PSS_ERRORSHOWN`; no sign-in.
  Since 284 Backspace / Go to root / `..` in a share's root take the same route.
- The full share path's sign-in: `CheckAndConnectUNCNetworkPath` -> `RestoreNetworkConnection(parent,
  NULL, root)` -> on Windows 7+ the ANSI `WNetAddConnection3(..., CONNECT_INTERACTIVE)` (research R1).
- `WNetAddConnection3W` without a dialog (PowerShell P/Invoke, current credentials): `\\localhost`,
  `\\localhost\IPC$`, `\\PC-DOMA`, `\\PC-DOMA\IPC$`, type ANY or DISK -> 5; `\\nosuchserver-tc` ->
  64; `WNetCancelConnection2W` afterwards -> 2250 (nothing was left connected).
- Built Debug at HEAD (`.\build.cmd`, exit 0). New probe `probe/signin_probe.ps1` (hidden desktop,
  seams of 125 + the planned sign-in seam, which HEAD does not have):

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\signin_probe.ps1 -Repo E:\Projects\tandemcommander -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe"
  ```

  `probe/result_before.txt`: A1, A2, C1, F1, W1, K1 - one box "Path: \\localhost\ Error: (5)
  Access denied", no list, sign-ins 0; N1 - box (53); R1 - list, `\\localhost\D$`. 8 END PASS,
  registry restored and identical. Defect confirmed (`BL verify`).

## Decisions

- Sign-in = Windows' dialog via `WNetAddConnection3W(CONNECT_INTERACTIVE)` to `\\server\IPC$`
  (RESOURCETYPE_ANY), wide; messages as `RestoreNetworkConnection` for an unmapped path; once per
  opening; no `CONNECT_UPDATE_PROFILE` (spec Clarifications, research R1-R3).
- `PRIVACY.md` not changed: every claim stays true (research R4); naming the sign-in there is left
  to the maintainer.
- The run was interrupted after the plan (the after_plan auto-commit returned exit 4 once; re-run,
  it committed `a4f1422b`). No probe was running; no registry backup was left.

## Implementation
