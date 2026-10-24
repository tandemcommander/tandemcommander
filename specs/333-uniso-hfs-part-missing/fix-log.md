# Fix log - 333-uniso-hfs-part-missing

Backlog item `iso-plug-in-an-hfs-part-of-a-hybrid-that-does-not-open-is` (review:330, NOTE 3 of review 2).

## Measurement at e9f777da (before any change)

Build: `.\build.cmd` (Debug x64, incremental, BUILD SUCCEEDED) at e9f777da.

Seeds (`probe/mkimg333.sh` in WSL Ubuntu, xorriso 1.5.6 fetched into `~/tc-xorriso`):

- `hdh.iso` - `xorriso -hfsplus on`, no Rock Ridge / Joliet, `a/side.txt` hidden from ISO 9660 (only in
  the HFS+ part). Apple partition map: `Apple_partition_map`, `Gap0` (`ISO9660_data`),
  `HFSPLUS_Hybrid` (`Apple_HFS`, start 55 x 2048) -> volume header "H+" version 4.
- `apm.iso` - the layout of Ubuntu / Debian install images: `xorriso -as mkisofs ... -e boot/efi.img
  -no-emul-boot -isohybrid-gpt-basdat -isohybrid-apm-hfsplus -isohybrid-mbr <template>`. Apple
  partition map: `Apple_partition_map`, `EFI` (**`Apple_HFS`**, start 35 x 2048) -> the EFI image, **no
  HFS+ volume header** (zeros here; a FAT boot sector in real images). libisofs needs the MBR template
  to start with `33 ED` + 30 NOPs ("MBR template file seems not prepared for Apple Partition Map"
  otherwise) - the script writes such a template.

Damaged copies (`probe/img333.py`): `ver` (volume header version 5), `cat` (catalog header node kind
0), `size` (catalog logical size 0), `ext` (catalog extent 0 start 0xFFFFF0), `nosig` ("H+" zeroed).

Probe `probe/iso333_probe.ps1` on the hidden desktop (`probe/result_before.txt`):

| Row | Result at e9f777da |
|---|---|
| H-OK | PASS - 5 files of both parts, image deleted: **a valid xorriso hybrid's HFS+ part opens** (the item's first question) |
| H-VER, H-CAT, H-SIZE, H-EXT | FAIL - only the ISO 9660 part's 2 files, no new window, **image deleted, side.txt lost** |
| H-NOSIG | PASS (limit row: image deleted) |
| APM-EFI | files and deletion as wanted; FAIL only for a box "Cannot read sector #00000200." - not this item (the probe now ignores it; Inbox item) |

9 PASS / 5 FAIL. Defect present and reachable: Unpack (Alt+F9) of the whole image with "Delete archive
after unpacking" in the default configuration (uniso on).

Caller chain: `CISOImage::OpenTrack` (`fs*_HFS`, `fs*_APFS`, and every `fsUDF_ISO9660`) -> `CUDFISO::Open`
-> `CHFS::Open(TRUE)` fails -> `delete hfs`, `PartMissing` only from ISO / UDF -> `CUDFISO::ListDirectory`
lists ISO / UDF only, `ListingLeftOut` unmarked -> the whole unpack succeeds -> the image is deleted.

## Design decision

`DetectTrackFS` takes "ER" at sector 0 (an Apple partition map) as an HFS part. The APM install image
has "ER" and an `Apple_HFS` partition, but no HFS+ volume: marking every HFS part that does not open
would make every Ubuntu / Debian style install image never unpack whole. So the declaration is the
HFS+ volume header's own signature: "H+", or "BD" (HFS wrapper) with "H+" as `drEmbedSigWord`
(byte 124). Not declared, unchanged: APFS, original HFS, HFSX ("HX"), a destroyed signature, a header
that does not read (research.md R1-R3).

## Implementation

- `src/common/salhfscatalog.h`: `SalHfsVolumeHeaderDeclaresHfsPlus(hdr, size)` - "H+" (size >= 2), or
  "BD" with "H+" at bytes 124-125 (size >= 126); everything else false.
- `src/plugins/uniso/hfs.h` / `hfs.cpp`: `CHFS::Declared` (FALSE in the constructor), set in `Open`
  right after the first volume header read returns (before the size check, from the bytes read). A
  wrapper whose embedded header then reads short or is not HFS+ stays declared.
- `src/plugins/uniso/udfiso.cpp` `CUDFISO::Open`: `hfsMissing = hfs->Declared` when `CHFS::Open` fails
  (read before `delete hfs`); `PartMissing = (HasISO && ISO == NULL) || hfsMissing` - 330's
  `ListDirectory` then marks `ListingLeftOut`. Quiet open unchanged; no message, no UI string (no
  `.slt` refresh needed).
- `src/saltests/saltests.cpp`: `TestHfsVolumeDeclared333` (18 checks: H+ v4 / v5, cut headers, NULL,
  HX, "+H", BD with / without / cut / other embedded signature, "H+" at 124 without BD, zeros, FAT,
  APFS, MBR).

## Checks (after)

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED (the C4267 warnings are existing lines of uniso, not this change) |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | `saltests: 28363 checks, 0 failed` (28,345 at 332 + 18 new) |
| probe | `iso333_probe.ps1` -> `probe/result_after.txt` | 14 PASS / 0 FAIL (H-VER, H-CAT, H-SIZE, H-EXT now keep the image; H-OK, H-NOSIG, APM-EFI deleted as before); registry restored, identical |
| regression | 322 / 329 / 330 / 332 probes -> `probe/regress_*.txt` | 18/0, 14/0, 30/0, 16/0 |
| encoding | `python tools/check_encoding.py --strict` | `TOTAL: 0 finding(s)` |

