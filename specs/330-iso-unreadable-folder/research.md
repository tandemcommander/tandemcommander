# Research - 330-iso-unreadable-folder

## R1 - Where to mark the ISO 9660 listing

- **Decision**: once, in `CISO9660::ListDirectory`, on the real walk's result: `!= ERR_OK` marks the
  listing incomplete.
- **Rationale**: every failure inside `ListDirectoryRe` returns `ERR_TERMINATE` / `ERR_CONTINUE`; the
  parent turns a nested `ERR_TERMINATE` into `ERR_CONTINUE`, keeps it in `ret` (which also stops later
  descents - "descend only when everything is OK") and returns it; so the top result is non-OK exactly
  when some directory failed. One site covers the read error, the two record safety checks, the zero
  block / size return, out of memory (visited set, data buffer, name buffer) and future error returns.
  The root's read failure returns `ERR_CONTINUE` (it keeps an "empty image" openable) - marked too.
  A directory met again (328's visited set) returns `ERR_OK`: a cycle in a crafted image, listed as an
  empty folder - not marked (spec edge case).
- **Alternatives**: a mark at each `Error(IDS_ERROR_LISTING_IMAGE)` site - misses the silent zero
  block / size return and needs a `FitCheck` guard at each site (count walks are not the listing);
  rejected.

## R2 - The UDF and Xbox readers

- **Decision**: mark at each site that shows `IDS_ERROR_LISTING_IMAGE` (UDF: the File Set Descriptor
  read in `ListDirectory`, `ScanDir`'s first read and continuation read; Xbox: `ScanDir`'s read).
- **Rationale**: these are "a folder that could not be read" with the same box; a top-level non-OK
  rule there would also mark entries skipped as damaged (`MapICB` of a file -> `ADD_FAILED`, an invalid
  tag) - the separate Inbox item `iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let`, kept out of
  scope. These readers have no count walks, so no guard is needed.
- **Alternatives**: leave UDF / Xbox for another item - rejected: the item's title ("an image whose
  folder could not be read") and the same box apply; it is three or four lines.

**Revised after review 1** (a reviewer that stopped; its probe rows): marking only the box sites
left three UDF folders that cannot be read unmarked - a folder whose file entry cannot be mapped
(listed empty, no box), an invalid tag in a directory, the root ICB not found ("Bad root ICB") - each
measured deleting the image of a hybrid whose UDF part alone held `side.txt`. Decision now: UDF and
Xbox use R1's top-level rule, UDF also marks its early returns and the unmapped folder. This also
marks a UDF *file* whose entry cannot be read (it ends its directory with `ADD_FAILED`), a part of
the Inbox item `iso-plug-in-udf-and-hfs-entries-skipped-as-damaged-let` - its HFS+ part stays open.
The Xbox walk's padding `break` is its normal end of a padded directory: not marked.

## R3 - A pure rule for saltests?

- **Decision**: none. The decision is one comparison of the plug-in's walk result constants
  (`ERR_OK`), which live in the plug-in; `CSalListingLeftOut::SetIncomplete` is already tested (328).
  Proof is the probe with damaged images and its controls.

## R4 - Probe images

- **Decision**: seeds from genisoimage in WSL (as 328 / 329: `~/tc-genisoimage`):
  `rd.iso` = `-R` of `a/side.txt`, `top.txt`, `zlast/z.txt` (328 review 4's tree), `ud.iso` = `-udf`
  of the same tree. Patched copies by `img330.py`: ISO 9660 folder A's extent past the end (`rd_ext`),
  a record inside folder A's directory with mismatched both-endian extent (`rd_rec`, safety check),
  the UDF folder A's file entry allocation descriptor past the end (`ud_ext` - `ScanDir`'s read fails,
  not `MapICB`), and an Xbox image of the same tree written whole with folder A's start sector past the
  end (`xd_ext`) plus its undamaged twin (`xd.xiso`).
- **Rationale**: one tree, each reader's read-error site, and an undamaged control per reader (the
  image deleted after a full unpack - FR-005).
