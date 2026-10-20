# Closing report - 264-remembered-drive-reconnect
Backlog item: remembered-network-drive-with-a-non-code-page-or-long-path - Remembered network drive with a non-code-page or long path cannot be reconnected
Outcome: closed

## What changed

- `src/drivelst.cpp`
  - `GetRememberedNetDriveRemoteW` - the remembered remote path of a letter from the wide
    `WNetOpenEnumW(RESOURCE_REMEMBERED)` enumeration, exact, on the heap (was the ANSI enumeration:
    code page, cut at `MAX_PATH - 1` bytes).
  - `ReadRegStringW`, `GetRememberedNetDriveLogonW` - wide twin of `GetUserName` (saved user name
    and provider of `HKCU\Network\<L>`, used when its `RemotePath` is the same path).
  - The helper thread of `NonBlockingWNetAddConnection3` split into shared parts
    (`NBWNetAC3WaitForPrevious`, `NBWNetAC3StartAndWait`, file-static lock) and a wide twin
    `NonBlockingWNetAddConnection3W` with heap-owned strings released only after the thread ended.
  - `RestoreNetworkDriveW` - the Windows 7+ mapped-letter flow of `RestoreNetworkConnection`, wide.
  - `CDrivesList::ExecuteItem` (drive bar / Change Drive menu) and `CheckAndRestoreNetworkConnection`
    (panel path change; its "listed" branch now gives `SalCheckPath` the UTF-8 path) use them.
- `src/consts.h` - declaration of `RestoreNetworkDriveW`.
- `src/common/salnetdrive.h` - `SalNetDriveSameRemote` (ordinal, case-insensitive, one trailing
  backslash ignored); `src/saltests/saltests.cpp` - `TestNetDriveSameRemote264`.
- Unchanged by design: `RestoreNetworkConnection` (UNC roots, Network plug-in via `zip.cpp`),
  `CheckAndConnectUNCNetworkPath`, `GetNetworkDrives`.

## Measurements (before / after, commands)

- Before (HEAD 7bd36b89): `specs\246-network-drive-labels\test-independent\itest246_pickcp.ps1` on the
  hidden desktop - PK-Q1 / PK-Q2 `reconnected exactly: False`, seam `...unnamed_???_?????`, message
  "The path or file name "Z:\" is invalid.".
- After: the same probe (`probe/result_pickcp246_after.txt`) - `reconnected exactly: True`, panel on
  the drive, no window; baseline unchanged.
- `probe/measure_longpath.ps1 -Scan` (research R1): Windows accepts a remembered remote path of up to
  259 UTF-16 units, refuses 260+ (67); the ANSI enumeration gives `?` where the wide one is exact.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `build.cmd` (Debug x64) -> BUILD SUCCEEDED.
- `saltests.exe` -> `saltests: 24716 checks, 0 failed`.
- `probe/run264.ps1` (hidden desktop, fixed + baseline `%TEMP%\tc264base\tree`), `probe/result_after.txt`:
  RESULT 0 FAIL - fixed Q1 (CJK + Cyrillic), Q2 (Cyrillic, named), L1 (259 characters), A1 (ASCII),
  U1 (missing server: Windows' `(53)`, 4.2 s), N1 (saved provider passed: `(1204)`), P1 (panel path
  change) PASS; baseline Q1 / Q2 / L1 / P1 negative controls fail as expected, A1 reconnects, U1 the
  same `(53)` in 4.2 s; registry restored identical, cleanup verified. Attempt 1 of the probe had two
  probe bugs (recorded in `fix-log.md`; its registry restored by hand, identical).

## Reviews (findings and what was done)

- Review 1 (refute-first agent): no MUST. SHOULD 1 provider probe row -> row N1 added, PASS.
  SHOULD 2 `HANDLES()` wrappers -> added. NOTE 1 the pick no longer reported an enumeration failure
  -> the old `GetNetworkDrives` mask call kept in `ExecuteItem`. NOTE 2-4 accepted (no fallback per
  FR-006; long-path cut needs a DBCS code page - covered by the heap / wide design; the unused
  `name != NULL` branch of `RestoreNetworkConnection` kept for the plug-in path).

## Owed to a person (with the new person-step items)

- `confirm-reconnecting-a-remembered-drive-on-a-password` - on a password-protected share: saved
  credentials, Windows' credential dialog (Cancel / correct password), Esc of the wait window.

## New Inbox items (slug - title)

- `logging-in-to-an-inaccessible-unc-path-with-a-non-ascii` - Logging in to an inaccessible UNC path
  with a non-ASCII share name uses code-page APIs.
- `confirm-reconnecting-a-remembered-drive-on-a-password` - Confirm reconnecting a remembered drive on
  a password-protected share (feature 264) (person step).
