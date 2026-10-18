# Contract: what the drive list shows for a mapped network drive (feature 246)

## Change Drive menu (Alt+F1 / Alt+F2) — item of a remote drive `X:`

| Column | Content |
|---|---|
| 1 | `X` (unchanged) |
| 2 | named: `Name (\\server\share\path)`; unnamed: `\\server\share\path` (as before); no remote path obtainable: as before (remembered path / SUBST target / empty) |
| 3 | empty (as before — free space is shown for local drives only) |

`&` appears literally (stored doubled, drawn with prefix processing). UTF-8 text.

## Drive bar

- Button text: the letter (unchanged).
- Tooltip: the same text as column 2, with `&` single, read at the moment the tooltip
  appears (name and path current).
- Icon: imageres 31 (disconnected) when `SalNetDriveIsDisconnected`, else 33.

## Rebuild of the drive bars

A bar is rebuilt when any of these differs from what it was built with:
`GetLogicalDrives() | remembered` (as before), the cloud storages (as before), **the
disconnected network drives mask** (new). Checked on Change Drive menu open/close, on
refresh (Ctrl+R and the panel refresh commands), and on main window activation (new). The
activation check shows no message box.

## Reconnection (picking a disconnected drive)

- Letter listed by Windows → no reconnect call; the panel changes to the drive and the
  existing reconnect on access applies.
- Letter not listed → reconnect with the remembered remote path from Windows; the
  displayed text is never parsed.

## Unchanged

Local / removable / CD / RAM drives, cloud storages, Network, plug-in items, hot paths,
other panel; Disconnect dialog; Drive Information dialog; panel path line.
