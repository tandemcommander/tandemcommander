# Contract: probe seam `TC_PROBE_DRIVES_DUMP` (feature 246, Debug builds only)

Compiled only under `_DEBUG` (`ProbeDrivesDump`, `src/drivelst.cpp`); a Release build has
no trace of it. Precedent: feature 125 (`TC_PROBE_UNC_*`).

When the environment variable `TC_PROBE_DRIVES_DUMP` names a file, the drive list appends
one UTF-8 line (CRLF) per event:

| Line | When | Fields |
|---|---|---|
| `BUILD bar=<0/1> copy=<0/1> drives=<hex> netdisc=<hex>` | end of the drive part of `CDrivesList::BuildData` (menu: `bar=0`; drive bar: `bar=1`; second bar copying the first: `copy=1`) | `CachedDrivesMask`, `CachedNetDisconnectedMask` |
| `ITEM <letter> idx=<n> type=<CDriveTypeEnum> acc=<0/1> text=<DriveText>` | after each `BUILD`, one per non-separator item built so far (drives) | `idx` = index in the drive list (drive bar command = `CM_DRIVEBAR_MIN + idx`); `text` is `DriveText` verbatim (letter, TAB, column text with `&` doubled) |
| `TIP <letter> <text>` | `GetDriveBarToolTip` for a network drive | the tooltip text as answered |
| `CHECK quiet=<0/1> drives=<hex> netdisc=<hex>` | `RebuildDriveBarsIfNeeded` with bars shown | the masks compared (`quiet=1` = window activation) |
| `REBUILD bar1` / `REBUILD bar2` | a bar is rebuilt by that check | |
| `RESTORE <letter> <remote>` / `NORESTORE <letter> listed|not-remembered` | `ExecuteItem` on a disconnected drive | the remote name handed to `RestoreNetworkConnection` |

The seam reads the variable on every call (no caching) and never changes behaviour.
