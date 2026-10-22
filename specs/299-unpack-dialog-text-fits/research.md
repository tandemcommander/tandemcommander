# Research - 299-unpack-dialog-text-fits

## R1 - Is the dialog reachable without an external unpacker?

- Decision: yes; the fix and the probe use the default configuration (the ZIP plug-in).
- Rationale: `CM_UNPACK` (Alt+F9) -> `CFilesWindow::Unpack` always opens `CUnpackDialog`, whatever
  unpacker the combo box offers; measured at 4787b56b (probe rows FAIL with the ZIP plug-in).
- Alternatives considered: configuring a test external unpacker (the item's note) - not needed.

## R2 - Where to refuse

- Decision: `CUnpackDialog::Validate` with `DlgItemTextFitsU8` (path, then mask), buffer size
  MAX_PATH.
- Rationale: winlib calls `Validate` before `TransferData` on OK; the helper measures the whole
  WTF-8 length, shows `IDS_TOOLONGPATH` and marks the field (`ErrorOn`) - the pattern of 214 / 291.
  The caller's `path` and `mask` are `char[MAX_PATH]`.
- Alternatives considered: growing the buffers to heap (`CSalPathBuf`) - the downstream code
  (`SalGetFullName`, `CheckAndCreateDirectory`, `ExecuteUnpacker`) works in MAX_PATH buffers; a
  larger scope than the item. A `CB_LIMITTEXT` on the path combo - UTF-16 units cannot express a
  byte limit (214), and the refusal covers it.

## R3 - Text that is too long for the field limit but not the buffer

- Decision: nothing to do. The mask edit's limit is 259 units (`EditLine`), ASCII text always fits
  the 260-byte buffer; the path combo has no limit.
