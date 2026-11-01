# Research - 368-uniso-multi-extent

## R1 - What a multi-extent file is

- Decision: ECMA-119 (ISO 9660) 9.1.6 file flags bit 7 *Multi-Extent*: "the Directory Record is not the final
  Directory Record for the file". The file's records are consecutive in the directory and carry the same File
  Identifier; the file's content is the extents (file sections) in record order, each of its record's Data Length.
  Linux `isofs` (`fs/isofs/inode.c`, `isofs_read_level3_size`) and libisofs read it so; the measurement's `isoinfo -x`
  joined BIG.BIN in record order (7144 bytes, the expected SHA-256).
- Rationale: matches the standard and every reader; the xorriso image of the measurement uses two extents
  (4,294,965,248 + 5,048).
- Alternatives considered: joining by disc order (wrong: the standard orders by record); joining non-consecutive
  records of one identifier (rejected: two records of one name with no bit are two files - feature 338's twins).

## R2 - Grouping key

- Decision: the raw identifier bytes and length of the records (ISO 9660 or Joliet UCS-2 bytes). The listed name,
  date and attributes come from the first record (its Rock Ridge name when the volume uses Rock Ridge).
- Rationale: the raw identifier is the same in every record by the standard; Rock Ridge NM may be in the first
  record only (row U-RRFIRST); comparing raw bytes needs no name conversion.
- Alternatives: comparing listed names (Rock Ridge NM missing in later records would break the chain).

## R3 - A broken chain

- Decision: leave the file out, `Error(IDS_ERROR_LISTING_IMAGE, FitCheck, <directory sector>)` and
  `ListingLeftOut.SetIncomplete()` (only in the real walk, not in the fit-check count walks); the directory walk
  goes on (the record that broke the chain is processed as usual).
- Rationale: item - "at least reported as not extracted"; project rule - fail closed; feature 330 uses the same box
  for a directory it cannot read. `ListingLeftOut.Add` would report "file name too long" (its reason text is the
  system's ERROR_FILENAME_EXCED_RANGE) - wrong reason. Returning `ERR_CONTINUE` from the walk would also stop
  descending into later folders (330's "descend only when everything is OK") - more lost than needed.
- Alternatives: list the parts found as the file (a cut file extracted as if whole - rejected); list the parts as
  before (the defect).

## R4 - Form 2 tracks and tracks of the extents

- Decision: a chain is listed only when every extent lies in the track of its first extent, at or after that
  track's extent offset, the sectors of each extent stay within 32-bit sector numbers, and that track does not
  store Form 2 data (`SalIsoTrackStoresForm2`); otherwise as R3.
- Rationale: `CISOImage::UnpackFile` opens the track of the first extent and reads every sector from it; 366 / 367
  read Form 2 per record with stream coverage (336 / 337) computed from one contiguous span - extending both to
  chains adds risk for a case that does not occur (Mode 2 discs are CDs).
- Alternatives: per-extent Form 2 reading (rejected, scope and risk).

## R5 - Reading

- Decision: `CFilePos` gets an owned array of extents (count > 1 only) and a destructor; `CISO9660::UnpackFile`
  walks the extents: for extent i, sectors `ceil(len / 2048)`, bytes of sector s `min(2048, len - 2048 s)`; an extent
  of length 0 contributes nothing. Read errors, cancel and the result go through the existing code
  (`SalIsoFileUnpackResult`).
- Rationale: the existing loop reads 2048-byte sectors; the plan is a pure function testable in `saltests`.

## R6 - Test images

- Decision: synthetic images by `img368.py` (all name kinds, out-of-order extents, broken chains, a folder with the
  bit) plus one real `xorrisofs -iso-level 3 -R -J` image with a 4 GiB + 3000 byte file (`mkimg368.sh`, WSL
  Ubuntu; genisoimage refuses such a file).
- Rationale: the real image proves the item's case; the synthetic ones cover the rule's branches quickly.
