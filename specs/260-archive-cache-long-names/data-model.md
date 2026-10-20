# Data model: 260

- **Temporary copy path** = cache folder (`CCacheDirData::Path`, `%TEMP%\SALxxxx.tmp\`, < MAX_PATH
  bytes) + the member's name (UTF-8, up to 765 bytes). Fits (long mode): UTF-16 units of the whole
  path <= 259. Fits (legacy mode): bytes + 1 <= 260.
- **Edited-copy record** (`CFileTimeStampsItem`): ZIP root, source path (the cache folder), file
  name (the member's name), DOS name, time, size, attributes - unchanged; only the buffers that
  join source path + name become heap strings.
- **gzip stored name** (`CDecompressFile::OldName` + new `OldNameTooLong` flag): the decoded name,
  or "too long" when the header field passed 64 KiB.
