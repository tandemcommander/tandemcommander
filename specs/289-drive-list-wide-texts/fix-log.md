# Fix log - 289-drive-list-wide-texts

Backlog item `drive-list-code-page-texts` - Drive list and folder type names use code-page shell
texts. Autonomous run (`/tandem-backlog-implement`), HEAD0 `cf860604`.

## Measurement before (at cf860604, on `main`)

Machine: ACP 1250 (`HKLM\...\Nls\CodePage\ACP`), Czech display language, not elevated, drives
C: D: E: F: G: all fixed (`Win32_LogicalDisk` DriveType 3) - no removable, no CD.

Sites found at HEAD (searched by name, not line):

| Site | What | Sink |
|---|---|---|
| `icncache.cpp` `ReadDirectoryIconAndTypeAux` | `SHGetFileInfo` (A) `SHGFI_TYPENAME` of the system dir -> `FolderTypeName[80]` | panel *Type* column (`salamdr4.cpp` `InternalGetType` -> `TransferBuffer` -> `fileswn4.cpp`; width `fileswn2.cpp`) - UTF-8 first, code-page fallback |
| `salamdr1.cpp` | `UpDirTypeName = DupStr(LoadStr(IDS_UPDIRTYPENAME))` (code page) | same |
| `drivelst.cpp` `GetDisplayNameFromSystem` | `SHGetFileInfo` (A) `SHGFI_DISPLAYNAME` of a removable root | Change Drive menu (`BuildData`), drive bar tooltip (`GetDriveBarToolTip`) |
| `drivelst.cpp` `ReadCDVolNameThreadFBody` | `GetVolumeInformation` (A) CD label, fallback `GetDisplayNameFromSystem` | menu, tooltip |
| `drivelst.cpp` `BuildData` / `AddToDrives` / `GetDriveBarToolTip` / `ExecuteItem` | `LoadStr` of IDS_FLOPPY350/525/800, IDS_REMOVABLE_DISK, IDS_LOCAL_DISK, IDS_COMPACT_DISK, IDS_MYDOCUMENTS, IDS_GOOGLEDRIVE, IDS_DROPBOX, IDS_ONEDRIVE, IDS_ONEDRIVEPERSONAL, IDS_NETWORKDRIVE; `PrintDiskSize(..., u8 = FALSE)`; mixed with the UTF-8 fixed-drive label (069), network texts (246), OneDrive business names (`SalRegQueryValueExW8`, UTF-8) | menu (`CMenuPopup`, UTF-8 first), tooltip (`tooltip.cpp` `SalU8ToW`, CP_ACP fallback) |

Reachability: Alt+F1 / Alt+F2 (Change Drive menu) -> `CDrivesList::BuildData` for every removable
/ CD / fixed drive; drive bar hover -> `CDriveBar::OnGetToolTip` -> `GetDriveBarToolTip`; every
panel listing with the *Type* column -> `InternalGetType`. Default configuration.

Harness (`%TEMP%\tc_measure_dl\measure.ps1`, PowerShell P/Invoke, input given as a PIDL so only
the output conversion is measured):

```text
ACP = 1250
[name] A bytes: 3F 3F 3F | W as UTF-8: D0 94 D0 BE D0 BC | A decoded equals W: False
[type] A bytes: 53 6C 6F 9E 6B 61 20 73 6F 75 62 6F 72 F9 | W as UTF-8: 53 6C 6F C5 BE 6B 61 20 73 6F 75 62 6F 72 C5 AF | A decoded equals W: True
```

- `SHGetFileInfoA` loses a name outside the code page entirely ("Дом" -> "???"); the wide call is
  exact. Same mechanism for a removable drive's display name; `GetVolumeInformationA` likewise
  (measured by feature 069 for fixed drives).
- The folder type name is stored as cp1250 bytes, not UTF-8; it shows right here only through
  the sinks' code-page fallback.
- All enabled translations of the affected strings (en, cs, de, fr, nl, hu, ro, sk, es) fit cp1250
  (checked from `translations/*/salamand.slt`), so no language choice reproduces the `LoadStr`
  part here either.
- End-to-end (a `????` CD / removable label, a `?` folder type name) needs a CD / removable drive
  labelled outside the code page or a display language outside the code page: **owed to a
  person**. The change is verified here by the bytes stored (valid UTF-8 equal to the wide text)
  and by an unchanged display.

## Decisions
