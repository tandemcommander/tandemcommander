# Research - 403-uniso-dir-length

## R1 - Where the length goes wrong

- Decision: the one site is `CISO9660::ListDirectoryRe` (`int size = root->DataLength;`,
  `new char[size]`). Joliet and the ISO 9660 part of a UDF hybrid reach it through
  `CISO9660::ListDirectory`; the fit and count walks too.
- Measured: `iso403_probe` before, IS-NEG / IS-NEG2 / IS-MIN - memory box; Ignore -> uncaught C++
  exception, program closed (bug report).
- Alternatives: none - the file path reads a sector at a time (`CISO9660::UnpackFile`).

## R2 - The limit

- Decision: 256 MiB (`SAL_ISO_DIR_MAX_LENGTH`).
- Rationale: a 2048-byte sector holds roughly 6 (Rock Ridge, long names) to 40 (short ISO names)
  records: 256 MiB is 0.8 - 5 million entries in one folder - far above any real image; a 256 MiB
  allocation does not fail on x64 in practice.
- Alternatives: only refuse >= 2 GiB (the minimum) - would still allocate up to 2 GiB for a damaged
  record (IS-HUGE: allocated, then failed at the read); a limit from the volume size in the primary
  descriptor - not all images give a trustworthy volume size (multi-session, hybrids).

## R3 - Past the end of the image

- Decision: for a folder of more than one sector, read its last sector (1 byte, `ReadBlock`) before the
  allocation; a failed read = a folder that cannot be read.
- Rationale: the same read path as the folder's own read (every container: plain, raw sectors, NRG,
  CCD, ISZ, DMG), no file-size API needed; one extra read only for multi-sector folders (the buffered
  file caches it for the following read when it is near).
- Alternatives: compare with the file size - wrong for compressed containers (ISZ / DMG) and track
  offsets; rely on the read failing after the allocation - allocates first (the item's *Expected* says
  before).
- The last block: `block + (length - 1) / sectorUserSize` in 64-bit; past 0xFFFFFFFF refused
  (`ReadBlock` takes a 32-bit block; `GetSectorOffset` takes an `int`, a block above 2^31 gives a
  negative offset whose seek fails - also a failed read).

## R4 - The outcome

- Decision: the existing failed-read path (box once per walk; ERR_TERMINATE, ERR_CONTINUE for the root;
  `ListDirectory` marks the listing). No new string.
