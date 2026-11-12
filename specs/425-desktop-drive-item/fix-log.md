# Fix log - 425-desktop-drive-item

Backlog item `ikona-na-desktop-vede-kamsi-neznamo-kam` (GitHub #31): the drive menu's "Desktop" opens the
Folders plug-in's virtual `fld:` view instead of the Desktop folder.

## Measurement before (main 472d20a8)

- Build: `.\build.cmd` (Debug x64) at 472d20a8 -> BUILD SUCCEEDED.
- Probe `probe/desktop_probe.ps1` (hidden desktop, `TC_PROBE_DRIVES_DUMP`) -> `probe/result_before.txt`:
  PASS 2 / FAIL 8 / NOT DRIVEN 3. The Alt+F1 list: no core Desktop item (Documents idx 6, nothing of a new
  type after it), no drive-bar Desktop button; the plug-in items `'/' FTP Client | ''' Desktop | ...` - the
  Folders plug-in's `'\tDesktop`; OPT-OFF / REGRESS pass trivially; the fld: rows NOT DRIVEN (no plug-in seam).
- By reading: `CPluginInterfaceForFS::ExecuteOnFS` (`src/plugins/folders/fs1.cpp`) enters every folder with
  `AddItemToIL` + `ChangePanelPathToPluginFS(.., "?")`; `GetCurrentPath` gives an empty user part - the path
  line is `fld:` at every depth.
- Measured with Shell.Application (this Windows 11, Czech UI): the fld: root lists the user's folder,
  Documents, Music, Downloads, Pictures, Videos, Desktop, OneDrive (file-system folders), This PC, Recycle
  Bin, Control Panel (twice: the category folder and a non-folder item), Libraries, Gallery, Network, Home
  (virtual) and two zip archives (shell folders whose path is a file). This PC lists only the drives.
- Stored plug-in drive-menu texts (`FS Cmd Name`): `;` Documents (core), `,` Network, `.` As Other Panel,
  `/` FTP and SFTP, `'` Folders -> the core Desktop takes `'`, Shell Folders takes `` ` ``.

## Decisions

- Classic icon: imageres.dll 183 (rendered: the Explorer Desktop folder icon; 110 = a monitor). Fluent 2:
  the existing `OpenDesktop` (light + dark).
- analyze U1 (MEDIUM): an unreadable (access denied) Desktop is left to `ChangePathToDisk`; see below.

## Implementation

(in progress)
