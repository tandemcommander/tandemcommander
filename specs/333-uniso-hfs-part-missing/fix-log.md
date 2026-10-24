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
