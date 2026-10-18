# 246 — Data model

## Mapped network drive (runtime, per build of the drive list)

| Field | Source | Notes |
|---|---|---|
| letter | `GetLogicalDrives()` bit or remembered enumeration | A–Z |
| listed | `GetLogicalDrives()` bit | FALSE for a remembered connection Windows did not restore |
| remembered | `WNetOpenEnum(RESOURCE_REMEMBERED)` (`GetNetworkDrives`) | code-page remote name kept for reconnection |
| remote path | `WNetGetConnectionW("X:")` | UTF-16 → UTF-8; also for a remembered, unavailable drive |
| status | `WNetGetConnectionW` result, `WNetGetConnection3W` disconnected state | see state rules |
| name | `MountPoints2\<key>\_LabelFromReg` | optional; cleaned (contract `salnetdrive.md`) |

### State rules

```
disconnected = !listed
            || WNetGetConnectionW == ERROR_CONNECTION_UNAVAIL (1201)
            || (WNetGetConnectionW == NO_ERROR && WNetGetConnection3W == NO_ERROR
                && state == WNGC_DISCONNECTED (1))
Accessible  = !disconnected            (CDriveData, drvtRemote only)
icon        = disconnected ? imageres 31 : imageres 33   (GetDriveIcon, unchanged)
```

## CDrivesList additions

| Member | Meaning |
|---|---|
| `CachedNetDisconnectedMask` | bit per letter of a remote drive judged disconnected at the last `BuildData` (all letters, regardless of hidden-drive settings) |
| `GetCachedNetDisconnectedMask()` | accessor, used by the drive bars' change detection |

`BuildData(..., copyCachedDrivesMask, ..., copyCachedNetDisconnectedMask)` — the copy path
(second drive bar) takes over the mask with the copied items.

`CDriveData` is unchanged (no new pointer field — reconnection reads Windows, not the item).

## Explorer's drive-name key (read-only)

`HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\##<server>#<share>[#<path>…]`
value `_LabelFromReg` (REG_SZ). Written by Explorer (rename) or Group Policy Preferences.
Never written by Tandem Commander.
