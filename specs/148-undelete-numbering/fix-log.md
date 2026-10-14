# Fix log: 148 - Undelete numbers equal names without taking a name the list already has

Backlog: `specs/NEXT-WORK.md` A.4 (queue 104 entry 2; 115 `research.md` 4).

## Before (`probe/result_pre148.txt`, `Debug_x64` at `b5a7cafa`)

114 probe, new image kind `num` in `make_images.py` (exFAT: deleted `a.txt` x2, deleted
`a (1).txt`) and row `num`: restoring all three asked "overwrite?" for `a (1).txt` (the probe
answered Skip: 2 files restored; Yes would have replaced the third file's content with the first
one's). `CFileList::RenameDuplicateFiles` (fs2.cpp) numbered the group from 1 regardless of the other
names; the FAT listing (`library/fat.h`) the same.

## Work

- `src/common/salnumbername.h` (new, header-only): `SalNumberedNameAlloc` (AddNumberSuffix's rule)
  and `SalPickNumberedNames(count, names, renumber, out)` - the smallest number per original name
  whose result is neither a kept name nor one chosen before (`SalNameOrderCompareCI`); sorted sets
  with binary search (review: the first version searched the per-name counters linearly and
  inserted by a linear scan - quadratic for {All Deleted Files}).
- `fs2.cpp` `RenameDuplicateFiles` and `fat.h` `RenameDuplicateDirectories`: the groups as before,
  the names from the rule (copied into `new[]` for the owners' `delete[]`).
- `fat.h`: a folder of one item returned BEFORE the recursion - nothing below it was ever numbered
  (review, pre-existing); now only the sort is skipped.
- `saltests` `TestNumberName148`: 13 checks incl. a 40,000-item list (unique, about 0.3 s in Debug).

## Review (refute-first agent, 2026-10-14)

No correctness defect (byte-identical names without a collision; uniqueness traced). Taken over:
the O(items x groups) counter search and the linear insertion (MEDIUM / LOW, performance); the
one-item folder that stopped the FAT recursion (MEDIUM, pre-existing). Recorded:
`String<char>::AddNumberSuffix` is unused now; "smallest n" is not strict for two spellings equal by
the rule with different byte lengths (results stay unique); `RenameDuplicateDirectories`' return
value is ignored by its caller (pre-existing).

## After (final build)

- `saltests` 21,829 -> 21,842, 0 failed; `check_encoding.py` TOTAL 0.
- 114 probe **33 / 0 / 4** (row `num` PASS: `a (1).txt` = its own content, `a (2).txt`, `a (3).txt`
  = the two `a.txt`, no box); 115 probe **23 / 0 / 2** (as recorded).
- Not driven: the FAT listing below a one-item folder (by reading).
