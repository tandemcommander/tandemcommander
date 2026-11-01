# Data model - 385

- **Server path**: UTF-8 / WTF-8 text held by the FTP plug-in (feature 224 decodes code-page
  servers to UTF-8); a path kind (`ESalFtpSrvPathKind`, mapped from `CFTPServerPathType`) gives
  its separators and whether case matters.
- **Name**: the bytes between two separators (or a separator and an end). Two names are equal by
  `SalNameOrderEqualCI` on case-insensitive kinds, by bytes on the case-sensitive kind.
- No stored data, no state.
