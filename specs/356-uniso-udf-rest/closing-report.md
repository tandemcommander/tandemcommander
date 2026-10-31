# Closing report - 356-uniso-udf-rest

Backlog item: iso-plug-in-a-udf-only-cooked-image-with-more-past-its - ISO plug-in: a UDF-only cooked image with more past its volume is still deleted by Unpack
Outcome: closed

## What changed

- `src/common/salisotrack.h`: UDF descriptor parsers (tag, anchor, partition, logical volume's virtual
  map, file entry), `SalIsoUdfClosesFile` (the file's last whole sector is this volume's anchor or, VAT,
  its VAT), `SalIsoUdfVolume`, `SalIsoUdfRestDecision` (unknown anchor / partition → mark; closed at the
  end → keep; a VAT volume not closed → mark; else 354's rule from the descriptors' end) and
  `SalIsoUdfRestSectorEmpty` (zero bytes or the volume's own anchor).
- `src/plugins/uniso/isoimage.cpp` / `.h`: `CISOImage::UdfRestMarks`, called from feature 354's
  `cookedIso` block when sector 16 holds no ISO 9660 primary descriptor; it marks `ListingLeftOut`, so a
  whole unpack fails and "Delete archive after unpacking" keeps the image.
- `src/saltests/saltests.cpp`: `TestIsoUdfRest_356` (86 checks).
- No UI string, dialog or message: no translation refresh.

## Measurements (before / after, commands)

- Where a UDF volume ends, measured on real tool output (`probe/udfmeasure.py`): IMAPI2FS UDF 1.02 -
  2.50 and mkudffs 2.3 (hd, dvd, dvdrw, cdrw, cd, VAT dvdr / bdr / cdr open and closed) - every plain
  image ends with its own closing anchor or VAT at its last sector; the descriptors alone end 128 - 272
  sectors earlier (fix-log *Where a UDF volume ends*).
- Probe `probe/iso356_probe.ps1` on the hidden desktop (`tools\run_on_hidden_desktop.ps1`), registry
  restored and identical every run:
  - main's `uniso.spl`: 38 / 10 (first 48 rows), 43 / 13 (all 56 rows) - R-TWO, R-TWOIMG, R-TWOABS,
    R-JOINISO, R-DATA100, R-MKDVD256, R-MKHD256, R-REST17, R-ZERO300, R-ZERO513, R-ZEROLATE, R-SHORT,
    R-NOANCHOR: `a.txt` extracted and the image **deleted** (the second volume's `b.txt` lost);
  - the fix: **56 / 0** (`result_after3.txt`).
- Rule mirror `probe/rule356.py` over 27 seeds and both reviewers' 16 images: every plain image KEEP,
  every image with data past the volume MARK (except 354's accepted 16-sector tolerance).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` → `TOTAL: 0 finding(s)`.
- `.\build.cmd` → BUILD SUCCEEDED (Debug x64).
- saltests 29,402 → **29,488 checks, 0 failed**; mutant (decision always keeps) 12 failed.
- Probes: 356 56 / 0; mutant `uniso.spl` 39 / 9 (the nine R rows of the first 48); regressions
  `iso354_probe` 28 / 0, `iso355_probe` 40 / 0.

## Reviews (findings and what was done)

- Review 1: MUST - the closing test also accepted the volume's anchor 256 sectors before the file's end;
  IMAPI2FS fills its rest with such anchors, so 1 - 256 sectors of data appended after it (exactly 256
  after a closed mkudffs volume) kept the listing and the image was deleted (reproduced on the branch
  build). Fixed: only the last sector closes (`SalIsoUdfClosesFile`, whole-sector read). SHOULDs fixed
  (tests of the closing test, probe rows with data appended; a spec table error). NOTEs recorded.
- Review 2: no MUST; MUST-1 verified gone. SHOULD - a VAT volume not closed by its VAT used the claimed
  medium size as its end: fixed (marked). SHOULD - such an image crashes the UDF reader (on main too):
  Inbox. NOTEs written into the spec's assumptions.
- Details: `fix-log.md`, *Review*.

## Owed to a person (with the new person-step items)

- `check-feature-356-with-real-udf-only-disc-images-blu-ray-dvd`: check with a real UDF-only image
  (Blu-ray / UDF DVD / closed packet-written disc) and two joined.
- The CHANGELOG entry below. `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's), so it is not added there.

CHANGELOG entry (for the next release's section):

- **Unpack could delete a UDF-only disc image together with a second image or other data stored after it** (feature 356).
  - **Before:** a disc image with only a UDF file system (as Windows writes images, as Blu-ray discs are made) showed only the files of its first volume. When the file held another image or other data after that volume, a whole Unpack (Alt+F9) with "Delete archive after unpacking" deleted the image, and the data after the volume was lost.
  - **Now:** a whole Unpack extracts what is listed and keeps the image when data lies past the UDF volume, or when where the volume ends cannot be read. A plain UDF image - one that ends where its volume ends, as Windows' image writer, mkudffs and disc authoring tools write them - unpacks and is deleted as before.
  - **Limitation:**
    - No message says why the image was kept.
    - A UDF image followed by many empty sectors, and UDF images with blocks smaller than 2048 bytes, are now kept too.
    - Up to 16 sectors after the volume are still not checked.
    - Checked with images written by Windows and by mkudffs, not with a real Blu-ray disc image.

## New Inbox items (slug - title)

- `iso-plug-in-a-udf-2-50-image-written-by-windows-imapi2fs` - ISO plug-in: a UDF 2.50 image written by
  Windows (IMAPI2FS) does not list (measure:356)
- `iso-plug-in-a-udf-image-with-a-vat-and-data-past-it-crashes` - ISO plug-in: a UDF image with a VAT and
  data past it crashes Tandem Commander (review:356)
- `check-feature-356-with-real-udf-only-disc-images-blu-ray-dvd` - Check feature 356 with real UDF-only
  disc images (Blu-ray, DVD, packet-written CD-R) (person step)
