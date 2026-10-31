# Fix log - 356-uniso-udf-rest

Backlog item `iso-plug-in-a-udf-only-cooked-image-with-more-past-its`: a UDF-only cooked image with more
past its volume is still deleted by Unpack (leftover of feature 354).

## Measurement at 7afab447 (main, before)

### Reachability (code)

`CISOImage::Open` (`src/plugins/uniso/isoimage.cpp`), the plain branch (no track table): `CheckForISO`
accepts sector 16 when it is `\x01CD001` **or** `\x00BEA01`, so a UDF-only image sets `cookedIso`
(no sync at sector 0, 2048-byte sectors from offset 0). The 354 block reads sector 16, `iso9660 =
IsValidCDHeader(desc)` is false for `BEA01`, and `SalIsoCookedRestDecision` returns
`SAL_ISO_REST_KEEP_LISTING` at its first line - nothing past the UDF volume is ever looked at.
`DetectTrackFS` gives `fsUDF` (no `CD001` primary descriptor in sectors 16..128) and `CUDF::Open`
(`udf.cpp`) lists from the anchor at sector 256 (2048-byte blocks only) and the main descriptor sequence
it names; a virtual partition's VAT is looked for around the partition length, else at the end of the
track (= the file).

### Where a UDF volume ends - real images (`probe/udfmeasure.py`)

Seeds: Windows IMAPI2FS (`probe/imapiudf356.ps1`, `FileSystemsToCreate = 4` = UDF only) with `a.txt`;
mkudffs 2.3 from udftools (`probe/mkudf356.sh`; fetched into `~/tc-udftools` with `apt-get download`,
not installed - as 354 fetched xorriso).

| Image | Anchor at 256: MVDS / RVDS | Partition | Descriptors end | File (sectors) | Past the descriptors |
|---|---|---|---|---|---|
| IMAPI2FS UDF 1.02, 1.50, 2.00, 2.01 | 32+16 / 294+16 | 288+6 | 310 | 576 | 266 sectors, **every one an anchor** (tag 2, its own location, the same extents); anchors at N-1 and N-257 |
| IMAPI2FS UDF 2.50 | 32+16 / 448+16 | 288+160 | 464 | 736 | 272 anchors, the same |
| mkudffs hd (2048) | 96+16 / 1983+16 | 257+1720 | 1999 | 2000 | the anchor at N-1 |
| mkudffs dvd, cd | 96+16 / 3840+16 | 257+3480 | 3856 | 4000 | 144: zero bytes, anchors at N-257 and N-1 |
| mkudffs dvdrw | 96+16 / 3840+16 | 1296+2432 | 3856 | 4000 | 144: zero, the sparing table at 3984 (`*UDF Sparing Table`), anchors at N-257, N-1 |
| mkudffs cdrw (sparable) | 96+32 / 3840+32 | 1312+2400 | 3872 | 4000 | 128: zero, the sparing table at 3968, anchors at N-257, N-1 |
| mkudffs dvdr / bdr / cdr (VAT, open) | 96+16 / 240+16 (bdr 224+16) | 272+3728 / 288+3712 / 257+3743 | 4000 (more than the file) | 288 / 320 / 300 | - the last sector is the VAT: tag 266 (extended file entry), its location + partition start = N-1 |
| mkudffs cdr --closed (VAT) | 96+16 / 240+16 | 258+3742 | 4000 | 514 | the anchor at N-257 (= 257), the VAT at N-1 |
| mkudffs hd, 512-byte blocks | - (sector 256 is not an anchor) | | | 2000 | |

Conclusion: "the end" from the descriptors alone (anchor 256, MVDS, RVDS, partition) marks every plain
image - IMAPI2FS fills its rest with anchors, mkudffs puts its closing anchors and (dvdrw / cdrw) other
non-zero sectors past the reserve sequence, and open VAT images claim the whole medium. The rule
therefore takes the volume to end at the file's end when the file closes with this volume's own anchor
(at N-1 or N-257; same MVDS / RVDS extents as the anchor at 256 - a later volume's anchors name its own
sequences) or, for a VAT volume, with its own file entry at N-1; otherwise at the descriptors' end, with
354's limits, and a rest sector counts as empty when it is zero bytes only or this volume's anchor.
**Amended by review 1**: N-257 removed - only the file's last sector closes the volume (see *Review*).

### GUI (`probe/iso356_probe.ps1`)

First attempt (16:5x): `REFUSED: tandemcommander.exe already runs` - the maintainer's installed Tandem
Commander (`C:\Program Files\Tandem Commander`, started 16:47) runs; probes share its registry key and
are never run beside it, and a run never stops it (precedent 336, 345). Retried later (*Probes*).

