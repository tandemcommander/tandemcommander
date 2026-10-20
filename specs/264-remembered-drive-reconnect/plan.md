# Implementation Plan: Remembered network drive reconnects to its exact path

**Branch**: `264-remembered-drive-reconnect` | **Date**: 2026-10-20 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/264-remembered-drive-reconnect/spec.md`

## Summary

Reconnecting a disconnected remembered network drive (drive menu / drive bar pick, panel
path change) took the remembered remote path from the ANSI enumeration - code page, cut at
259 bytes - and handed it to the ANSI `WNetAddConnection3`. The fix takes the exact path
from the wide enumeration on the heap and reconnects through a wide twin of the same
reconnection flow (same background attempt with the Esc wait window, same interactive
credential dialog, same saved user name / provider, same messages). The "listed" recovery
of the panel gets the exact path in UTF-8. One pure rule (`SalNetDriveSameRemote`) goes to
`src/common/salnetdrive.h` with saltests checks. Research: [research.md](research.md).

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143
**Primary Dependencies**: Win32 `mpr.dll` (WNet*), advapi32 registry - already linked
**Storage**: reads `HKCU\Network\<letter>` (Windows' own key, read-only here); nothing new stored
**Testing**: `saltests` (pure rule), hidden-desktop probe `probe/run264.ps1`
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core `tandemcommander.exe`)
**Performance Goals**: no extra network round trip; one extra local enumeration per pick (as before)
**Constraints**: never cut a path; no code-page conversion of the path; UI not blocked during the first attempt
**Scale/Scope**: `src/drivelst.cpp`, `src/consts.h`, `src/common/salnetdrive.h`, `src/saltests/saltests.cpp`

## Constitution Check

| Principle | Check |
|---|---|
| I Build reproducibility | no new dependency, no new project, no new string |
| II Backward compatibility | ASCII / code-page paths behave as before (probe row A1 in both builds); registry untouched; plug-in ABI untouched (`RestoreNetworkConnection` kept for the Network plug-in) |
| III Incremental modernization | one call chain made wide; old ANSI code kept for its other callers |
| IV Windows commitment | Win32 only; XP/Vista credential branches not carried into the new path (Windows 11 target) |
| V Plug-in architecture | no `spl_*.h` change |
| VI UI consistency | same wait window, same messages, no new UI string |

Gate: PASS (also after design).

## Design

1. **salnetdrive.h** - `SalNetDriveSameRemote(const WCHAR* a, const WCHAR* b)`: TRUE when the
   two remote paths are the same by the file system's rule (ordinal, case-insensitive,
   `CompareStringOrdinal`), ignoring one trailing backslash on either side; FALSE for NULL.
   saltests: equal, case, trailing backslash, Cyrillic case (`А`/`а`), different lengths,
   prefix-only, NULL / empty.
2. **drivelst.cpp**
   - `GetRememberedNetDriveRemoteW(char letter)` - wide enumeration of remembered disk
     connections (`WNetOpenEnumW` / `WNetEnumResourceW`, heap buffer grown on
     `ERROR_MORE_DATA`); a malloc'd copy of the letter's remote path or NULL.
   - `GetRememberedNetDriveLogonW(letter, remote, &user, &provider)` - wide twin of
     `GetUserName`: `HKCU\Network\<letter>` values `RemotePath` / `UserName` /
     `ProviderName` read whole (REG_SZ), used when `SalNetDriveSameRemote`.
   - `NonBlockingWNetAddConnection3W(err, NETRESOURCEW*, user, flags, errCode, errBuf,
     errProvider)` - wide twin sharing the thread object, the re-entrance lock and the wait
     loop with the ANSI one; its strings are copied to the heap owned by the thread
     parameters and released only after the thread has ended (also after an Esc).
   - `RestoreNetworkDriveW(HWND parent, char drive, const WCHAR* remote)` - the Windows 7+
     flow of `RestoreNetworkConnection` for a mapped letter, wide.
   - `CDrivesList::ExecuteItem` - remote path from `GetRememberedNetDriveRemoteW`; seam
     `RESTORE <L> <exact UTF-8 path>`; `RestoreNetworkDriveW`.
   - `CheckAndRestoreNetworkConnection` - mask from `GetNetworkDrives(.., NULL)`, path from
     `GetRememberedNetDriveRemoteW`; listed -> `SalCheckPath` on the UTF-8 form
     (`SalWToU8Alloc`); not listed -> `RestoreNetworkDriveW`; no path -> not restored
     (FALSE, `pathInvalid` FALSE - the caller's normal error handling).
3. **consts.h** - declaration of `RestoreNetworkDriveW` next to `RestoreNetworkConnection`.

Contract of the internal functions and the seam: [contracts/reconnect.md](contracts/reconnect.md).
Data: [data-model.md](data-model.md). Validation: [quickstart.md](quickstart.md).

## Project Structure

### Documentation (this feature)

```text
specs/264-remembered-drive-reconnect/
├── spec.md, plan.md, research.md, data-model.md, quickstart.md
├── contracts/reconnect.md
├── probe/  (measure_longpath.ps1, run264.ps1, results)
├── fix-log.md, closing-report.md
└── tasks.md
```

### Source Code

```text
src/drivelst.cpp              reconnection chain (wide)
src/consts.h                  declaration
src/common/salnetdrive.h      SalNetDriveSameRemote (pure rule)
src/saltests/saltests.cpp     saltests checks of salnetdrive.h
```

**Structure Decision**: core only; no plug-in, no resource, no string.

## Complexity Tracking

None.
