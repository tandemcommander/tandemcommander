# Research - 364-uniso-udf-folder-extents

## R1 - Walk every extent or only mark?

- Decision: both. Every leading recorded extent (up to 32) is walked; a folder whose walked extents are shorter than
  its Information Length marks the listing incomplete.
- Rationale: *Expected* allows either; walking gives the user the files of a valid fragmented folder (R-ROOTSPLIT,
  R-ROOTFRAG ...), the mark covers what cannot be walked (type 1 / 2 / 3, past 32, one short extent).
- Alternatives: mark only (simpler, but a valid fragmented folder could then never be unpacked whole - the image
  kept, files missing); read the whole folder into a heap buffer (needs a size cap that a valid single-extent
  folder could exceed today - a regression risk).

## R2 - How the walk crosses an extent boundary

- Decision: the two-sector window is filled per sector through the extent table; when both window sectors lie in
  one extent (or past the last) one `ReadBlockPhys(phys, 2)` as before, otherwise two one-sector reads.
- Rationale: ECMA-167 4/12.1 - every extent but the last is a whole number of logical blocks, so the folder's
  block k maps to exactly one extent; a file identifier (at most one block, UDF 2.01 2.3.4) read at most one sector
  into the window lies in the window (feature 363's bound unchanged). A one-extent folder makes the same reads as
  before.
- Alternatives: per-extent walks (an identifier crossing the boundary would be cut - measured garbled name in
  R-ROOTFRAG before).

## R3 - Stop reasons

- Decision: the walk takes descriptors while the type is 0 (recorded and allocated) and the length is > 0; it stops
  after an extent that is not a whole number of blocks. Type 1 / 2 (not recorded), type 3 (continuation, not
  followed - files do not follow it either), length 0 (ECMA-167 4/12: ends the sequence) stop it. "Read whole" =
  the walked sum >= the Information Length.
- Rationale: the Information Length is the folder's size by ECMA-167 4/14.9.10; whatever stops the walk, the
  folder is complete exactly when the walked bytes cover it.
- A first descriptor that is not type 0: nothing to walk -> 362's walkable check fails -> the existing unreadable
  folder path (before: walked over unrecorded bytes).

## R4 - Information Length smaller than the extents

- Decision: walk the extents' sum as before; not marked.
- Rationale: cutting to a smaller Information Length could hide entries without a mark (silent loss); the old
  behaviour is kept for a case the item does not name.

## R5 - The 32-extent limit

- Decision: `UDF_FOLDER_MAX_EXTENTS` = 32, as `UnpackFile`'s `icbs[32]`. More descriptors: the reader stops at 32
  (its trace), the sum stays below the Information Length -> marked.
- Rationale: bounded stack (`CUDFFolder` ~ 530 bytes per recursion level), consistent with files.
