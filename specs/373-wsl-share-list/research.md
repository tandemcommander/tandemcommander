# Research - 373-wsl-share-list

All measured on 2026-11-01 at `5b62b037`, Windows 11 26300, computer PC-DOMA, WSL 2 with
Ubuntu and docker-desktop. Network provider order (`HKLM\SYSTEM\CurrentControlSet\Control\NetworkProvider\Order`):
`RDPNP,P9NP,LanmanWorkstation,webclient`; WebClient service stopped. Calls made from a
PowerShell P/Invoke script with the core's parameters (`NetShareEnum` level 1,
`MAX_PREFERRED_LENGTH`; `WNetOpenEnumW(RESOURCE_GLOBALNET, RESOURCETYPE_DISK, 0, &nr)` with
`nr` = `RESOURCE_GLOBALNET` / `RESOURCETYPE_DISK` / `RESOURCEDISPLAYTYPE_SERVER` /
`RESOURCEUSAGE_CONTAINER` / `\\server`).

## R1 - Does asking the providers after error 53 add a second network timeout?

| Server | NetShareEnum | then WNetOpenEnumW | WNetOpenEnumW asked first (cold) |
|---|---|---|---|
| `\\wsl.localhost` | 53, 1-17 ms | 0: docker-desktop, Ubuntu; 1-7 ms | 0, 3 ms |
| `\\wsl$` | 53, 1 ms | 0: the same (remote names `\\wsl.localhost\...`) | - |
| `\\192.168.0.50` (no host) | 53, 21,056 ms | 1203, 2 ms | - |
| `\\192.168.0.51` (no host) | 53 (cached) | 1203, 1 ms | 1203, **21,058 ms** |
| `\\10.255.255.1` | 53 (cached) | 1203, 0 ms | 1203, **21,057 ms** |
| `\\192.168.1.1` (gateway, no SMB) | 53, 11,116 ms | 1203, 6 ms | - |
| `\\nosuchhost-tc-xyz` | 53, 1,282 ms | 1203, 1 ms | - |
| `\\nosuch-tc-cold2` | 53 (cached) | 1203, 0 ms | 1203, **2,693 ms** |
| `\\localhost` | 0, 7 shares, 6 ms | (not asked by the core) | - |

- **Decision**: ask the providers after a 53 with no share, always *after* `NetShareEnum`.
- **Rationale**: once `NetShareEnum` failed, Windows remembers the missing name and the
  providers' question returns 1203 within milliseconds (every missing server tried); asked
  first, the providers' question costs the full timeout itself. So the order matters, and the
  existing order (SMB first) is the right one.
- **Alternatives considered**: (a) ask `WNetGetNetworkInformation` / `WNetGetResourceInformationW`
  for the provider first (the item's fallback idea) - not needed, the measured cost of the plain
  enumeration is milliseconds, and the resource-information call would itself be a cold network
  question; (b) ask the providers only when `NetShareEnum` failed quickly (time threshold) - a
  threshold is a guess that would miss a slow-starting WSL VM and does not buy anything measured;
  (c) a special case for the names `wsl.localhost` / `wsl$` - would leave other non-SMB providers
  (WebDAV, third-party) out and hard-codes a product name.

## R2 - Which first-way errors keep today's route?

- **Decision**: 51 (`ERROR_REM_NOT_LIST`), 1231 (`ERROR_NETWORK_UNREACHABLE`), 1232
  (`ERROR_HOST_UNREACHABLE`) keep "error, no second question"; 53 with no share goes to the
  providers; every other error with no share goes there as today.
- **Rationale**: the item names 53 (measured) and only "possibly" 51; none of the three others
  was observed for a provider-served name; conservative rule (stop-rules §1 step 4).
- **Alternatives considered**: all four to the providers - unmeasured cost for 1231/1232.

## R3 - Which error is shown when the providers give nothing?

- **Decision**: the first way's error (53) - the message of today.
- **Rationale**: the providers answer 1203 ("no network or bad path") for a missing server;
  showing 53 keeps the text the user sees today and the rule 125 already uses for refusals
  (an empty provider answer does not turn a refusal into "no shared folder").

## R4 - Callers and side routes

- `CUncSharesJob::Read` is the only reader; `CUncSharesJob::Start` is called only from
  `CFilesWindow::PickServerShare` (`fileswnb.cpp`), reached from `ChangeDir` for `\\server` /
  `\\server\` (125), from the way up of a share's root (284: `..`, Backspace, Parent directory,
  Go to root, Open in other panel) and again after the sign-in of 285.
- The sign-in step of 285 (`SalUncShareListStep`, `IsLogonFailureErr`) sees `job->Error`; 53
  is not a logon failure, so after the change it still sees 53 when both ways fail.
- The Debug seams (`TC_PROBE_UNC_*`) return before the real calls; unchanged.
- At HEAD a repeated `NetShareEnum` of `\\wsl.localhost` sometimes answers 1707
  (`RPC_S_INVALID_NET_ADDR`), which already goes to the providers - that is why probe row W2
  passed before the fix.
