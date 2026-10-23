# Fix log: 322 - the ISO plug-in checks an HFS+ catalog against the image; Joliet names kept whole

Backlog item `uniso-hfs-btree-trust-and-joliet-cut` (left by feature 223).

## Measured at a222bd88 (before any change)

By code reading and caller tracing, default configuration (`uniso=on` in `plugins.cfg`):

- Opening an image (`.iso`, `.dmg`, `.img`, ...) -> `CISOImage::CheckForHFS` (`ER` at block 0, or
  `H+` at 1024) -> `CHFS::Open` (alone - `fsHFS`; or inside `CUDFISO` for hybrids, quietly) ->
  `CHFS::BTree::BTree`. There `node = pBTreeData + firstLeafNode * nodeSize` and
  `pBTreeData + fLink * nodeSize` (32-bit multiplication) are used without a comparison with the
  loaded size; `nodeSize` may be 0 or larger than the catalog; the record table
  (`node + nodeSize - 2 (i + 1)`) and each record offset are read unchecked; an `fLink` that points
  back never ends the loop (the pointer array is re-grown every turn); a catalog shorter than the
  header node is read past its end; `leafRecords` sizes a `malloc` directly.
- `GetRootName`, `ListDirectory`, `UnpackFile` read the key length, the name and the folder / file
  record behind the key without checking that they lie inside the node (223 bounded the name at 255
  units only).
- Joliet: `ListDirectoryRe` (files) -> `ConvJolietName` (UCS-2 -> UTF-8) -> `ExtractFileName` ->
  `ExtractExtFileName` -> `lstrcpyn(fileName, src, LengthOfFileIdentifier + 1)`: the UTF-8 name cut
  to the UCS-2 byte length. 12 CJK letters + `.txt;1`: 36 identifier bytes, 42 UTF-8 bytes, 35 kept.
  Folders go through `ConvJolietName` only - not affected.

`BL verify` recorded at a222bd88 (commit `[322] start`).

## Test images

- WSL Ubuntu (noble) had no image tools and no passwordless sudo. xorriso 1.5.6 fetched without root:
  `apt-get download xorriso libisoburn1t64 libisofs6t64 libburn4t64`, unpacked with `dpkg -x` into
  `~/tc-xorriso` (test tooling outside the repository; `probe/mkimg322.sh` does it once). Docker
  Desktop was not running - not used.
- `probe/mkimg322.sh` writes `hyb.iso` (ISO 9660 + Rock Ridge + Joliet + HFS+), `rr.iso`, `plain.iso`
  (each 458752 bytes) of a tree `folder/note.txt`, `top.txt`.
- Measured layout of `hyb.iso`: Apple partition map (`ER`, block 2048; `Apple_partition_map`,
  `ISO9660_data` at 16, `Apple_HFS` at 60 for 11 blocks); HFS+ volume header at 123904; block size
  2048; catalog at partition block 1, 8192 bytes, node size 4096, one leaf node (node 1) with 8
  records (`TC322` root folder, `folder`, `top.txt`, `note.txt`, threads); `top.txt` data at
  partition block 8, `note.txt` at 7. So the bytes from offset 122880 are a valid HFS+-only image
  (zeros at 0, `H+` at 1024) - the probe's HFS+ seed.
- Joliet CJK images: IMAPI2 (as feature 223's probe).

## Scope decision (during implement)

This run does not generate mutated or damaged images (a mutation script was started and removed
before it was used or committed). The bounds are proven by `saltests` checks on catalogs built in
memory, each with one field out of range; the probe uses valid images only. The item's "fuzzing pass
over HFS+ / ISO9660 / Joliet / Rock Ridge" is therefore a deviation (stop-rules §2.14): recorded in
the spec's Assumptions and as an Inbox item for the maintainer.

## Analyze

Round 1: 0 CRITICAL, 0 HIGH; U1 (MEDIUM, hang criterion) fixed in T003; C1 (Joliet surrogates keep
the existing fallback) and A1 (how the HFS+-only seed is made - measured above) accepted.
