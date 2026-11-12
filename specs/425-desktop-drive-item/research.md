# Research - 425-desktop-drive-item

## R1 How the Desktop path is read

- **Decision**: `SHGetKnownFolderPath(FOLDERID_Desktop, KF_FLAG_DONT_VERIFY, NULL, &p)` (wide, any
  length), converted by `SalDesktopPathToU8` (`saldesktop.h`): the whole path into the caller's
  `SAL_MAX_PATH_UTF8` buffer or refused; then `SalGetFileAttributes` must report a directory.
- **Rationale**: the known-folder API follows redirection (OneDrive, a share); `KF_FLAG_DONT_VERIFY`
  keeps the path of a missing folder so the program can say so instead of failing silently; the
  existence check stops `ChangePathToDisk` from "shortening" a missing path to its parent (a wrong path).
- **Alternatives**: `GetSpecialFolderPathW(CSIDL_DESKTOP)` of `shellib.cpp` (MAX_PATH units only);
  `GetMyDocumentsOrDesktopPath` (Documents first - another folder).

## R2 Icons

- **Decision**: Fluent 2 `OpenDesktop` (exists with its dark variant: the Open Desktop toolbar command,
  416); Classic `imageres.dll` icon 183 (measured: the blue Desktop folder icon File Explorer shows;
  110 is a bare monitor, 105 an error mark).
- **Rationale**: no new SVG needed; `check_iconset.py` already covers `OpenDesktop`.

## R3 Hot keys

- Measured at 472d20a8 (stored "FS Cmd Name" values and the drive dump): `;` Documents, `,` Network,
  `.` As Other Panel, `/` FTP and SFTP, `'` the Folders plug-in. **Decision**: `'` for the core Desktop
  (the key users already press for "Desktop"), `-` for Shell Folders (review 1: the backtick, the first choice, is a dead key on most enabled layouts).

## R4 The plug-in's stored drive-menu text

- The core stores each plug-in's drive-menu text in the registry (`FS Cmd Name`) and replaces it at
  every load of the plug-in (`CPluginData::InitDLL` clears it before `Connect`); a new `plugins.ver`
  (every installer update, and `build.cmd`) loads every plug-in once. An existing configuration shows
  "Shell Folders" after the update. The probe forces it by resetting `Plugins.ver Version (x64)`.

## R5 A real folder inside fld:

- **Decision**: in `CPluginInterfaceForFS::ExecuteOnFS`, sub-folder branch: `GetAttributesOf` on the
  current folder for `SFGAO_FOLDER | SFGAO_FILESYSTEM`; when both are set, `ILCombine` +
  `SHGetPathFromIDListEx(.., GPFIDL_DEFAULT)` into a 32768-unit heap buffer; the path must be an
  existing directory (`GetFileAttributesW`); then `SplWToU8` into a `SAL_MAX_PATH_UTF8` heap buffer
  and `SalamanderGeneral->ChangePanelPathToDisk(panel, path)`. The decision itself is
  `SalShellFolderOpensAsDisk` (`saldesktop.h`).
- **Rationale**: `ChangePanelPathToDisk` is allowed outside `CPluginFSInterfaceAbstract` methods
  (`spl_gen.h`); `ExecuteOnFS` belongs to `CPluginInterfaceForFS` and already changes the panel path.
  After the call the FS may be closed - nothing of `fs` or `file` is used afterwards. A zip archive
  (`SFGAO_FOLDER | SFGAO_FILESYSTEM | SFGAO_STREAM`) and a `.lnk` to a folder have a file path - not a
  directory - and stay in `fld:`; This PC, Control Panel, Recycle Bin, Libraries, Network have no
  `SFGAO_FILESYSTEM` / no path.
- **Measured** (Shell.Application on this machine): the Windows 11 Desktop root lists the user's
  folder, Documents, Music, Downloads, Pictures, Videos, Desktop, OneDrive (fs=True) beside This PC,
  Recycle Bin, Control Panel, Libraries, Gallery, Network, Home (fs=False) and two zip archives
  (folder=True, fs=True, a file path).

## R6 Strings and dialog

- Bundle 885 (14160-14175) holds the other drive-item names; 14163 / 14164 are free: no new bundle (084).
- `IDD_CFGPAGE_CHANGEDRIVE`: accelerators in use S, e, D, C, L, N, O - the new check box is
  "Des&ktop", placed after Documents; the controls below move 13 DLU down, the group box grows 13.
- New control id 6305 (`_APS_NEXT_CONTROL_VALUE`).
