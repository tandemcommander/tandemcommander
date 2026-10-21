# Data model - 289-drive-list-wide-texts

No stored data. In-memory texts, all UTF-8 after the change:

| Text | Holder | Max bytes | Source after | Fallback |
|---|---|---|---|---|
| Folder type name | `FolderTypeName[241]` (+ `FolderTypeNameLen`) | 240 | `SHGetFileInfoW(SHGFI_TYPENAME)` of the system directory | previous value (empty at start) |
| Up-directory type name | `UpDirTypeName` (heap) | any | `LoadStrU8(IDS_UPDIRTYPENAME)` | "ERROR LOADING STRING" as before |
| Removable drive name | caller buffer | `SAL_DRIVE_TEXT_U8_MAX - 1` | `SHGetFileInfoW(SHGFI_DISPLAYNAME)`, suffix " (X:)" trimmed | "Removable Drive" |
| CD label | `ReadCDVolNameBuffer[SAL_DRIVE_TEXT_U8_MAX]` | same | `GetVolumeInformationW`, else the display name | "Compact Disc" |
| Drive item text | `CDriveData::DriveText` (heap) | any | letter, TAB, name (`&` doubled), [TAB free space] | - |
| Drive bar tooltip | `TOOLTIP_TEXT_MAX` buffer | 4999 | name [+ " (free space)"] | - |

Validation: every text is valid UTF-8; a text that does not convert whole counts as a failed
call (fallback), never as a cut text.
