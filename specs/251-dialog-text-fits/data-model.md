# Data model: 251

No stored data changes. The values involved and their limits (UTF-8 bytes with the terminator):

| Value | Kept in | Limit |
|---|---|---|
| Make File List file name | `CConfiguration::FileListName` | 260 |
| Make File List line format | `CConfiguration::FileListHistory[]` | 260 |
| User menu Command / Initial directory | `CUserMenuItem` (heap) | 260 |
| User menu Arguments | `CUserMenuItem` (heap) | 32,772 |
| Viewer / editor Command, Arguments, Initial directory | `CViewerMasksItem` / `CEditorMasksItem` (heap) | 260 |
| Hot path path | `CHotPathItem::Path` (heap) | 1,040 |
| Hot path name | `CHotPathItem::Name` (heap) | 260 |
| "If path is inaccessible go to" | `CConfiguration::IfPathIsInaccessibleGoTo` | 260 |
| Edit New default | `CConfiguration::EditNewFileDefault` | 260 |

Rule: a value is accepted when `SalWTextFitsU8(text, limit)`; otherwise it is refused and the
stored value stays as it was.
