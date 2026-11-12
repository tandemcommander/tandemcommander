# Data model - 425-desktop-drive-item

## Drive type `drvtDesktop`

- `CDriveTypeEnum` value 21, appended after `drvtWSLMenu` (the probe dumps of 246 / 289 / 374 rely on
  the numbers before it).
- Built only when `Configuration.ChangeDriveShowDesktop` is TRUE, right after `drvtMyDocuments`;
  text `"'\t" + IDS_DESKTOPDRIVE`; icon `SAL_ICONSET_NAME_DESKTOP` / imageres 183.
- On the drive bar: an icon-only button, tooltip IDS_DESKTOPDRIVE; no context menu (as Documents).
- Execute: `CFilesWindow::ChangePathToDesktop` (menu and bar).

## Configuration value

| Name | Type | Default | Read | Written |
|---|---|---|---|---|
| `Change Drive Show Desktop` | REG_DWORD 0/1 | 1 (absent = 1) | `LoadConfig` (`GetValue` keeps the default) | `SaveConfig` |

Not part of the Altap / Open Salamander settings import (rule 245 FR-016).

## Pure rules (`src/common/saldesktop.h`)

| Function | In | Out |
|---|---|---|
| `SalDesktopPathToU8(desktopW, path, size)` | the shell's wide path (NULL / "" = none) | `SAL_DESKTOP_NONE` / `_OK` (whole path) / `_TOO_LONG` (path emptied) |
| `SalDesktopFolderUsable(attrs)` | `GetFileAttributes` result | true only for an existing directory |
| `SalShellFolderOpensAsDisk(isFolder, isFileSystem, havePath, attrs)` | shell attributes, path got, the path's attributes | true = open as a disk path; false = stay in `fld:` |

## Folders plug-in drive-menu entry

`IDS_DRIVEMENUTEXT` = `"-\tShell Folders"` (hot key `-`).
