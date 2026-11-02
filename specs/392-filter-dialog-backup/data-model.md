# Data model - 392-filter-dialog-backup

**Panel filter** (`CFilesWindow::Filter`, a `CMaskGroup`)

| Field | Meaning | After a refused edit (required) |
|---|---|---|
| `MasksString` | the group text, up to 1000 bytes | unchanged, byte for byte |
| `ExtendedMode` | `#` = a digit | unchanged |
| `NeedPrepare` / `PreparedMasks` / `MasksHashArray` | the prepared form used by `AgreeMasks` | unchanged (still prepared) |

**Check group** (local to `CFilterDialog::Validate`): the typed text (up to 259 bytes, feature
270) with the panel's `ExtendedMode`; destroyed at the end of `Validate`.

State: Validate never writes the panel filter; only `Transfer(ttDataFromWindow)` after a good
Validate does (as before).
