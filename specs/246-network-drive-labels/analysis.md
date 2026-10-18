# 246 — Analysis (baseline of the 0.1.10 tree, commit 1a8d00b5)

Read-only analysis by three independent agents (text path, accessibility/refresh, live
Windows measurement) plus the session's own reading. File:line references are to the tree
at the start of the feature.

## A. Where a mapped drive's text comes from and where it is shown

- **Built** in `CDrivesList::BuildData`, `src/drivelst.cpp:1816-1837`: `DriveText = "X\t" +
  remote name` (`:1884-1892`), or `"X"` alone when the remote name is empty (`:1896-1903`,
  a 2-byte buffer). Remote drives have no third column (free space is measured for fixed
  and RAM disks only).
  - Remembered (persistent) connection — the usual case: the remote name is
    `netRemotePath[]` from `GetNetworkDrives` (`:20-86`), which enumerates
    `WNetOpenEnum(RESOURCE_REMEMBERED)` with the **code-page (A)** API (the core is built
    without `UNICODE`).
  - Connected, not remembered: `GetMappedDriveNameU8` (`:1333`, feature 069, wide → UTF-8).
  - Otherwise `GetSubstInformation`.
  - `DuplicateAmpersands` (`:1835`) doubles `&` (the menu draws column 2 with prefix
    processing) and **cuts** a text that does not fit (`src/salamdr3.cpp:1771-1776`).
- **Shown**:
  - Change Drive menu (Alt+F1/F2): `LoadMenuFromData` (`:2322`) → columns split at `\t`
    (`src/menu1.cpp:288-319`), drawn UTF-8 first, code page as fallback
    (`src/menu3.cpp:966-1012`).
  - Drive bar tooltip: `GetDriveBarToolTip` (`:2724-2731`) copies `DriveText + 2` and runs
    `RemoveAmpersands`; the tooltip sink is UTF-8 first (`src/tooltip.cpp:309-313`).
  - Second drive bar: the copy branch (`:1669-1712`) duplicates `DriveText` and `Accessible`.
  - Not affected (show only the letter or their own data): the drive bar button text
    (letter, `:2605`), Disconnect dialog (`src/dialogs6.cpp:949-1047`, own enumeration),
    Drive Information (`src/dialogs3.cpp:1673-1731`, own `WNetGetConnectionW`), Find
    dialog drives, context menu, panel path line.
- No current code reads a network drive's Windows name. Explorer's name is not the volume
  label (see C).

## B. Consumers that depend on `DriveText` column 2 being the UNC path

| Consumer | Today | If column 2 showed a label |
|---|---|---|
| `ExecuteItem` `:2451-2459` (a disconnected drive picked in the menu or bar) | `strcpy(remoteName, DriveText + 2)` → `RestoreNetworkConnection(hwnd, "X:", remoteName)` | `WNetAddConnection3` would get "Archiv" → reconnection fails; `GetUserName` would not match `HKCU\Network\X\RemotePath` |
| `GetDriveBarToolTip` `:2726` | shows the UNC path | the path would no longer be visible |

Defects already present in that consumer (found by both static agents independently):

1. **Doubled `&`**: the reconnection gets the doubled text (`\\srv\R&D` → `\\srv\R&&D`);
   nothing undoes `DuplicateAmpersands` before `RestoreNetworkConnection`.
2. **Read past the buffer**: for the text `"X"` (2 bytes) `DriveText + 2` points past the
   allocation (a disconnected drive without a remote name — rare).
3. **The path can be cut**: `DuplicateAmpersands` truncates to `MAX_PATH` (rule 097/098).

`RestoreNetworkConnection` (`:440-817`) needs the exact remote name in **code page**
(ANSI `NETRESOURCE`, `WNetAddConnection3`); `GetUserName` (`:88-135`) matches it against
`HKCU\Network\<letter>\RemotePath`. The other caller, `CheckAndRestoreNetworkConnection`
(`:819-856`), takes it fresh from `GetNetworkDrives`.

