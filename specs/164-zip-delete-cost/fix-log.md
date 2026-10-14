# Fix log: 164 - deleting many members from a large ZIP archive is fast

Backlog: `specs/NEXT-WORK.md` item 15 (113; queue 108, entry 2): "the bound and `UpdateCentrDir`
walk the central directory once per deleted member (n x d)". Measure first whether it matters.

## Measured

`probe/zip_delete_cost_probe.ps1` + `bigzip.py`: an archive of N small deflated members
`d/a000000.txt ...`, every second one `*.del`; the panel enters `big.zip\d`, selects `*.del`
(Select, 841), deletes (F8, 729), Yes; the time from Yes until no window but the main one and the
panel answers (the probe waits 500 ms first - its floor). Afterwards Python's zipfile: exactly the
kept members with their own content, `testzip` clean.

| Members / deleted | Before (build at 163) | After |
|-------------------|-----------------------|-------|
| 2,000 / 1,000 | 0.5 s | 0.5 s (floor) |
| 10,000 / 5,000 | 2.6 s | 0.5 s (floor) |
| 30,000 / 15,000 | 21.9 s | 0.5 s (floor) |
| 100,000 / 50,000 | (not run; quadratic: minutes) | 1.0 s |

Debug build. 10,000 -> 30,000 (3x) took 8.4x: quadratic. Every archive BAD 0 before and after
(`probe/result_before.txt`, `result_after.txt`, `result_after_100k.txt`).

## Cause (by reading)

`CZipPack::DeleteFiles` (`del.cpp`), per deleted member: `SalZipNextMemberOffset` (113's bound:
where the next member on disk begins) walks every record; `UpdateCentrDir` walks every record
again, removes the member's record with a memmove of the rest and lowers the offsets between this
member and the next deleted one.

## Work

- `src/common/salzipdelete.h` (header-only): `SalZipBuildOffsetIndex` (the sorted offsets; fails
  exactly where `SalZipNextMemberOffset` fails), `SalZipNextFromIndex` (binary search),
  `SalZipApplyDeletions` (one pass: records equal to a processed member removed, the records
  between processed member k and the next deleted member lowered by delta[k], read and written as
  `UpdateCentrDir` did). The header's comment carries the equivalence argument.
- `del.cpp`: the fast path when the index builds, `DelFiles` ascends strictly (the callers sort it;
  duplicates take the old path) and the batch array is allocated; each member is recorded exactly
  where `UpdateCentrDir` was called (after its data moved) and the batch is applied once before
  `DeleteFiles` returns - so errors, a cancel, BackupZip's partial move leave the same directory.
  Otherwise the per-member code, unchanged.
- saltests `TestZipDelete164`: 400 random directories (shuffled order, 32-bit and zip64 offsets, a
  foreign extra block before the zip64 one, part-way breaks): the bound against
  `SalZipNextMemberOffset` on the progressively updated directory and the result against a
  byte-level port of `UpdateCentrDir` - 0 mismatches; a directory with a zip64 marker without a
  value, a truncated and an empty one. **Negative control**: `v <= nxt` instead of `v < nxt` in
  the header - 55 directory mismatches, FAIL; restored - 0.

Build: BUILD SUCCEEDED; saltests 22,286 / 0; `check_encoding.py` TOTAL 0.

## Review

Independent refute-first review (read-only): nothing CRITICAL; the equivalence could not be
refuted (nothing reads the directory during the loop; `Recover`, `FinishPack`, `WriteCentrDir`
run after the batch; added files' records are not in the directory during `DeleteReplacedAfterPack`;
a lowered record stays below every later member; the bound and the limit clamp agree; lowered
32-bit values never become the marker; memory freed on every path; the saltests port faithful).
- NIT, taken: the 16-bit counts get an explicit `(__UINT16)` (the same value as the per-member
  decrements, modulo 2^16).
- NIT, taken: "no next member" is `~0ULL` tested as such (`nxt == ~0ULL || v < nxt`) - a zip64
  record at offset 0xFFFFFFFFFFFFFFFF past the last member was kept, the old code lowered it.
- SHOULD-FIX, pre-existing, recorded as the next feature (165, NEXT-WORK item 15): the plug-in's
  entry counts are 16-bit; a zip64 archive with 65,535+ entries keeps 0xFFFF and deletion counts
  down from it (100,000 -> 50,000 writes 15,535); the zip64 end record is written only for size or
  offset. Python's zipfile walks by size, so the probe's check did not see it.

## Regression

On the build before the two NITs: 113 zipskip 37 / 0 (replacing members, DeleteAfterPack,
RestoreReplaced), 110 zipname 42 / 0 (the del row), 097 arcwork 390 / 0 / 21 n/a (DELETE in ZIP).
On the final build: saltests 22,286 / 0, the probe 30,000 / 15,000 0.5 s and 100,000 / 50,000 1.0 s,
archives BAD 0, registry identical.
