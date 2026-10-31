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

### GUI (`probe/iso356_probe.ps1`)

First attempt (16:5x): `REFUSED: tandemcommander.exe already runs` - the maintainer's installed Tandem
Commander (`C:\Program Files\Tandem Commander`, started 16:47) runs; probes share its registry key and
are never run beside it, and a run never stops it (precedent 336, 345). Retried later (*Probes*).

## Decisions

See spec *Clarifications*.
