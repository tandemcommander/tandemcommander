---
title: Server path of WSL (wsl.localhost) offers no share list: error 53 skips the provider fallback
type: bug
status: in-progress
severity: 4
area: panels-ui
source: manual
who: agent
created: 2026-11-01
updated: 2026-11-01
verified: 2026-11-01 5b62b037
effort: S
feature: 373
related: [real-file-server-person-rows, decide-ship-network-plugin-nethood]
depends-on: []
reason: -
---

# Server path of WSL (wsl.localhost) offers no share list: error 53 skips the provider fallback

## Problem

Typing `\\wsl.localhost` (or `\\wsl.localhost\`) in Change Directory shows an error instead of the list of WSL distributions that Explorer shows. The core's share list of feature 125 (`CUncSharesJob`) asks `NetShareEnum` first. WSL is not an SMB server, so that call always fails with error 53 (`ERROR_BAD_NETPATH`). Error 53 is classed as "server not found", so the second way, `WNetOpenEnumW`, is never tried. The Plan 9 network provider would answer it with the distributions. The same probably holds for every non-SMB network provider that serves `\\name` roots (WebDAV redirector, third-party providers); only WSL was measured.

## Evidence

- `src/shares.cpp` at 777b3552, `CUncSharesJob` worker (the `notFound` test after the `NetShareEnum` loop, about L580): `ERROR_BAD_NETPATH`, `ERROR_REM_NOT_LIST`, `ERROR_NETWORK_UNREACHABLE` and `ERROR_HOST_UNREACHABLE` set `Error` and skip the `WNetOpenEnumW` branch. The comment there gives the reason: a server that was not found is not asked a second time (another network timeout).
- Measured on 2026-11-01 (PowerShell P/Invoke of the same calls, level 1 and `RESOURCE_GLOBALNET` / `RESOURCETYPE_DISK` / `RESOURCEUSAGE_CONTAINER` as the core uses them), Windows 11 26300, WSL with Ubuntu and docker-desktop:
  - `\\wsl.localhost`: `NetShareEnum` = 53; `WNetOpenEnumW` = 0 → `\\wsl.localhost\docker-desktop`, `\\wsl.localhost\Ubuntu` (provider *Plan 9 Network Provider*), then 259 (`ERROR_NO_MORE_ITEMS`).
  - An address with no server (`\\192.168.0.50`, no answer on 445): `NetShareEnum` = 53; `WNetOpenEnumW` = 1203 (`ERROR_NO_NET_OR_BAD_PATH`). The error shown there is correct.
  - `\\PC-DOMA` / `\\127.0.0.1` (the local Server service): `NetShareEnum` = 0 with the hidden admin shares. The ordinary SMB route works.
- Not measured in the program itself: the exact message box text for `\\wsl.localhost` (by the code it is the 53 error of `PSS_ERRORSHOWN`).

## Expected

`\\wsl.localhost` and `\\wsl.localhost\` in Change Directory offer the distributions in the share menu of 125. Picking one opens `\\wsl.localhost\<distro>`. A server that really does not exist still shows one error, without a noticeably longer wait than today.

## Approach

At error 53 (and possibly `ERROR_REM_NOT_LIST`), try `WNetOpenEnumW` as well. Measure first how long it takes for a name that does not exist, and whether the MUP / provider order answers fast enough. If it adds a second network timeout, ask `WNetGetResourceInformationW` / the provider name first (`WNetGetNetworkInformation`), or try the provider enumeration only when `NetShareEnum` failed quickly. Keep the decision in `src/common/saluncserver.h` with saltests checks. Also check the way up from a share's root of 284 (`\\wsl.localhost\Ubuntu` with Backspace), which goes through the same job. `\\wsl$` is the older alias of the same provider: check it too.

## Notes

Severity 4: a function does not work, and a workaround exists (type `\\wsl.localhost\Ubuntu` in full). Reported by the maintainer together with "a NAS should list its shares". The NAS case is an SMB server and goes the `NetShareEnum` route, which works against the local Server service (measured) and the probes of 125/285 (`\\localhost` with seams); a real NAS was never measured. Its check with a real server is the person step `real-file-server-person-rows`. Enabling the Network plug-in (`decide-ship-network-plugin-nethood`) would not fix this by itself: the plug-in would need the same provider route.

## Log

- 2026-11-01 — created (source manual)
- 2026-11-01 — moved to Next position 34
- 2026-11-01 — moved to Next position 2
- 2026-11-01 — Notes: the NAS route is measured only against the local server, not a real NAS
- 2026-11-01 — verified at 5b62b037: probe at 5b62b037: `\\wsl.localhost`, `\\wsl$` and Backspace at `\\wsl.localhost\Ubuntu` show error (53); NetShareEnum 53, WNetOpenEnumW lists the distros
- 2026-11-01 — run started, feature 373
