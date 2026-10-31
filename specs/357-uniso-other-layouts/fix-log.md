# Fix log - 357-uniso-other-layouts

Backlog item `iso-plug-in-a-multi-session-image-opened-through-another` (source review:355).

## Measurement before (main 8bf3ebd4)

- `.\build.cmd` - Debug x64 up to date (6 s).
- Seeds: 334's `mkimg334.sh` in WSL Ubuntu (genisoimage): s1.iso (a.txt "A1", 176 sectors, PVD size 176),
  s2.iso (b.txt "B2", addressed from sector 176).
- `probe/img357.py` (new, based on 355's `img355.py`) writes s1 / s1 + s2 / tails in ten layouts the plain
  detection reaches without the sync pattern at offset 0: ECDC (2352, sync and header zero, user data at 24), NRG
  offset 0x4B000, 2336 (subheader 8), NCD 0x16E4E, PDI 0x130, CIF (44-byte RIFF prefix, 2056-byte sectors), C2D
  0x20000, C2D 0x76220 Mode 2, Roxio 0x120, CIF 2332. It mirrors `CISOImage::Open`'s order of checks and refuses
  an image that an earlier check would open through another layout.
  - Finding: a Roxio image shorter than 0x7F53E bytes never opens (`CheckForC2D` returns FALSE when it cannot read
    0x7F538, before the Roxio check) - an older limit, nothing extracted or deleted; Roxio's one-session row is a
    zero-tail image of 326 sectors instead (C-ROXIO-ZERO150).
- Probe `probe/iso357_probe.ps1` (hidden desktop, Alt+F9 whole unpack, "Delete archive after unpacking"):
  `probe/result_before.txt` - **44 PASS / 16 FAIL**: R-<L>-TWO for all ten layouts (R-ECDC-TWO = the reviewer's
  X-ECDCTWO) and R-ECDC/NRG-REST17, -ZERO513, -SHORT extracted a.txt and DELETED the image; the 14 C rows
  (one-session, 16 sectors of data, 150 zero sectors) deleted as expected. Registry restored and identical.
- Reachability: the plain branch of `CISOImage::Open` (no `.cue` / `.ccd` / Nero footer) -> listing of the volume
  at the layout's sector 16; a whole unpack with the option deletes the image unless `ListingLeftOut` is marked
  (328 / 338). 355's block runs only for `rawStart && !CcdMissing`; 354's for `cookedIso`; 353's for
  `CcdMissing && rawStart` - none for these layouts.

## Decisions

- Covered: NRG offset, 2336, NCD, PDI, ECDC, CIF, C2D (all three), CIF 2332 without a raw start. Not covered:
  Xbox (XDVDFS, no ISO 9660 descriptor at sector 16 - 355's rule would mark every Xbox image), HFS, APFS (no CD
  sessions), MDF (needs the sync: always a raw start, already 355). (item *Notes*: measure which layouts can carry
  a later session)
- Rule: 355's `SalIsoRawRestDecision` and block unchanged, at the opened layout (item *Expected*).
- A UDF-only volume at the NRG offset: marked (size unknown - fails closed, as 355).
- analyze: MEDIUM C1 (Xbox / HFS / APFS unchanged shown by unit checks only - no crafted image) and LOW C2 (no
  task for "no UI string") accepted.

## Implementation

- `src/common/salisotrack.h`: enum `SAL_ISO_PLAIN_*` (the checks of the plain detection, in their order) and
  `SalIsoPlainRawRuleApplies(rawStart, ccdMissing, layout)` - a raw start as 355 (unless the `.ccd` is missing);
  without one, true for NRG, 2336, NCD, PDI, ECDC, CIF, C2D, CIF 2332.
- `src/plugins/uniso/isoimage.cpp`, `CISOImage::Open` plain branch: `plainLayout` set in each branch of the
  detection chain; 355's block runs when `SalIsoPlainRawRuleApplies(rawStart != FALSE, CcdMissing != FALSE,
  plainLayout)` (was `rawStart && !CcdMissing`). For a raw start the condition is the same as before for every
  layout; the block's body (355's rule, user data at `DataOffset + n * SectorRawSize + SectorHeaderSize`) is
  unchanged.
- `src/saltests/saltests.cpp`: `TestIsoPlainLayouts_357` (65 checks).

## Measurement after

- `.\build.cmd` -> BUILD SUCCEEDED (only the older C4267 warnings of other uniso files).
- saltests 29,488 -> 29,553 checks, 0 failed. Mutant (the eight layouts return false without a raw start - the
  code of main): 16 failed; restored: 0 failed.
- `probe/result_after.txt`: **60 PASS / 0 FAIL** (before 44 / 16): every R row keeps the image, every C row
  deletes it, no window, registry restored and identical. The before run on main's `uniso.spl` is the
  never-applies mutant of the plug-in edit (main's condition = the rule with `false` for every layout without a
  raw start): 44 / 16.
- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s). clang-format on the changed lines: one
  alignment of the test arrays fixed.
- Regressions (hidden desktop, this build): `probe/regress_353.txt` 16 / 0, `regress_354.txt` 28 / 0,
  `regress_355.txt` 40 / 0, `regress_356.txt` 56 / 0 - as those features recorded; registry restored and
  identical each time.
