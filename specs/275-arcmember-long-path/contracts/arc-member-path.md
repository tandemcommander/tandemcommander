# Contract: the path inside the archive handed to an archiver by F3 / F4 (feature 275)

Core-internal; the plug-in interface is unchanged (version 108 in the tree).

- `PackUnpackOneFile` (F3 `ViewFile`, F4 / Enter `ExecuteFromArchive`) hands the archiver the
  member's path inside the archive **whole, at any length the listing accepts** (a folder part of at
  most `MAX_PATH - 5` bytes + `\` + a name of at most 255 UTF-16 units: at most about 1,021 bytes).
  A plug-in that lists with a NULL path (`AddFile(NULL, ...)`, e.g. tar's single-file streams) gets
  no such check; the cache's rule then refuses a name that does not fit the temporary folder.
  Before 275 a path of 520+ bytes was refused with `IDS_UNPACKTOOLONGNAME` (feature 095).
- The only length refusal before extraction is the disk cache's rule for the temporary copy
  (`specs/260-archive-cache-long-names/contracts/cache-tmp-path.md`).
- An archiver plug-in's `UnpackOneFile` that cannot take the path must refuse it with a message,
  never cut it - the interface 104 promise (long names and paths), which F5 has relied on since
  feature 222. Shipped archivers: ZIP, 7-Zip, tar, uniso take it; uncab refuses a path over its
  buffer (`U8_MAX_CAB_NAME`) with `IDS_TOOLONGNAME` (unreachable with a real cabinet).
- Not shipped and known to overflow at 260+ bytes (also before 275): unrar, unchm - backlog items.
- Latent: the uniso listing joins paths in `char path[4 * MAX_PATH + 2]` without a bound; safe only
  while `AddDir` / `AddFile` keep the folder part at `MAX_PATH - 5` bytes. Whoever lifts that bound
  must fix the uniso listing first.
- The Archive Update dialog lists an edited member's whole path inside the archive (heap line,
  review of 275 M1 - a `3 * MAX_PATH` buffer showed only the folder at 780+ bytes).
