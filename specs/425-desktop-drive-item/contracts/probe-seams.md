# Probe seams - 425-desktop-drive-item (Debug builds only)

## Core: `TC_PROBE_DESKTOP_FILE=<file>`

`GetDesktopPathU8` (`shellib.cpp`) takes the Desktop folder from the UTF-8 text of `<file>` (BOM and
line ends removed) instead of `SHGetKnownFolderPath(FOLDERID_Desktop)`. An empty file = the shell
reports no Desktop path. A file, not the variable itself: the environment is copied through the code
page at start (feature 386's trap). Release builds have no seam.

## Core: `TC_PROBE_DRIVES_DUMP` (features 246 / 289 / 374, unchanged)

The new item appears as `ALL idx=<n> type=21 text='<TAB>Desktop` and `TIP ' Desktop` on the bar.

## Folders plug-in: `TC_PROBE_FLD_DUMP=<file>`

Appends one UTF-8 line per event to `<file>`:

- `LIST count=<items> dirs=<folders> root=<0|1>` - after each listing of `ListCurrentPath`;
- `EXEC dir=<0|1|2> name=<UTF-8 name> attrs=<SFGAO hex> path=<UTF-8 path or -> action=<disk|fld|up|file|skipped>`
  - at each `ExecuteOnFS`.

While the seam is on, `ExecuteOnFS` acts **only** on the item whose name equals the UTF-8 text of
`<file>.pick` (read at each call; the up-dir item's name is `..`); every other item is recorded with
`action=skipped`, and a file item is **never** run (`action=file` is recorded, nothing is invoked).
So a probe walking the focus down the list never opens or runs anything but its target. Release
builds have no seam.
