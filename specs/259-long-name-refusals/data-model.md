# Data model: 259

No stored data changes.

- **Copy name** (`SalMakeCopyNameU8`): input - the source name (UTF-8), folder or file, the
  localized `" - " + Copy` text, the attempt number (1, 2, ...); output - the candidate name
  (UTF-8, whole) and OK / TOOLONG. Valid when at most 255 UTF-16 units. See
  [contracts/copy-name-rule.md](contracts/copy-name-rule.md).
- **CDragDropOperData** (core-only struct, `shellib.h`): new field `BOOL SrcPathTooLong` - TRUE
  when the common folder of the list did not fit `SrcPath`; `SrcPath` is then empty.
