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

## Before (probe/result_before.txt, build of the branch before the code change)

`iso322_probe.ps1 -Label before` on the hidden desktop: PASS 11, FAIL 3.
- J-CJK12 FAIL: a file of 12 CJK letters + `.txt` extracted as the 12 letters without `.txt`
  (36 of its 40 UTF-8 bytes kept) - the Joliet cut reproduced.
- J-CJK40 FAIL: 40 letters + `.txt` (124 UTF-8 bytes) cut to 88 bytes inside a letter; the broken
  UTF-8 was then taken as code page text: a name of 92 mojibake units.
- HYB FAIL (by the first form of the row): the valid xorriso hybrid opens with "Cannot read sector
  #00000020." - from the Xbox reader (`xdvdfs.cpp:74`, not quiet), another reader: not this item;
  the row now records it (PASS = the program stays alive) and an Inbox item records the finding.
- J-ASCII, RR, PLAIN, HFS (HFS+ alone: volume folder TC322, top.txt extracted with 'TOP') PASS.

## Work

- `src/common/salhfscatalog.h` (new, header-only): `SalHfsCatalogWalk` - the header node must hold
  its descriptor and header record (120 bytes); node size 120 .. catalog size; first leaf 0 = an
  empty tree; every node (start, each fLink) wholly inside the catalog, met once (a bit per node);
  record table inside the node; each record offset >= 14 with its key length before the table;
  per record the bytes to the table (`Avail`). `SalHfsCatalogKeyView` - key length >= 6, key and
  record type inside `Avail`, the name inside the key.
- `hfs.cpp` `CHFS::BTree::BTree`: an empty catalog or one larger than its blocks is refused before
  the allocation; the walk replaces the unchecked loop (`leafRecords` no longer sizes an allocation;
  the walk counts the records, as the MagicISO workaround did); NOT_HEADER keeps the old message,
  DAMAGED shows the new `IDS_ERR_HFS_BTREE_DAMAGED`. `GetRecord` returns the record's `Avail`.
- `GetRootName`, `ListDirectory`: a record whose key / name does not fit is skipped; in
  `ListDirectory` also a folder / file record shorter than `HFSPlusCatalogFolder` (88) /
  `HFSPlusCatalogFile` (248). `UnpackFile`: the same checks before the forks are read (refuses with
  the new message; the listing already filtered such records).
- `iso9660.cpp` `ExtractExtFileName`: for Joliet the name `ConvJolietName` made is copied whole.
- `uniso.rh2` / `lang.rc2`: `IDS_ERR_HFS_BTREE_DAMAGED` 1061 (free slot of the 1056-1071 bundle,
  rule 084) "The Catalog file of the HFS Plus partition is damaged.\nThe partition cannot be read."

## Checks

- `.\build.cmd` -> BUILD SUCCEEDED (the C4267 warnings are the existing `fd.NameLen = strlen` of
  every reader).
- `saltests`: first run 3 FAIL - the test's own data: the four records (512 bytes) did not fit a
  512-byte node and the helper wrote past its node; node size 1024 and a fit guard in the helper
  (a CHECK) -> `saltests: 27776 checks, 0 failed` (30 new in `TestHfsCatalog322`).
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Probe after (probe/result_after.txt): PASS 14, FAIL 0, NOT DRIVEN 0 - J-CJK12 extracted under
  its 16 units with 'CJK12', J-CJK40 whole; HFS / RR / PLAIN / J-ASCII as before; HYB alive, the
  same Xbox message as before.
- Feature 223's probe (probe/result_223_after.txt): ISO-F5 PASS; RR-LONG NOT DRIVEN (Docker not
  running) - covered by the new RR-LONG row of iso322_probe (xorriso, a 200-letter Rock Ridge name).

## Translations (stop-rules §2.13)

- Step 0: one new entry, `IDS_ERR_HFS_BTREE_DAMAGED` (STRINGTABLE:4:1061); no changed entry.
- `english_fallback` rows in `uniso.origin` before: 0 in every language.
- Dry run: 1 unique gap, ~85 chars in each of cs de fr nl hu ro sk es. Real merge
  `--formality prefer_more --budget 3360`: DeepL characters sent 736, validation failures 0.
- Read back: formal / neutral register everywhere. Pinned in `translations/ui-overrides.json`
  (`uniso`, `_feature_322`) for 7 languages: the module's established term for the Catalog file
  (1056/1057: cs/sk "Soubor/Súbor katalogu", fr "fichier Catalogue", es "fichero Catálogo"),
  no space before the line break (de/nl/hu/sk), the full stop (fr/es). ro kept as DeepL gave it.
  Second merge: 0 gaps.
- `python -m translate.slt --verify` -> 298 files, round-trip byte-exact.
- Layout drift: `IDC_CFG_BOOTIMAGEASFILE` (1203) widened in 7 languages (all but fr) - 1
  re-laid-out control each; committed as the pipeline's output.

## Final checks (after `build.cmd full`)

- `.\build.cmd full` -> BUILD SUCCEEDED, 189 language modules.
- `saltests: 27776 checks, 0 failed`.
- Probe after (probe/result_after.txt, with the RR-LONG row): PASS 16, FAIL 0, NOT DRIVEN 0;
  registry restored and identical.
- Finding on the way (not this feature - an Inbox item): the plug-in does not read the Rock Ridge
  names of xorriso / libisofs images. `ExtractExtFileName` recognises Rock Ridge only by an `RR`
  entry in the first SUSP entry, which RRIP 1.12 dropped (genisoimage still writes it - feature
  223's image); xorriso's images list the ISO 9660 names (`TOP.TXT`, a 200-letter name as 31
  letters) - measured the same before this feature (RR row: `TOP.TXT` in result_before.txt). The
  RR-LONG row therefore checks that the file is extracted whole with its content and records that
  the Rock Ridge name was not used.