## Decisions

See spec *Clarifications*.

## Implementation

- `src/common/salisotrack.h`: UDF parsers (`SalIsoUdfTagValid` - identifier, checksum, location;
  `SalIsoUdfReadAnchor` / `SalIsoUdfAnchorOf` - an anchor of the volume = the same four extent values as
  the anchor at 256; `SalIsoUdfExtentEnd`, `SalIsoUdfDescriptorsEnd`; `SalIsoUdfPartition`;
  `SalIsoUdfLvdHasVirtualMap` - the map table walked within the sector; `SalIsoUdfFileEntryAt` - tag 261 /
  266 at a partition-relative location), `SalIsoUdfVolume`, `SalIsoUdfRestDecision` (unknown anchor or
  partition → MARK; closed at the end → KEEP; else 354's `SalIsoCookedRestDecision` with the descriptors'
  end) and `SalIsoUdfRestSectorEmpty` (zero bytes, or a whole sector holding this volume's anchor).
- `src/plugins/uniso/isoimage.cpp` / `.h`: `CISOImage::UdfRestMarks(fileSize)` reads sector 256, at most
  64 sectors of the main sequence (stops at a short read or the terminating descriptor), the file's last
  whole sector (an anchor of the volume, or with a virtual map a file entry of the first partition) and the
  sector 256 before it (an anchor of the volume) - never the anchor at 256 itself (`whole > 257`,
  `last > 512`, so a joined file of 513 sectors cannot pass as closed by it) - and the rest sector by
  sector; `Open`'s `cookedIso` block calls it when `iso9660` is false and marks `ListingLeftOut`.
  **After review 1**: the sector 256 before the end is no longer read; the closing test is the pure
  `SalIsoUdfClosesFile` (last sector only, read whole, past sector 256).
- `src/saltests/saltests.cpp`: `TestIsoUdfRest_356` (68 checks; 80 after review 1).

## Checks

- `.\build.cmd` → BUILD SUCCEEDED (warnings only the old C4267 in hfs / xdvdfs / audio / udf / iso9660).
- saltests 29,402 → **29,470 checks, 0 failed**.
- Negative control (mutant: `SalIsoUdfRestDecision` returns KEEP_LISTING first): saltests **12 failed**
  (all MARK / CHECK rows of the decision); its `uniso.spl` kept as `%TEMP%\tcudf\spl\uniso_mutant.spl` for
  the probe. Header restored (`git checkout HEAD --`), rebuilt, 0 failed.
- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.

### Rule mirror over the images (`probe/rule356.py`, before the GUI run)

All IMAPI2FS (1.02, 1.50, 2.00, 2.01, 2.50) and mkudffs (hd, dvd, dvdrw, cdrw, cd, dvdr, bdr, cdr, cdr
closed) images: KEEP (closed at the end); mkudffs hd 512-byte blocks: MARK (no anchor at 256). Composed
(`img356.py` from IMAPI2FS u1 a.txt / u2 b.txt): plain, anchor600, zero100 (its anchor 256 before the end),
rest16, zero512, anchorrest (141 empty sectors: u1's anchors + one zero sector) KEEP; two, twoabs (842 past,
more than 512), rest17, short, noanchor, zero513, zerolate MARK; **zero300 MARK** - u1 + 300 zero sectors:
neither the last sector nor the one 256 before it is u1's anchor, 566 sectors past the descriptors (more
than are read) - a limit that fails closed, recorded as probe row R-ZERO300 and in the spec's
*Assumptions*. C-ZERO100 was first meant to exercise the "own anchors in the rest" path; the mirror showed
the closing anchor catches it, so C-ANCHORREST was added for that path.

### Probes

`before` = `uniso.spl` built from main's `isoimage.cpp` (the header with the new rule present but not
called - the plug-in behaves as main), saved as `%TEMP%\tcudf\spl\uniso_main.spl`; it is copied over the
build's `plugins\uniso\uniso.spl` for the before run and the fix's copied back afterwards.

The installed Tandem Commander closed at about 17:13; all probes ran after it, on the hidden desktop
(`tools\run_on_hidden_desktop.ps1`), registry restored and identical every time (SHA-256 07F63FE1...).

