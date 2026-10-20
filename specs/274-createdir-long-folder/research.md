# Research - 274 Create Directory takes a relative name in a long folder

## R1 - Where the refusal comes from

- Decision: pass `nameBufSize = SAL_MAX_PATH_UTF8` to `SalGetFullName` in `CFilesWindow::CreateDir`.
- Rationale: `path` is `char[SAL_MAX_PATH_UTF8]` and every later step (`GetRootPath`, `CheckPath`,
  `CheckAndCreateDirectory` with `newDir[SAL_MAX_PATH_UTF8]`, `SalCreateDirectoryEx`) is long-path
  capable since feature 027; only the join used the default `MAX_PATH`. The "path..." branch of
  `SalGetFullName` refuses `l1 + l2 >= nameBufSize` - with the real buffer size it refuses exactly
  what does not fit. Measured: U255 (765 bytes in a 44-byte folder) was refused too, so the defect
  is any joined path of 260+ bytes, not only deep folders.
- Alternatives: a heap buffer - not needed, the buffer already has the program's maximum.

## R2 - The message for a name no file system takes

- Decision: check the new folder's own name (the last component of the full path) with
  `SalNameTooLongForFileSystemU8`; over 255 UTF-16 units -> `IDS_TOOLONGNAME` ("Cannot finish
  operation because of too long name.") in the same message box as the other pre-creation
  refusals of F7 (`IDS_ERRORCREATINGDIR` title); the dialog comes back.
- Rationale: feature 259 measured that Windows answers error 123 "invalid name" for such a file
  name and chose this text for Edit New File; F7 follows it. Checking before
  `CheckAndCreateDirectory` means nothing is created - also no missing parent folder of a
  multi-component name.
- Alternatives: let Windows answer (wrong reason - rejected in 259); a new string (needs the
  `.slt` refresh a run cannot do).

## R3 - Other callers with the default limit

| Caller | Buffer | Same defect? |
|---|---|---|
| fileswn7.cpp Pack (`fileBuf`) | `char[MAX_PATH]` | no - the limit equals the buffer |
| fileswn7.cpp Unpack (`path`) | `char[MAX_PATH]` | no |
| mainwnd4.cpp Make File List to a file (`fileName`) | `char[MAX_PATH]` | no |
| dialogs.cpp File List dialog, OK and Browse (`buffFile`) | `char[MAX_PATH]` | no |
| fileswn5.cpp Edit New File | `SAL_MAX_PATH_UTF8` | fixed in 259 |

Those routines are limited to 259 bytes as a whole (their buffers, their dialogs); raising
that is a different, larger change. Not changed here.

## R4 - Limits that stay

- A created folder whose name is 260+ bytes is not focused (`nextFocus` / `NextFocusName` hold
  259 bytes; `SalGetFullName` copies only a shorter name) - as Edit New File (259).
- An intermediate component over 255 units in a multi-component typed name keeps the system's
  answer from `CheckAndCreateDirectory`.
- A full path between 32,767 UTF-16 units and `SAL_MAX_PATH_UTF8` bytes keeps the system's answer
  from the creation step, as a typed absolute path already does.
