# Closing report - 366-uniso-form2-files
Backlog item: iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may - ISO plug-in: Video CD MPEG files in Form 2 sectors may extract cut to 2048 bytes a sector
Outcome: closed

## What changed

- A file whose ISO 9660 record carries a CD-XA attribute Form 2 (not Form 1, not a folder), on a track that
  stores the 2324-byte Form 2 user data where the plug-in reads user data, and whose first sector is a Form 2
  sector, is listed with sectors x 2324 bytes and extracted 2324 bytes a sector (`CISO9660::UnpackFile`,
  `CRawFS::UnpackFile` through the new `CISOImage::ReadForm2Block`; `CISOImage::FileIsForm2`; `CFilePos::Form2`).
- Feature 337's stream coverage counts such a file's sectors by 2324 (`SalIsoFileSectorSpan` bytes-a-sector).
- Rules in `src/common/salisotrack.h`: `SalIsoXaAttributes`, `SalIsoXaIsForm2File`, `SalIsoTrackStoresForm2`,
  `SalIsoForm2FileSize`; tests `TestIsoXaForm2_366`.
- No UI string, dialog, setting, plug-in interface or stored data changed (no `.slt` refresh).

### CHANGELOG entry (no `## [Unreleased]` section in CHANGELOG.md - for the maintainer to add)

```text
- **Video CD and SVCD video files extracted from a disc image were cut** (feature 366).
  - **Before:** the video files of a Video CD / SVCD image (`MPEGAV/AVSEQnn.DAT`, `MPEG2/AVSEQnn.MPG`) were
    extracted with only 2048 of every 2324 bytes of each sector - about 12 % of the video lost without a
    message - and "Delete archive after unpacking" then deleted the image that held the full video.
  - **Now:** files the disc marks as Mode 2 Form 2 are listed and extracted with all 2324 bytes of every
    sector: an SVCD's video file equals the MPEG it was made from, a Video CD's holds it whole between the
    disc's empty margins.
  - **Limitation:** a file stored in Form 2 sectors without that mark (a damaged or unusual directory entry)
    is still extracted as before; an `.iso` made of a Video CD holds only 2048 bytes a sector.
```

## Measurements (before / after, commands)

- Before (main 308896b0): `rev335c_probe.ps1 -Only R-VCD-CCD,R-SVCD-CCD,R-VCD-NRG` -> AVSEQ01.DAT 608,256 bytes
  (CCD, NRG), AVSEQ01.MPG 292,864, image deleted; `probe/vcdscan.py`: the extracted files equal the 2048-byte
  read; `v.mpg` only in the 2324-byte read (`probe/result_before_realvcd.txt`).
- After: `iso366_probe.ps1` (images `img366.py`): AVSEQ01/02.DAT 690,228 bytes = the 2324-byte read, `v.mpg`
  whole; AVSEQ01.MPG 332,332 = `s.mpg`; Form 1 files and the control rows as on main
  (`probe/result_after.txt` 20 / 0, `probe/result_after_review1.txt` 24 / 0).
- Negative control: main's `uniso.spl` in a copy of the Debug tree -> 11 / 9 (`probe/result_negative_main.txt`).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> TOTAL: 0 finding(s).
- `.\build.cmd` -> BUILD SUCCEEDED.
- saltests 29,893 -> 29,942 checks, 0 failed; five rule mutants fail 2-4 checks each (`probe/mutants366.ps1`).
- Probe `iso366_probe` 24 / 0; regressions 337 74 / 0, 365 22 / 0, 334 23 / 1 (S-RAW, 335's intended change).

## Reviews (findings and what was done)

- Review 1: no MUST. SHOULD-1 (files in Form 2 sectors without the XA Form 2 attribute still cut, image deleted,
  as on main) -> Inbox item. NOTE 1 (identical real video files) -> rows D-DIFF2-CCD / D-DIFF2-NRG added. NOTEs
  2-4 recorded and accepted; NOTE 5 done at closing.

## Owed to a person (with the new person-step items)

- `check-feature-366-with-a-real-video-cd-dump-the-extracted` - play a video file extracted from a real Video CD
  / SVCD dump.
- Add the CHANGELOG entry above (no `## [Unreleased]` section exists).
- The decision `keep-video-cd-images-after-a-whole-unpack-until-their-video`: its option C ("fix the cut first")
  is done for files with an XA Form 2 attribute; what remains is only the files of the new Inbox item.

## New Inbox items (slug - title)

- `iso-plug-in-a-video-file-in-form-2-sectors-without-an-xa` - ISO plug-in: a video file in Form 2 sectors
  without an XA Form 2 attribute extracts cut
- `check-feature-366-with-a-real-video-cd-dump-the-extracted` - Check feature 366 with a real Video CD dump: the
  extracted video plays whole
