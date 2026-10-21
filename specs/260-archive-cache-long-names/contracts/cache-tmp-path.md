# Contract: the disk cache's temporary path (feature 260)

Core-internal (`src/cache.h`); the plug-in interface is unchanged (version 108 in the tree).

- `CDiskCache::GetName(..., int* errorCode, BOOL longTmpPath = FALSE)`: a new trailing argument.
  - `FALSE` (every existing caller, the plug-in services `CSalamanderDiskCache` / viewer services in
    `src/zip.cpp`, the User Menu): the temporary path fits when `strlen(folder) + strlen(name) + 1 <=
    MAX_PATH` bytes - unchanged.
  - `TRUE` (the core's F3 and F4 of archive members only): it fits when folder + name have at most
    `MAX_PATH - 1` UTF-16 units (`SalCacheTmpPathFitsU8`, `src/common/salcachename.h`); the UTF-8
    path may then have up to `3 * (MAX_PATH - 1)` bytes.
  - Not fitting: `NULL`, `*exists = TRUE`, `DCGNE_TOOLONGNAME` - as before.
- Feature 275 lifted the 520-byte limit below: F3 / F4 hand the archiver the path inside the
  archive whole (see `specs/275-arcmember-long-path/contracts/arc-member-path.md`); the text of this
  item records the state at 260.
- In practice the UTF-8 path stays under about 260 + 520 bytes: before the cache is asked, F3 / F4
  refuse a member whose path inside the archive has 520 bytes or more (feature 095, kept - the
  longest name an archiver plug-in has ever received). Within that, an archiver plug-in's
  `UnpackOneFile` now gets a target folder (the cache folder, < 260 bytes) + a member name whose
  join may exceed MAX_PATH bytes - the same kind of input F5 (extract) has given it since names
  over 255 bytes are listed (feature 222). Measured with ZIP (probe 260); by reading 7-Zip, tar,
  uniso and uncab take it (heap or refusal); the disabled unrar copies `nameInArchive` into
  `char[MAX_PATH]` (an Inbox item - reachable before through long folder paths), unchm / demoplug
  refuse without a message (review of 260, S2).
- An item already in the cache is found by its key as before; the mode matters only when a new
  temporary file is placed.

# Contract: the tar plug-in's gzip stored name (feature 260)

- The ORIG_NAME field is read whole (up to 64 KiB; more = too long); the last part after `/` is
  the name, `:` becomes `_` (as before).
- A decoded name over 255 UTF-16 units: the archive is refused (listing and extraction) with the
  system's text for `ERROR_FILENAME_EXCED_RANGE`, title "GZip Error". No member, no file.
