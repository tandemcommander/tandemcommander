# Data model - feature 380

No data is added or changed. The values involved:

| Value | Where | Limit | Rule after the fix |
|---|---|---|---|
| Full FS path (`reg:\HKEY_...\key`) | `GetFullFSPath` output, buffer of the core | `MAX_PATH` bytes incl. terminator | whole, or refused (`IDS_LONGNAME`, `success = FALSE`) |
| Focus name after Quick Rename | `QuickRename` `newName` | `MAX_PATH` bytes | whole, or empty |
| Focus name after rename by Move | `CopyOrMoveFromFS` `targetPath` (via `nextFocus`) | `2 * MAX_PATH` bytes | whole, or empty |
| Find Focus path / name | `PostFocusCommand` | `3 * MAX_FULL_KEYNAME + 1` / `3 * MAX_KEYNAME` bytes | whole, or refused (`IDS_LONGNAME`) |
