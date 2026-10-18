# Implementation Plan: Network drive names and disconnected-drive icons

**Branch**: `246-network-drive-labels` | **Date**: 2026-10-18 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/246-network-drive-labels/spec.md`

## Summary

A mapped network drive is shown in the Change Drive menu and the drive bar tooltip by its
UNC path only, and the drive bar keeps a stale icon when a remembered drive switches
between connected and unavailable. The fix (all in the core, `src/drivelst.cpp` plus the
bar's refresh in `src/mainwnd3.cpp` / `src/toolbar6.cpp`):

1. Read the drive's Windows name the way Explorer stores it — `_LabelFromReg` under
   `HKCU\…\Explorer\MountPoints2\##server#share#path` — with wide registry calls, no
   network access; show `Name (\\server\share\path)`; unnamed drives unchanged.
2. Take the remote path from `WNetGetConnectionW` (also returned for a remembered,
   unavailable connection — measured) so the shown text is Unicode-exact.
3. A remote drive is disconnected when its letter is missing (today) **or**
   `WNetGetConnectionW` returns `ERROR_CONNECTION_UNAVAIL` **or**
   `WNetGetConnection3W(WNGC_INFOLEVEL_DISCONNECTED)` reports `WNGC_DISCONNECTED`.
4. Cache a "disconnected network drives" mask next to `CachedDrivesMask`; the drive bars
   are rebuilt when it changes; check it also on main window activation (quiet: no message
   box).
5. Reconnection takes the remote name from Windows (`GetNetworkDrives`), never from the
   displayed text — fixes the doubled `&`, the read past a 2-byte text and the cut path.

Pure rules go to a new header-only `src/common/salnetdrive.h` with `saltests` checks.

## Technical Context

**Language/Version**: C++20 (`/std:c++latest`), MSVC v143 (VS2022)
**Primary Dependencies**: WinAPI only — `mpr.lib` (WNet, already linked), advapi32 (registry)
**Storage**: reads `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2`
(Explorer's per-user drive names; read-only, never written)
**Testing**: `saltests` (pure rules); GUI probe on the hidden desktop with temporary
mappings to `\\localhost\C$\…` (`probe/`); independent test and review agents
**Target Platform**: Windows 11 x64
**Project Type**: desktop application (core executable)
**Performance Goals**: menu build + ≤ 50 ms with four network drives (SC-004); the
activation check costs one local status query per network drive
**Constraints**: no network round trip on the UI thread (no `GetVolumeInformation`,
`WNetGetResourceInformation`, WMI on a remote drive — measured to block 21 s); names and
paths UTF-8 (WTF-8), never cut; no new UI strings; no plug-in API change
**Scale/Scope**: up to 26 drive letters; ~250 lines in the core, one new header

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Assessment |
|---|---|
| I. Build reproducibility | No new dependency; `mpr.lib` already linked (WNet calls exist). Pass |
| II. Backward compatibility | Unnamed drives and all other drive kinds unchanged (SC-002 byte-identical); named drives gain their name while keeping the path; the icon now matches Windows. A defect fix with no information removed — justification recorded in spec *Clarifications* (no option). Registry: reads an Explorer key, writes nothing; no configuration change. Pass |
| III. Incremental modernization | Touches only the remote-drive branch of `BuildData`, the tooltip, `ExecuteItem`'s reconnect, the bars' change detection; new code wide/UTF-8, English comments. Pass |
| IV. Windows commitment | Pure WinAPI. Pass |
| V. Plugin architecture | No plug-in interface change (`LAST_VERSION_OF_SALAMANDER` stays 108). Pass |
| VI. UI consistency | No new dialog or control; menu/tooltip texts only. Pass |
| CLAUDE.md text rules | Wide producers (`WNetGetConnectionW`, `RegQueryValueExW`), `SalWToU8`; text built on the heap, never cut; `check_encoding.py` must stay `TOTAL: 0`. Pass |
| CLAUDE.md public claims | `PRIVACY.md`: no network communication added (WNet status queries are local; no new URL), nothing stored, installer unchanged → no update needed (verify wording in T-docs). Pass |

## Project Structure

### Documentation (this feature)

```text
specs/246-network-drive-labels/
├── spec.md, analysis.md, fix-log.md
├── plan.md              # this file
├── research.md          # Phase 0
├── data-model.md        # Phase 1
├── contracts/
│   ├── salnetdrive.md   # the pure rules (header contract)
│   └── drive-ui-text.md # what the menu / tooltip / icon show
├── quickstart.md        # validation guide
├── probe/               # measurement tools, GUI probe, results
└── tasks.md             # /speckit-tasks
```

### Source Code (repository root)

```text
src/common/salnetdrive.h      # NEW: pure rules (key name, name cleaning, text, state)
src/drivelst.cpp              # remote-drive text, state, tooltip, reconnect, quiet enum, mask
src/drivelst.h                # CachedNetDisconnectedMask + accessor, BuildData copy param
src/salamand.h                # GetNetworkDrives(..., showErrors), GetNetDisconnectedMask()
src/mainwnd.h / mainwnd3.cpp  # RebuildDriveBarsIfNeeded compares the new mask; activation check
src/toolbar.h / toolbar6.cpp  # the bar passes / copies the new mask
src/saltests/saltests.cpp     # TestNetDrive246
```

**Structure Decision**: core-only change, existing files plus one header under
`src/common/` (the project's place for pure, tested rules).

## Complexity Tracking

No constitution violations.
