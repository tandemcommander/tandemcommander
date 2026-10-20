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
- An item already in the cache is found by its key as before; the mode matters only when a new
  temporary file is placed.

# Contract: the tar plug-in's gzip stored name (feature 260)

- The ORIG_NAME field is read whole (up to 64 KiB; more = too long); the last part after `/` is
  the name, `:` becomes `_` (as before).
- A decoded name over 255 UTF-16 units: the archive is refused (listing and extraction) with the
  system's text for `ERROR_FILENAME_EXCED_RANGE`, title "GZip Error". No member, no file.