## C. Accessibility and the icon

- `drv.Accessible = (mask & i) != 0` (`:1753`): a remote drive is "accessible" whenever its
  letter is in `GetLogicalDrives()`. The connection state is never consulted. Icon 31
  (disconnected, imageres.dll) appears only for a remembered drive whose letter is absent
  from `GetLogicalDrives()`; otherwise 33 (`src/salamdr1.cpp:1053`).
- Readers of `Accessible` for drives: the icon (`:1705`, `:1905`); `ExecuteItem` "try to
  revive" (`:2451`); the drive context menu (`:3008`, `:3135`, posts a rebuild after a shell
  command on an inaccessible drive). Making `Accessible` FALSE for a letter that still
  exists: `RestoreNetworkConnection` gets `ERROR_ALREADY_ASSIGNED`, treats it as "we were
  wrong", rebuilds the drive list and returns TRUE (`:690-697`); the panel then reconnects
  through `CheckAndRestoreNetworkConnection`. Harmless.
- Gray icons: drives keep `HGrayIcon == NULL` (same icon in both image lists).

## D. Refresh

- The Change Drive menu always rebuilds when opened (`Track`, `:2500`).
- Drive bars are rebuilt on `WM_USER_DRIVES_CHANGE` (`mainwnd3.cpp:1912-1928`) or by
  `RebuildDriveBarsIfNeeded` (`:1312-1347`), which compares only
  `GetLogicalDrives() | remembered` with the cached mask; it runs on menu open/close and
  Ctrl+R. Shell notifications registered (`:1186-1189`): media, drive add/remove, net
  share; `SHCNE_SERVERDISCONNECT` is handled in the switch (`:1750`) but **not registered**.
  No timer; activation re-checks only OneDrive.
- So a server going offline (mask unchanged) never rebuilds the bars, and even a rebuild
  would show icon 33.

## E. Cost on the UI thread (per remote drive, full build)

`GetDriveType` twice, `WNetGetConnectionW` (+ A fallback on failure), `QueryDosDevice`;
the icon is a resource load. Deliberately skipped for remote drives: volume label, free
space, share search ("we will not bother network drives"). Feature 069 notes the build's
timeout sensitivity — no extra round trip per drive.

## F. `CDriveData` (`src/drivelst.h:78-95`)

Shallow `TDirectArray` copies; `DriveText` freed only in `DestroyDrives` (`:2269-2292`).
`BuildData` reuses one local `drv` for every add (copy path, drives, plug-in FS,
`AddToDrives`, other panel, hot paths) and `CPlugins::AddItemsToChangeDrvMenu`
(`src/plugins2.cpp:1140-1173`) fills its own uninitialised local — a new pointer field
must be reset at every add site or it is freed twice.

## G. Measurement of Windows behaviour (Windows 11 26300, 2026-10-18)

Tools and full logs: `probe/measure/` (`measure.cpp`, `snap.ps1`, `measure.log`,
`snap.log`, `idle_monitor.log`). Targets: `\\localhost\C$\<scratch>\share` and an
unreachable TEST-NET server `\\192.0.2.1\x`; free letters T:–W:; everything created was
removed and the cleanup verified (MountPoints2 `##*` list equal to the baseline,
`HKCU\Network` empty as before, `net use` empty).

### G1. Explorer's name of a mapped drive