| Run | Result | Rows that failed |
|---|---|---|
| `result_before.txt` (main's `uniso.spl`) | **38 PASS / 10 FAIL** | R-TWO, R-TWOIMG, R-TWOABS (the defect: `a.txt` extracted, the image with `b.txt` **deleted**), R-REST17, R-ZERO300, R-ZERO513, R-ZEROLATE, R-SHORT, R-NOANCHOR (deleted); C-U250 (see below) |
| `result_after.txt` (the fix) | **48 PASS / 0 FAIL** | - |
| `result_mutant_never_marks.txt` (decision always KEEP) | **39 PASS / 9 FAIL** | the nine R rows |
| `regress_354.txt` (`iso354_probe.ps1` on the fix) | 28 / 0 | - |
| `regress_355.txt` (`iso355_probe.ps1` on the fix) | 40 / 0 | - |

- **C-U250 → N-U250.** On main the IMAPI2FS UDF 2.50 image does not list at all ("Cannot read sector
  #00000000.", "Error reading directory structure at sector #FF567539. Incomplete content of ISO
  image."; nothing extracted, the image kept) - a defect of the UDF reader outside this item (its
  logical volume descriptor at 34 precedes the partition descriptor at 35; the metadata partition map is
  resolved with `PD.Start` still 0). The row was turned into `N-U250` (unchanged: no file, only those
  read-error boxes, kept) and passes before and after; Inbox item
  `iso-plug-in-a-udf-2-50-image-written-by-windows-imapi2fs` (measure:356).
- R-MKHD512 (512-byte blocks) is kept already on main (no file listed, no window) and after.
- The C-MK rows (empty mkudffs volumes: nothing to extract) are deleted before and after - the plain
  images of every media type the rule must leave alone, VAT open and closed included.

## Review

### Review 1 (independent agent, refute-first)

- **MUST-1 (accepted, fixed)**: the "anchor 256 before the end" alternative of the closing test lost data.
  IMAPI2FS fills every sector past its reserve sequence with the volume's anchors, so 1 - 256 sectors of
  any data appended after an IMAPI2FS volume (and exactly 256 after a closed mkudffs volume) found an
  anchor of the volume at "last - 256" → closed → kept listing → the image deleted. The reviewer
  reproduced it on the branch's build with its own probe copy: R-JISO (u1 + an ISO 9660 image of b.txt)
  extracted `a.txt` and **deleted** the image, also R-JDATA100, R-JMKDVD256, R-JMKHD256 (8 / 4).
  Fix: `SalIsoUdfClosesFile` - only the file's last whole sector closes the volume; the N-257 read is
  gone from `UdfRestMarks`. No measured plain image needed it (each closes at its last sector: the
  closed VAT `cdr` by its VAT there). Rule mirror after the change over the 27 seeds and the
  reviewer's 9 joined images: every plain verdict unchanged; C-ZERO100 now kept through the read rest
  (366 empty sectors); all of the reviewer's joined images MARK.
- **SHOULD-1 (accepted, fixed)**: nothing tested how `ClosedAtEnd` is derived and C-ZERO100 (zeros)
  could never catch it. Now the pure `SalIsoUdfClosesFile` with 12 saltests checks (an anchor recorded
  elsewhere, 0x5A data, zero bytes, the anchor at 256, a later volume's anchor, a partial read, VAT with
  and without a virtual map, another partition start), and probe rows R-DATA100, R-JOINISO
  (`imapiudf356.ps1 -FileSystems 1` ISO 9660 image of b.txt joined after u1), R-MKDVD256, R-MKHD256 with
  non-zero data where "last - 256" is an anchor of the volume. One new check failed first: a partial read
  of the last sector counted as closing - `SalIsoUdfClosesFile` now requires a whole sector.
- **SHOULD-2 (accepted, fixed)**: the spec's table said mkudffs hd has anchors at N-1 and N-257; hd has
  only N-1 (fix-log measured right). Spec table corrected.
- NOTE-1 (VAT check loose: any file entry at the partition-relative location, the first partition's
  start, no check that it is the VAT): recorded, not changed - a joined image cannot match the
  partition-relative location; a crafted one can (as accepted for 353 - 355).
- NOTE-2 (a partial last sector past a closing... u1 + 1000 bytes is kept): within 354's accepted
  tolerance (whole sectors count; a partial sector holds no later volume).
- NOTE-3 (non-conforming images whose UDF signature is at 16 but whose listing comes from another file
  system): recorded only.

After the fix: build BUILD SUCCEEDED; saltests **29,482 checks, 0 failed**;
`result_before2.txt` (main's `uniso.spl`, the new rows) **43 / 13** (the 13 R rows deleted, N-U250
unchanged); `result_after2.txt` (the fix) **56 / 0**; regressions `regress_354.txt` 28 / 0,
`regress_355.txt` 40 / 0; encoding guard 0.
