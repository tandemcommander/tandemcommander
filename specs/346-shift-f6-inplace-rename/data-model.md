# Data model - 346

No stored data. No configuration value, registry value or file format is added or changed.

Runtime state reused (unchanged meaning): `CFilesWindow::QuickRenameIndex` (the item being edited)
and `CFilesWindow::QuickRenameRect` (the label rectangle the editor is sized from), now also set by
the keyboard entry point.

New identifiers: command `CM_QUICKRENAMEINPLACE` (2954), string `IDS_MENU_FILES_RENAMEINPLACE`
(13019).
