---
title: Remembered network drive with a non-code-page or long path cannot be reconnected
type: bug
status: open
severity: 4
area: encoding
source: probe:246
who: agent
created: 2026-10-18
updated: 2026-10-19
verified: -
effort: M
feature: -
related: [drive-list-code-page-texts]
depends-on: []
reason: -
---

# Remembered network drive with a non-code-page or long path cannot be reconnected

## Problem

A remembered (persistent) network drive that Windows did not reconnect is picked in the
Change Drive menu or the drive bar: Tandem Commander reconnects it with the remembered path
in the **code page** (and cut at 259 bytes). A path with characters outside the system code
page (e.g. Cyrillic or Chinese on a Czech system) or a longer path is handed to Windows
wrong, the drive stays disconnected and the user sees a misleading message
`The path or file name "Z:\" is invalid.` Since feature 246 the menu shows such a path
exactly, which invites the pick that then fails. 0.1.10 behaves the same (not a regression).

## Evidence

At 82b32159:
- `GetNetworkDrivesBody` (`src/drivelst.cpp`) enumerates `WNetOpenEnum(RESOURCE_REMEMBERED)`
  with the ANSI API (the core is built without `UNICODE`) and copies `lpRemoteName` cut to
  `MAX_PATH - 1`.
- `CDrivesList::ExecuteItem` (246) takes that path and calls `RestoreNetworkConnection`,
  which fills an ANSI `NETRESOURCE` and calls `WNetAddConnection3` /
  `NonBlockingWNetAddConnection3`; `GetUserName` matches it against
  `HKCU\Network\<letter>\RemotePath` with the code-page `SalRegQueryValueEx`.
- `CheckAndRestoreNetworkConnection` (the panel's reconnect) uses the same chain.
- Independent test of 246: `specs/246-network-drive-labels/test-independent/results_pickcp.txt`
  rows PK-Q1 / PK-Q2 — seam line `RESTORE Z \\localhost\C$\...\unnamed_???_?????`, the
  message above; the baseline build fails identically.
- 246 review round 1, finding 3 (`specs/246-network-drive-labels/fix-log.md`).

## Expected

Picking a remembered, disconnected network drive reconnects it to its exact path whatever
characters the path holds and however long it is; the password dialog and the saved user
name keep working.

## Approach

- `WNetRestoreSingleConnectionW(hwnd, L"X:", TRUE)` restores a remembered connection by its
  letter from the user's profile (no remote name needed; Windows shows its own credential
  dialog). Measured during 246: 6 ms for a reachable target, error 53 at once for an
  unreachable server. Check whether it blocks like `WNetAddConnection3` for a slow server
  (the existing non-blocking wait window with Esc must not be lost).
- Or a wide `RestoreNetworkConnection` (wide enumeration, `WNetAddConnection3W`,
  `NETRESOURCEW`, wide `GetUserName`), keeping the password dialog.

## Notes

Severity 4: a function does not work in a narrow case (non-code-page or long remembered
paths), workaround: reconnect in Explorer or with `net use`. Found by the independent test
of feature 246 (probe), recorded by the implementing agent.

## Log

- 2026-10-18 — created (source probe:246)
- 2026-10-19 — moved to Next position 22
