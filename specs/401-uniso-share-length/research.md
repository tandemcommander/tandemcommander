# Research - 401-uniso-share-length

## R1 - Walk again or mark incomplete?

- Decision: walk the folder again for its own length (key = block and length).
- Rationale: the item's *Approach*; feature 400 did the same for the Xbox walk (review 1's MUST,
  `xd_share.iso`); every file the record covers is listed and extracted, the image is deleted only when
  everything was extracted.
- Alternatives: mark the listing incomplete when a block is met with another length - keeps the image
  but lists fewer files than the image holds; rejected (the item lists it only as the fallback).

## R2 - Is the walk still bounded?

- Decision: yes - each walk inserts each (block, length) pair once; the pairs come from directory
  records of the image, so a walk performs at most (number of distinct pairs in the records it reads)
  + 1 directory walks. A folder pointing to itself with a longer length (IS-LOOP) is walked once per
  length and then met again.
- Cost: a crafted directory of N folder records at one block with N lengths reads the block N times
  (IS-MANY: 40); the same bound 400 accepted for the Xbox walk. 328's decision mode (count walks) adds
  and removes keys exactly as before.

## R3 - Which length?

- Decision: the record's `DataLength` (the value `ListDirectoryRe` reads as `size`), with the block
  after the extended attribute record (`block`), i.e. exactly the two values the walk reads with.
- Rationale: two records with the same pair read the same bytes; different pairs may read different
  bytes.

## R4 - Same block, same length met again

- Decision: unchanged (328: listed empty, not marked). UDF / Xbox mark it since 400 (review 2) -
  the difference goes to the Inbox (stop-rules §1 step 4: the item does not name it).

## R5 - One key rule

- Decision: `SalIsoFolderVisitKey(start, length)` in `src/common/salisowalk.h` = `(length << 32) |
  start` as 64-bit, used by the ISO 9660 and Xbox walks (the Xbox walk's inline formula is the same
  value); tested in saltests (distinct lengths give distinct keys, start and length do not alias).
