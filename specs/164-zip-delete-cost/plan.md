# Plan: 164

- `src/common/salzipdelete.h` (header-only, the ZIP plug-in cannot compile a shared .cpp):
  `SalZipBuildOffsetIndex` (sorted offsets of every record, fails like `SalZipNextMemberOffset`),
  `SalZipNextFromIndex` (binary search), `SalZipApplyDeletions` (one pass: records of processed
  members removed, the records between a processed member and the next deleted one lowered by
  that step's delta, read and written as `UpdateCentrDir` did).
- `src/plugins/zip/del.cpp` `DeleteFiles`: the fast path when the index builds, `DelFiles` ascends
  strictly and the batch array is allocated; the members are recorded where `UpdateCentrDir` was
  called and applied once after the loop (every exit). Otherwise the per-member code, unchanged.
- saltests: a byte-level port of `UpdateCentrDir`, compared on random directories.

Constitution: PASS (no format, interface, string or registry change; incremental; the plug-in's
behaviour is unchanged except its speed).
