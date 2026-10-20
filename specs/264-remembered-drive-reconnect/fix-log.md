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

## 2026-10-20 - plan, measurements for it, analyze

- `probe/measure_longpath.ps1 -Scan` (no GUI, cleanup verified): `WNetAddConnection2W` accepts a
  remembered remote path of up to 259 UTF-16 units, refuses 260+ with 67; a 250-character path
  with a Cyrillic tail: wide enumeration exact, ANSI enumeration `...?????`, `WNetAddConnection3W`
  with the exact path reconnects (0). -> research R1; spec US2 / SC-003 reworded to 259.
- Baseline tree for negative controls: `%TEMP%\tc264base\tree` (copy of the HEAD0 Debug build,
  exe SHA-256 A911B648...7B106, equal to the build at 7bd36b89).
- speckit-analyze: 0 CRITICAL, 0 HIGH. Fixed: U1 (listed recovery recorded NOT DRIVEN in T013),
  I1 (US2 test wording). Accepted: U2 - unpaired surrogates / out of memory have no probe row
  (not producible through SMB / not drivable), code review only; A1 - SC-004 timing compared by
  the U1 row's elapsed seconds, fixed vs baseline.

## 2026-10-20 - implementation

- `src/common/salnetdrive.h`: `SalNetDriveSameRemote` (ordinal CI via `CompareStringOrdinal`, one
  trailing backslash ignored, NULL -> FALSE); `src/saltests/saltests.cpp`:
  `TestNetDriveSameRemote264` (25 checks: case incl. Cyrillic / Czech, a code-page `?` is not the
  character, prefix, 600-unit paths differing in the last unit, NULL / empty).
- `src/drivelst.cpp`:
  - `GetRememberedNetDriveRemoteW` - wide `WNetOpenEnumW(RESOURCE_REMEMBERED)` enumeration, heap
    buffer grown on `ERROR_MORE_DATA`, exact `_wcsdup` of the letter's remote path.
  - `ReadRegStringW` + `GetRememberedNetDriveLogonW` - wide twin of `GetUserName`.
  - thread machinery split into `NBWNetAC3WaitForPrevious` / `NBWNetAC3StartAndWait` shared by
    `NonBlockingWNetAddConnection3` (behaviour unchanged) and the new
    `NonBlockingWNetAddConnection3W`; the re-entrance lock is now file-static `NBWNetAC3CS` (was
    a function-local static of the ANSI function - both twins must share it); wide strings are
    heap copies owned by the thread parameters, freed after the thread ended (on normal
    completion, or by the next attempt after its wait - an Esc leaves the thread running).
  - `RestoreNetworkDriveW` (declared in `consts.h`).
  - `CheckAndRestoreNetworkConnection`: `GetNetworkDrives(.., NULL)` for the mask, the exact path
    from `GetRememberedNetDriveRemoteW`; listed -> `SalCheckPath` on `SalWToU8Alloc(remote)`; not
    listed -> `RestoreNetworkDriveW`; no path -> FALSE, `pathInvalid` FALSE.
  - `CDrivesList::ExecuteItem`: exact path, seam `RESTORE <L> <UTF-8 path>`, `RestoreNetworkDriveW`.
- `RestoreNetworkConnection` itself is unchanged (UNC roots, Network plug-in via `zip.cpp`); its
  `name != NULL` branch has no core caller any more (kept: conservative, plug-in path untouched).

### T013 - RestoreNetworkDriveW against the Windows 7+ path of RestoreNetworkConnection (name != NULL)

| Old (name != NULL, Windows7AndLater) | New |
|---|---|
| `GetUserName(name, remoteName, ...)` -> user (non-empty), provider (non-empty) when `IsTheSamePath(RemotePath, remoteName)` | `GetRememberedNetDriveLogonW` - same values, wide, whole; `SalNetDriveSameRemote` (ordinal CI, one trailing `\`) |
| CREDUI branches (`!Windows7AndLater`) | not carried (dead on Windows 11) |
| loop, `connectInteractive = FALSE`: wait cursor, `CreateSafeWaitWindow(IDS_TRYINGRECONNECTESC, 3000, Esc)`, `NonBlockingWNetAddConnection3(.., passwd NULL, user, CONNECT_UPDATE_PROFILE)`, Esc -> FALSE / `ERROR_CANCELLED` | same, `NonBlockingWNetAddConnection3W` |
| interactive: `WNetAddConnection3(parent, ns, NULL, user, CONNECT_INTERACTIVE \| CONNECT_UPDATE_PROFILE)`, cancel -> FALSE, extended error via `WNetGetLastError` | same, `W` |
| `ERROR_SESSION_CREDENTIAL_CONFLICT` -> `IDS_CREDENTIALCONFLICT`, FALSE | same |
| `ERROR_ALREADY_ASSIGNED` -> post `WM_USER_DRIVES_CHANGE`, TRUE | same |
| logon failure: extended + text -> "provider: (code) text"; else not bad user/password -> `GetErrorText`; then interactive once, second time FALSE | same; the extended text is composed wide and shown as UTF-8 |
| other error (not success / already remembered) -> `GetErrorText`, FALSE | same |
| success -> post `WM_USER_DRIVES_CHANGE`, TRUE | same |

NOT DRIVEN (no keyboard, no password-protected share on the hidden desktop; owed to a person):
the credential dialog after refused credentials (Cancel / correct password), the Esc of the wait
window for a slow server, a saved user name other than the current user. Also not producible
here: the "listed but not answering" recovery of `CheckAndRestoreNetworkConnection` (US3
scenario 2) - verified by reading (it now gets the exact UTF-8 path; it got code-page bytes,
wrong for `SalCheckPath` even for Czech characters).

## 2026-10-20 - checks

- `build.cmd` -> BUILD SUCCEEDED (warnings only in untouched files: salamdr2.cpp C4018, zip.cpp C4244).
- `saltests.exe` -> `saltests: 24716 checks, 0 failed`.
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Probe `probe/run264.ps1` (hidden desktop, fixed + baseline `%TEMP%\tc264base\tree`):
  - attempt 1 (`probe/run_after_attempt1.log`): every fixed reconnection worked, but the rows
    judged FAIL - a probe bug: `Seam-For` returned one line, PowerShell unrolled it to a string and
    `$rest[0]` was its first character; and the cleanup threw on the L1 path's MountPoints2 key
    name (> 255 characters) before restoring the registry. Restored by hand from
    `%TEMP%\tc264p\reg_backup.reg` (SHA-256 A46438BF...1EA3 before = after), three MountPoints2
    keys and the fixture removed by hand, mappings / `HKCU\Network` were already clean. Fixed: `@()`
    around the call; the registry restored first in `finally`, every cleanup step guarded,
    > 255-character key names skipped.
  - attempt 2 (`probe/result_after.txt`): **RESULT 0 FAIL**. Fixed: Q1, Q2, L1 (259 characters),
    A1, U1 (`(53)` Windows text, 4.2 s), P1 (panel path change) PASS, seam exact. Baseline:
    Q1 / Q2 / L1 / P1 negative controls fail as expected (`...unnamed_???_?????`, "The path or file
    name "Z:\" is invalid."), A1 reconnects (control), U1 the same `(53)` in 4.2 s. Registry
    restored identical, cleanup verified.
- Step-3 measurement repeated (`itest246_pickcp.ps1`, `probe/result_pickcp246_after.txt`):
  PK-Q1 / PK-Q2 `reconnected exactly: True`, panel on the drive, no window (before: False, the
  "invalid" message); baseline unchanged; registry identical, cleanup verified.
