# Closing report - 367-uniso-form2-unmarked
Backlog item: iso-plug-in-a-video-file-in-form-2-sectors-without-an-xa - ISO plug-in: a video file in Form 2 sectors without an XA Form 2 attribute extracts cut
Outcome: closed

## What changed

- A file stored in Form 2 sectors that feature 366 did not recognise (no CD-XA record, mixed attributes 0x3D55,
  a Form 1 first sector) is examined at listing when its track stores Form 2 data and it starts in a Form 2
  stream track, has the XA Form 2 bit, or has a Form 2 first sector. Each sector's subheader decides what is read:
  2324 bytes of a Form 2 sector, 2048 of any other; the listed size is the sum (all Form 2 = 366's size).
- Both readers (`CISO9660::UnpackFile`, `CRawFS::UnpackFile`) read such a mixed file sector by sector
  (`CISOImage::ReadMixedBlock`).
- Feature 337's stream coverage counts only the leading run of sectors read whole: a Form 2 sector, or a Form 1
  sector whose EDC checks (or whose last 276 bytes are empty) and that the record does not end inside; an unknown
  or unsure sector stops it - the gap check then reads the rest and keeps the image when data would be left.
- Rules in `src/common/salisotrack.h` (`SalIsoSectorForm`, `SalIsoFileNeedsSectorScan`, `SalIsoSectorScan*`,
  `SalIsoCdEdc`, `SalIsoForm1SectorWhole`); `CFilePos` gets `Form2 = FORM2_MIXED`, `Scanned`, `WholeSectors`.
- No UI string, dialog or option; no plug-in interface change.

## Measurements (before / after, commands)

- Before (main 56a44fba): `iso366_probe.ps1 -Only C-MIXED,C-NOXA,C-F1SUB` on the hidden desktop - the video file
  extracted as 608,256 bytes (the 2048-byte read of 297 sectors) and the image deleted in all three.
- After: `probe/iso367_probe.ps1` (images `probe/img367.py` from the real vcdimager 2.0.1 output) - C-MIXED,
  C-NOXA, C-NOXA-NRG and the raw .bin variants extract AVSEQ01.DAT as 690,228 bytes with `v.mpg` whole; C-F1SUB
  689,952 bytes (2048 + 296 x 2324); the images deleted as for a real Video CD (every stream extracted whole);
  damaged / mislabelled / part-read sectors (C-BADSUB, C-F1MID, C-LASTF1) keep the image.

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict`: TOTAL: 0 finding(s).
- `.\build.cmd`: BUILD SUCCEEDED (no `full` needed: no UI string, resource or language file changed).
- saltests: main 29,916 -> 29,999 checks, 0 failed (`TestIsoSectorScan_367`); 11 mutants of the rules each fail
  1 to 5 checks (`probe/mutants367.ps1`).
- Probe `iso367_probe`: 40 / 0 (`probe/result_after_review1.txt`; 36 / 0 before review 1's rows); negative control
  with main's `uniso.spl` 27 / 9 - exactly the nine 367 rows fail (`probe/result_negative_main.txt`).
- Regressions: 337's rows with 367's expectations 74 / 0 and folders off 8 / 0 (`regress_337_r367*.txt`; 337's own
  probe 54 / 20 - its synthetic stream files are such files, now read 2324 bytes a sector, S-VCDBYTE's file read
  whole and its image deleted - recorded in the fix-log), 365 22 / 0, 334 23 / 1 (S-RAW, 335's intended change).
- clang-format of the changed lines: clean.

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST. SHOULD-1 (a Form 1 subheader counted as read whole without looking at its
  last 276 bytes - a relabelled sector let the image be deleted) - fixed with the EDC / empty-rest rule, tests,
  mutants and probe rows C-F1MID / C-F1EDC. NOTE 1 (listing cost) -> Inbox. NOTE 2 (a damaged-subheader sector
  is still read 2048 bytes without a message in a plain Unpack) - a stated limit. NOTE 3 (probe expectations
  computed by the same rule; the `v.mpg` check and the negative control are the independent evidence) - accepted.
  No fresh review (no MUST).

## Owed to a person (with the new person-step items)

- Add the CHANGELOG entry below (CHANGELOG.md has no `## [Unreleased]` section):

```text
- **Video files in Form 2 sectors without the disc's Form 2 mark were extracted cut** (feature 367).
  - **Before:** a Video CD-like disc image whose video file was stored in Mode 2 Form 2 sectors but not marked
    as such in its directory record (no CD-XA record, mixed Form 1 + Form 2 attributes, or a Form 1 first
    sector) extracted that file with only 2048 of every 2324 bytes of each sector, without a message, and
    "Delete archive after unpacking" then deleted the image that held the full video.
  - **Now:** each sector of such a file is read as its own header says - 2324 bytes of a Form 2 sector, 2048
    of a Form 1 sector - and the file is listed with that size; the image is deleted only when every stream
    was extracted whole.
  - **Limits:** a sector whose header is damaged is read with 2048 bytes (the image is then kept when
    "Delete archive after unpacking" is on); such files are read in full each time the image is listed.
```

- The decision `keep-video-cd-images-after-a-whole-unpack-until-their-video` is now answered by its option C (the
  cut is fixed for the files 366 and 367 cover) - the maintainer may close it.
- No person-step item: the change was measured on real vcdimager output; 366's person step
  `check-feature-366-with-a-real-video-cd-dump-the-extracted` still covers a physical-disc dump.

## New Inbox items (slug - title)

- iso-plug-in-listing-a-disc-image-reads-every-sector-of - ISO plug-in: listing a disc image reads every sector of examined Form 2 files
