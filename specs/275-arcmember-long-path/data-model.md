# Data model: 275

No stored data changes. The values involved:

- **Path inside the archive** (`nameInArchive`, UTF-8): the member's folder as the listing stores
  it + `\` + its name. Bounded by the listing: folder part <= `MAX_PATH - 5` bytes, name <= 255
  UTF-16 units (<= 765 bytes). Before: refused by F3 / F4 at >= 520 bytes. After: no own limit.
- **Disk-cache key** (`dcFileName`): the archive's key + `\` + the path inside the archive (+
  `:0x<pointer>` for case twins in F3). Unchanged (heap since 095, same bytes).
- **Temporary copy's path**: cache folder + `\` + the member's name (or F3's valid shortened name).
  Judged by `SalCacheTmpPathFitsU8` (<= 259 UTF-16 units, feature 260) - unchanged; its refusal
  (`IDS_UNPACKTOOLONGNAME`) is now the only length refusal before extraction.
