# Data model - 319-pack-name-colon

No stored data changes. One value is decided on:

- **Full archive name** (`fileBuf` in `CFilesWindow::Pack`, UTF-8, at most `MAX_PATH` bytes):
  the output of `SalGetFullName` - `X:\...\last` or `\\server\share\...\last`.
  - **Last part**: the bytes after the last `\` or `/` (after the drive prefix `X:`).
  - Rule `SalPackNameHasStreamColon`: the last part holds `:` → refused (always).
  - Rule `SalPackNameIsNotKeptAsTyped` (318): a trailing dot / space or a device name → refused
    unless a file of exactly that name exists.
  - Otherwise: on to the packer as before.
