# Data model - 299-unpack-dialog-text-fits

No stored data. The two values the dialog hands to its caller:

| Value | Buffer (caller) | Rule |
|---|---|---|
| Target path (`IDE_PATH`, combo box) | `char path[MAX_PATH]` in `CFilesWindow::Unpack` | UTF-8 (WTF-8) length + NUL <= 260, else refused |
| Mask (`IDE_MASK`, edit) | `char mask[MAX_PATH]` | the same |

State: OK -> `Validate` (path, then mask) -> refused: the dialog stays, the field focused with its
whole text, nothing returned; accepted: `Transfer` reads both whole, the dialog closes with IDOK.
