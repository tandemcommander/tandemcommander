# Research - 363-uniso-udf-fid-bound

## R1 - What the walk holds from an identifier

- Decision: the bound is `sizeof(directory) - p` = `2 * SECTOR_SIZE - p` bytes.
- Rationale: `ScanDir` reads two sectors from `lbNum` (`ReadBlockPhys(lbNum, 2, directory)`) and keeps `p <=
  SECTOR_SIZE` before every read (it steps one sector forward when `p > SECTOR_SIZE`); `p` starts at the
  descriptor's `Offset` - 0 for short / long / extended descriptors, `< SECTOR_SIZE` for an embedded folder
  (`ReadFileEntry`, feature 361). So at least `SECTOR_SIZE` bytes are held from every identifier.
- Alternatives: bound by the folder's length (`dirICB.Length`) - stricter, would refuse identifiers that the walk
  reads today when a folder's length is not a whole number of identifiers; not the item's point (multi-extent and
  length questions are other Inbox items).

## R2 - Padded or unpadded length

- Decision: the padded length `4 * ((38 + L_IU + L_FI + 3) / 4)` must fit.
- Rationale: it is the step to the next identifier; with it the next `p` is at most `2 * SECTOR_SIZE`, after the
  one-sector step at most `SECTOR_SIZE`, so the next head (tag 16 bytes, identifier head 38 bytes) is in the buffer.
  UDF (2.01, 2.3.4) limits an identifier to one logical block, padding included, so a valid identifier at a
  position of at most one sector always fits.
- Alternatives: `38 + L_IU + L_FI` only (the item's wording) - leaves up to 3 bytes of overshoot of the next
  position; harmless for the next head but not "never past the buffer" as a rule.

## R3 - What a refusal does

- Decision: the existing invalid-tag path of `ScanDir`: `Error(IDS_UDF_INVALID_TAG_ID); return ERR_CONTINUE;`.
- Rationale: the item ("refused like an invalid tag; the folder is marked incomplete"); 330 made every walk result
  other than `ERR_OK` mark `ListingLeftOut` in `ListDirectory`, and a nested `ERR_CONTINUE` stays `ERR_CONTINUE`.
- Alternatives: skip only the identifier and continue - impossible: its length is what is damaged, the next
  position is unknown.

## R4 - Callers

- `CUDF::ReadFileIdentifier` - one caller, `CUDF::ScanDir` (grep at 443ee778). No other walk of file identifiers in
  the plug-in (`UDF_TAGID_FID` appears only in `ScanDir` and `udf.h`).
- `ScanDir` - called by `ListDirectory` (root) and itself (sub-folders).

## R5 - Measurement before

`probe/result_before.txt` (443ee778, Debug): L-AIU, L-AIU4K, L-AFI no window; R-AIU, R-AIU4K, R-AFI extracted
`UDF (TC330)/_/side.txt`; R-TIU an empty `UDF (TC330)/_`; R-SIU `UDF (TC330)/a/_`; image deleted in all five; controls
PASS. No crash: the stack above `ScanDir` held the 64 KB read (not relied upon).