`result_before.txt` was taken with the probe's first version, which counted only the "#00000020" box
as known (APM-EFI failed on its "#00000200" box only); the probe now also ignores "#00000200" (an
Inbox item). The damaged rows do not depend on that change.

## Negative control (T008)

A mutant rule (`return true;` before the signature checks - every header declares HFS+), built into
the plug-in and saltests (`probe/result_mutant_declared_always.txt`): saltests 10 failed (HX, +H, BD
alone, BD cut, BD other, H+ at 124, zeros, FAT, APFS, MBR); probe rows H-NOSIG and APM-EFI FAIL (image
kept - every Ubuntu-style install image would never be deleted), H-OK PASS. The header was restored
from a copy (no `MUTANT` line left), rebuilt; saltests 0 failed and the probe 14 / 0 on that build.

## Inbox (INBOX = 2)

- `iso-plug-in-an-ubuntu-style-install-image-with-an-apple` - the "Cannot read sector #00000200." box
  of the APM install image (measure:333).
- `iso-plug-in-apfs-original-hfs-and-hfsx-parts-of-a-hybrid-are` - decision: mark APFS / original HFS
  / HFSX parts that are never listed (measure:333).

## Review

### Review 1 (refute-first agent, no MUST)

- Re-ran the probe on the branch build: 14 / 0. Own negative control (worktree of HEAD with `main`'s
  `udfiso.cpp`, only `uniso.spl` built and swapped into a copy of the build tree): 10 / 4 - exactly the
  4 damaged rows (image deleted). saltests 28,363 / 0; clang-format and BOMs clean; callers of `CHFS`
  enumerated (`CUDFISO::Open` changed, the HFS-only track unchanged; a false mark on a plain UDF + ISO
  image needs "H+" at byte 1024 and zeros at 0 - negligible); MDB offset 124 confirmed (packed struct).
- **SHOULD 1 (fixed)**: `CHFS::Open` walks every partition map entry before reading the volume
  header; a damaged entry it does not need ("Gap0": signature "PX", or its count 3 -> 4) returned before
  `Declared` was set - an intact HFS+ volume dropped unmarked, the image deleted, `side.txt` lost
  (reviewer's rows R-APMSIG / R-APMCNT FAIL on the pre-fix build:
  `probe/result_review1_apm_before_fix.txt`). Fix: `SalHfsApmEntryIsHfs` (pure, 9 saltests checks) and
  `CHFS::DeclaredBehindDamagedMap` on the three map-failure returns (an intact `Apple_HFS` entry in
  blocks 1-64 whose volume header declares HFS+ -> `Declared`). Spec clarification revised (it had kept
  this case unmarked), FR-001a added. Probe rows H-APMSIG / H-APMCNT (kept) and the control APM-EFI-CNT
  (the install image with its map refused: deleted - its `Apple_HFS` entry holds the EFI image) added:
  probe 20 / 0 (`probe/result_after.txt`); saltests 28,372 / 0; regressions 322 18/0, 329 14/0, 330
  30/0, 332 16/0 (re-run); encoding TOTAL: 0.
- NOTE 1 (the last `Apple_HFS` entry is taken; a real HFS+ entry followed by a non-HFS+ one is not
  marked; xorriso refuses such a map): recorded in the spec's edge cases as a limit, no item (no known
  image).
- NOTE 2 (the "BD" wrapper path only in saltests): no tool here writes an HFS wrapper image; recorded.
- NOTE 3 (no message when the image is kept): FR-003, as features 330 / 332.
- NOTE 4 (closing steps): done at closing.
- NOTE 5 (stale worktrees `rev325`, `rev328`, `rev330`, `rev332\neg` of earlier reviews): not this
  feature's; left as they are (a run deletes no worktree or branch).

### Review 2 (refute-first agent, previous findings given; no MUST, no SHOULD)

- Re-ran at f183c6c5: saltests 28,372 / 0, encoding TOTAL: 0, BOMs present, probe 20 / 0 (registry
  restored, identical).
- Adversarial images against `DeclaredBehindDamagedMap` (its own mutator and a probe copy, 21 PASS +
  1 expected): kept - first entry's signature broken, first entry's count 1, every count 9; deleted
  without a new box, hang or report - block size 0 / 0xFFFF / 512 with a damaged entry, an HFS start of
  0x7FFFFFFF / 0x80000000 / 300 (past the end); an image cut after the map takes the plain HFS track
  (its existing "Corrupted Partition Manager structures" box, image kept - not this feature's code).
- Negative control: `uniso.spl` built at 0f3b1bfe (before the review-1 fix) in a separate worktree and
  build folder - the three "kept" rows FAIL (image deleted, `side.txt` lost); H-OK passes.
- NOTE 1 (a damaged block 0 or a start past the end stays unmarked): recorded as an edge case in the
  spec (limit, as H-NOSIG). NOTE 2 (a volume header / map read cut by the end of the file returns before
  the scan): the image is cut inside its own HFS metadata, nothing more is lost. NOTE 3 (the scan also
  runs on the plain HFS track, where `Declared` is unused; on a DMG a start in the last 1 KiB could reach
  the existing "block undefined" pattern of `Open` itself): not new, left. NOTE 4: review 1's NOTEs.
