# Data model - 318-pack-name-trailing-dot

No stored data. One value is decided on:

- **Archive full name** (`fileBuf` in `CFilesWindow::Pack`, UTF-8, at most `MAX_PATH` bytes): the
  result of `SalGetFullName` on the Pack dialog's entry.
  - **Last part**: the bytes after its last `\` (the whole name when there is none).
  - Rule `SalPackNameIsNotKeptAsTyped` (research R2): the last part is not empty and
    (ends with `.` or ` `) or (is a reserved device name, with or without spaces and an extension).
  - TRUE -> refused: `IDS_PATHISINVALID`, the dialog again, nothing written.
  - FALSE -> unchanged route (the "packed into itself" check, the question, the packer).
