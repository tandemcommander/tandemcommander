# Research: 290 - adding into a ZIP that holds case twins

## R1 - Where the decision is made

- Decision: inside `CZipPack::MatchFiles`, from the central directory the add already holds
  (`NewCentrDir`).
- Rationale: `PackToArchive` gets no plug-in data of the listing (271 contract point 4; the core
  interface is not changed - constitution V). The pre-pass over the central directory exists (the
  HS_UNIX test and the entry count); collecting the names there costs no read of the file (FR-004).
- Alternatives: hand the listing's `CPluginDataInterface` to the pack - needs an interface change
  (maintainer-owned); re-list the archive - a second read.

## R2 - The twin rule on flat paths

- Decision: `SalPathsHaveCaseTwins(paths, count, &lowMemory)`: every prefix of every path that ends
  at a whole part (before each separator, and the whole path unless it ends with one) is one name;
  252's `HaveTwinsInPlace` (byte-different, equal by `SalNameOrderCompareCI` or by the legacy fold)
  runs over all of them.
- Rationale: two byte-different paths that are equal ignoring case differ first in some part whose
  preceding parts are identical - that folder holds twins; conversely twins `a`, `b` in folder `F`
  give the prefixes `F\a`, `F\b`. The separator `\` has no case partner in either comparison (ASCII
  0x5C; the legacy fold maps no byte to it), so whole-string equality is part-wise equality. This is
  the same decision 271's listing makes with `SalDirTreeHasCaseTwins` on the case-sensitive tree
  (checked by a randomized cross-check in saltests).
- Alternatives: build a directory tree in the plug-in (more code, more memory); compare only names
  of the target folder (would differ from the listing's per-archive decision, and the folder part
  below the panel's folder - ADDFOLDER - would still be matched ignoring case).

## R3 - What "exact" means for the match

- Decision: when the archive holds twins, `rootIgnoreCase` FALSE and the new `nameIgnoreCase` FALSE:
  `SalZipNamePrefix` / `SalZipNameEqual` with `ignoreCase` FALSE (ASCII: bytes; UTF-8: ordinal on
  UTF-16; legacy text: `CompareStringA` without flags - the comparison a Unix-made ZIP already uses
  for the panel's folder).
- Rationale: measured, a Unix-made ZIP compares only the panel's folder exactly; below it, ignoring
  case (UNIX-ADDFILE replaced `A.txt` for `a.txt`). The item's *Expected* wants exact matching for
  every ZIP with twins.
- Alternatives: "exact first, else ignoring case" per added item - ADDFOLDER (`d\x.txt` with only
  `D\x.txt` in the archive) would fall back to `D\x.txt` and replace it; rejected.

## R4 - The `Unix` flag

- Decision: unchanged (set only by an HS_UNIX entry).
- Rationale: in `MatchFiles` it only (a) keeps asking about an item already skipped and (b) after a
  Yes renames the added item to the member's spelling (AF_OVERWRITE). With exact matching (b) is a
  no-op and (a) concerns exact duplicates only; leaving it keeps every other behaviour of
  Windows-made ZIPs.

## R5 - Low memory

- Decision: the add is refused with IDS_LOWMEM before anything is asked or changed.
- Rationale: guessing "no twins" could replace the other twin (the defect), guessing "twins" would
  change an ordinary archive's behaviour; `MatchFiles` already returns IDS_LOWMEM for its buffers.