| Query | not renamed | after an Explorer rename to "Archiv Test ž" |
|---|---|---|
| `SHGetFileInfoW(SHGFI_DISPLAYNAME)` | `share (\\localhost\C$\…\246-measure) (W:)` (3 ms) | `Archiv Test ž (W:)` (3 ms) |
| `SIGDN_PARENTRELATIVEEDITING` | the same without ` (W:)` | `Archiv Test ž` |
| `GetVolumeInformationW` label | `''` | `''` |
| `WNetGetConnectionW` | `\\localhost\C$\…\share` (as typed, no trailing `\`) | unchanged |

- Default format: `<last component> (<rest of the UNC path>) (X:)`; a share root gives
  `C$ (\\localhost) (T:)`. The **server volume label is not used** (`\\localhost\E$` has
  label `DATA`, Explorer shows `E$ (\\localhost)`).
- A rename (`IShellFolder::SetNameOf`, the same as F2 in Explorer) writes REG_SZ
  `_LabelFromReg` under `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\
  MountPoints2\##localhost#C$#Users#…#246-measure#share`. The key exists from the first
  mapping with `_LabelFromDesktopINI = ""` (empty in every case tried, also with a
  `desktop.ini` `LocalizedResourceName`). Group Policy Preferences drive maps write the same
  value (research).
- Key name: `\` → `#`; a literal `#` stays `#`; non-ASCII characters as-is (UTF-16).
  Keyed by remote path, not by letter; lookup case-insensitive (registry key names are);
  the label survives unmap/remap to another letter and shows for a remembered,
  disconnected drive.

### G2. Connection states

| | Connected | Remembered, not connected (localhost or unreachable) | Mapped folder deleted on the server | Connected, idle 16+ min |
|---|---|---|---|---|
| `GetLogicalDrives` bit | 1 | **0** | 1 | 1 |
| `GetDriveTypeW` | 4 | 1 | 4 | 4 |
| `WNetGetConnectionW` | 0 | **1201** (remote name still returned, 3 ms) | 0 | 0 |
| `WNetGetConnection3W` (disconnected level) | 0, state 0 | 2 | 0, state 0 | 0, state 0 |
| `net use` status | OK | Unavailable | OK | OK |
| shell icon (`SHGFI_SYSICONINDEX`) | 9 (`imageres,-33`) | **10** (`imageres,-31`, red X) | 9 | 9 |
| shell type name | "Síťová jednotka" | "Síťová jednotka je odpojena." | "Síťová jednotka" | "Síťová jednotka" |

- Shell display-name calls never blocked (0.3–24 ms in every state). Calls that **block**:
  `WNetGetResourceInformationW` for the unreachable server (21 s), WMI
  `Win32_NetworkConnection` (21 s).
- Not producible on this machine without logon/service changes: a letter present in
  `GetLogicalDrives` with Explorer's red X, and the `net use` status "Disconnected".
  `CONNECT_DEFERRED` is refused (87); a direct mapping to an unreachable server fails
  (67) and creates nothing; 16 minutes idle stayed OK.

### G3. Consequences (session's reading of A–G2)

1. **Name**: Explorer's name is `_LabelFromReg` when the user (or a policy) named the
   drive; otherwise it is only a reformatting of the UNC path. The value can be read from
   the registry without touching the network.
2. **Icon in the Change Drive menu**: in every red-X state measured, the letter is absent
   from `GetLogicalDrives` → `Accessible = FALSE` → icon 31. The menu is rebuilt at every
   opening, so the menu itself is right for those states.
3. **Icon in the drive bar — a reproducible root cause**: the bars are rebuilt only when
   `GetLogicalDrives() | remembered` changes (`CachedDrivesMask`, `drivelst.cpp:1721`,
   `mainwnd3.cpp:1321`). A persistent drive going from connected to unavailable (or back)
   clears or sets only its `GetLogicalDrives` bit, while its "remembered" bit keeps the
   OR-ed mask unchanged. Unless Windows sends a shell drive notification, the bar keeps the
   old icon — even across Alt+F1 and Ctrl+R, which call `RebuildDriveBarsIfNeeded`.
   (To be confirmed on the build — negative control in the probe.)
4. **Letter present, connection broken** (the user's report may be this): not
   reproducible here; Windows offers `WNetGetConnectionW == ERROR_CONNECTION_UNAVAIL` and
   `WNetGetConnection3W(WNGC_INFOLEVEL_DISCONNECTED) == WNGC_DISCONNECTED` as local,
   non-blocking indicators; today's code consults neither.
