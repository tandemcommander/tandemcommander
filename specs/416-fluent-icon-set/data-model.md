# Data model - 416

## Icon set (`SAL_ICONSET_*`, `src/common/saliconset.h`)

| Id | Name | Standard folder | Dark folder | Shell icons | Drive / `..` / chevron |
|---|---|---|---|---|---|
| 0 | Fluent 2 (default) | `iconsets\fluent` | `iconsets\fluent\dark` | only as fallback | own SVGs (`Drive*`, `OpenDocuments`, `OpenNetwork`, `UpDir`, `IDV_ARROW_DOWN_FLUENT`) |
| 1 | Classic | `toolbars` | `toolbars\dark` | yes (today) | imageres / `updir.ico` / `IDV_ARROW_DOWN` |

## Setting

- `Configuration.ToolbarIconSet` (int). Registry: `HKCU\<SALAMANDER_ROOT_REG>\<SALAMANDER_CONFIG_REG>` value
  `Toolbar Icon Set`, REG_DWORD. Read rule `SalIconSetFromStored(read, value)`: read && value == 1 -> Classic, else
  Fluent 2 (missing, wrong type, unknown number).

## Fluent name of a toolbar button (`SalIconSetFluentButtonName(tbbe, classicName)`)

- Classic name unless overridden: 73 (Zoom Panel) -> none; 74 (Shared Directories) -> `SharedDirectories`;
  36 / 51 (Change Drive L/R) -> `ChangeDrive`; 43 `OpenActiveFolder`, 44 `OpenDesktop`, 45 `OpenComputer`,
  46 `OpenControlPanel`, 47 `OpenPrinters`, 48 `OpenNetwork`, 49 `OpenRecycleBin`, 50 `OpenFonts`, 97 `OpenDocuments`.

## Fluent drive icon (`SalIconSetFluentDriveName(type, accessible, isSystem)`)

- REMOVABLE `DriveRemovable`; REMOTE `DriveNetwork` / `DriveNetworkDisconnected`; CDROM `DriveCD`; RAMDISK `DriveRam`;
  FIXED on the Windows drive `DriveSystem`; anything else `DriveFixed`.

## Override choice (`SalIconSetChooseSource(darkActive, darkUsable, stdUsable)`)

- dark active and dark usable -> dark verbatim; else standard usable -> standard (adapted in Dark); else none (cell
  left as it was). Usable = parsed and has at least one shape.

## Preview

- TBBE ids: 14 Back, 11 Parent Directory, 2 Create Directory, 3 Find, 4 Views, 16 Refresh, 21 Copy, 23 Delete,
  37 Select, 41 Pack.
