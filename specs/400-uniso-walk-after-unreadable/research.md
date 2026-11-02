# Research - 400-uniso-walk-after-unreadable

## R1 - Why the walks stopped descending

- Decision: replace "descend only when everything is OK" by "descend unless out of memory stopped the walk".
- Rationale: the old condition used one variable (`ret`) for two things - this directory's result and
  "may I descend". After a nested failure it stayed `ERR_CONTINUE`, so no later sibling folder, and
  (returned upwards) no later folder of any ancestor, was descended. 330 measured it; at aaf95b94 the
  probe rows RD-EXT, RD-REC, UD-EXT, UD-TAG, XD-EXT list `top.txt` only.
- Alternatives: keep the early stop (the item asks otherwise); resynchronise inside a damaged
  directory at the next sector (rejected: the item's point is later folders; a damaged directory's
  tail is not trusted - spec Clarifications).

## R2 - A failure must not be forgotten

- Decision: `ret = SalIsoWalkAfterChild(ret, child)` instead of `ret = child`.
- Rationale: with descents after a failure, `ret = child` would let a later good folder reset the
  directory to `ERR_OK`; the top result would then be OK and 330's mark (a whole unpack fails, the
  image is kept) would be lost - the data-loss case 330 fixed.

## R3 - Boxes

- Decision: one box per file system walk (`SalIsoWalkBoxQuiet`).
- Rationale: today a damaged folder shows one box and the walk ends its descents, so a listing shows
  one; descending later folders would show one per damaged folder (a crafted image: thousands).
  Quiet walks (328's fit check and count walks) stay quiet and do not use up the box.

## R4 - Loops

- Decision: the UDF and Xbox walks meet each directory once per walk (as 328's ISO 9660 walk);
  met again = listed as an empty folder, no box, the listing marked incomplete (review 2: two
  folders can name one directory - fail closed). Xbox key = start sector and size (review 1: each
  entry gives its own size).
- Rationale: their only bound was the listing's path-length rule; a folder listing itself twice
  doubles the walk per level (2^depth). Some crafted images ended early only because a failure
  stopped all descents; after this feature they would not. Keys: UDF ICB (partition, block); Xbox
  start sector. Legitimate images do not share directories.

## R5 - Out of memory

- Decision: out of memory sets `Stopped` (no later descent), as the old behaviour for every failure.
- Rationale: going on would fail again in every later folder. ISO 9660 / Xbox `ADD_FAILED` means out
  of memory only; UDF's `ADD_FAILED` also means "a file entry cannot be read" - so `Stopped` is set
  at the out-of-memory sites, never derived from `ADD_FAILED` in UDF.
