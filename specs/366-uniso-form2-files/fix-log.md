# Fix log - 366-uniso-form2-files

Backlog item `iso-plug-in-video-cd-mpeg-files-in-form-2-sectors-may` - ISO plug-in: Video CD MPEG files in
Form 2 sectors may extract cut to 2048 bytes a sector.

## Measurement before (main 308896b0)

- `build.cmd` (Debug x64) - BUILD SUCCEEDED.
- Real images: 335 reviewer 3's vcdimager 2.0.1 output was still in WSL `~/rev335c` (`vcd.bin`, `svcd.bin`,
  `v.mpg`, `s.mpg`); copied to `%TEMP%\rev335c\data`, images made with
  `python -I specs/335-uniso-raw-track-lost/probe/review3/gen335c.py <data> <dummy s1.iso> %TEMP%\rev335c\imgs`
  (`real_vcd.img/.ccd`, `real_svcd.img/.ccd`, `real_vcd.nrg` - 2336-byte ETNF sectors; X-SHORT's dummy s1 unused).
- Probe (hidden desktop): `rev335c_probe.ps1 -ImgDir %TEMP%\rev335c\imgs -Lib specs\098-long-path-overruns\probe\fix_probe_lib.ps1
  -Label before-366 -Only R-VCD-CCD,R-SVCD-CCD,R-VCD-NRG` -> `probe/result_before_realvcd.txt` PASS 6 (the probe
  checks sizes and the image's fate only): AVSEQ01.DAT / AVSEQ02.DAT 608,256 bytes (CCD, NRG), SVCD AVSEQ01.MPG
  292,864 bytes; the image deleted in all three. Registry restored, identical.
- Content (`probe/vcdscan.py`, a session script reading the raw `.bin`'s ISO 9660 records):
  - `MPEGAV/AVSEQ01.DAT;1` extent 450, DataLength 608,256 (297 x 2048), XA system-use record
    `00000000 1555 5841 01 0000000000` - attributes 0x1555: Form 2 bit 0x1000, no Form 1 bit; 297 of 297 sectors
    Form 2 by subheader. `VCD/INFO.VCD`, `VCD/ENTRIES.VCD`: 0x0D55 (Form 1). Folders: 0x8D55.
  - the extracted files (kept by the probe in `%TEMP%\rev335c\keep\<row>`) equal the 2048-byte read of the
    sectors: `== 2048-read: True; == 2324-read: False` for R-VCD-CCD, R-VCD-NRG, R-SVCD-CCD.
  - `v.mpg` (515,928 = 222 x 2324) is not in the 2048-byte read; it is whole in the 2324-byte read (690,228
    bytes) at offset 69,720, everything else in it zero bytes. SVCD: 143 x 2324 = 332,332 = `s.mpg` at offset 0.
- Conclusion: the defect is real and reachable (whole Unpack, default configuration, uniso on); 61,272 bytes
  of the VCD's AVSEQ01 video lost, 39,468 of the SVCD's; the image then deleted.

## Sites (enumerated)

- Readers of a file's content: `CISO9660::UnpackFile` (iso9660.cpp - a file inside an ISO 9660 track),
  `CRawFS::UnpackFile` (rawfs.cpp - a file whose extent is in a track without a file system: a Video CD's
  MPEG track). Both reached through `CISOImage::UnpackFile` (isoimage.cpp), which opens the file's track
  (`GetTrackFromExtent`, `OpenTrack` -> `SetTrackParams`) - callers `uniso.cpp` UnpackArchive (whole / selection)
  and UnpackOneFile (viewer, F3). `CUDFISO::UnpackFile` dispatches ISO 9660 entries to `CISO9660::UnpackFile`.
- Listed size: `CISO9660::AddFileDir` (`fd.Size = dr.DataLength`), called from `ListDirectoryRe` for files
  (the raw record is at hand there) and `AddBootRecord` (a virtual record, no XA).
- Users of a listed ISO 9660 file's size as sectors: `CISOImage::NoteListedFileStarts` ->
  `SalIsoFileSectorSpan` (floor(size / 2048), feature 337); `SalIsoFileStartTrack` (size 0 only).
- `CISOImage::ReadBlock` reads `SectorUserSize` (2048) a sector at `GetSectorOffset(block)` = track start +
  block x stored sector size + header size. Mode 2 tracks: header 24 (2352) / 8 (2336) - the same place the
  Form 2 user data starts (after the subheader); `GetHeaderSizeFromMode` gives Mode 2 / 2448 a header of 16
  (not the Form 2 position) - such tracks stay unchanged.

## Analyze

- Run 1: 0 CRITICAL, 0 HIGH. MEDIUM C1 (no row for a Form 2 file past the image's end) - fixed: T012 adds a cut
  image row. MEDIUM C2 (only a whole Unpack is driven) - accepted: one file, a selection and F3 (UnpackOneFile)
  reach the same `CISOImage::UnpackFile` -> file system `UnpackFile` (callers enumerated in *Sites*); the
  listed size is the same object. LOW L1 (2448/16 layout only in saltests) - accepted.

## Implementation

- `src/common/salisotrack.h`: `SalIsoXaAttributes` (the CD-XA record of a raw directory record: system-use
  area at 33 + identifier length, padded even; whole record within the record's and the given length;
  signature "XA" at 6..7), `SalIsoXaIsForm2File` (0x1000 set, 0x0800 and 0x8000 clear), `SalIsoTrackStoresForm2`
  (`SalIsoForm2PayloadOffset(raw) == header`, the 2324 bytes within the stored sector), `SalIsoForm2FileSize`
  (ceil(len / 2048) x 2324); `SalIsoFileSectorSpan` takes the bytes a sector (default 2048).
- `isoimage.h/.cpp`: `CFilePos::Form2` (constructor FALSE); `CISOImage::FileIsForm2(extent)` - the extent's track
  (`GetTrackFromExtent`, the unpack's own rule), `SalIsoTrackStoresForm2` of its record, its first stored sector's
  first 24 bytes through `SalIsoSectorIsForm2`; `CISOImage::ReadForm2Block(block, data)` - 2324 bytes at
  `GetSectorOffset(block)` of the open track, 0 when the open track does not store Form 2 there or the read is
  short; `NoteListedFileStarts` passes 2324 for a Form 2 file to `SalIsoFileSectorSpan`.
- `iso9660.h/.cpp`: `ListDirectoryRe` reads the file record's XA attributes; `AddFileDir(..., xaForm2)` sets
  `Form2` and the size for a file `FileIsForm2` confirms (not in the fit-check pass; zero-byte records stay 0);
  `UnpackFile` reads a Form 2 file with `ReadForm2Block`.
- `rawfs.cpp`: `CRawFS::UnpackFile` the same (a Video CD's video lies in the MPEG tracks, which have no file system).

## Checks

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED (only the pre-existing C4267 warnings of uniso) |
| saltests | `saltests.exe` | 29,893 -> 29,942 checks, 0 failed (`TestIsoXaForm2_366`, 49 checks) |
| mutants | `%TEMP%\tc366work\mutants.ps1` (each rule changed in the header, built, saltests, restored) | Form 1 bit ignored 2 failed; header check dropped 4; size rounded down 3; span always 2048 3; XA pad ignored 2 - every mutant fails |
| encoding guard | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |
| clang-format | VS's clang-format on each changed file, diff | the new code formats unchanged (the files' other differences are main's: same counts) - four comment alignments in the tests fixed |
| probe after | `iso366_probe.ps1 -ImgDir %TEMP%\tc366img -Label after` (images `img366.py`) | `probe/result_after.txt` PASS 20, FAIL 0 (10 rows); registry restored + identical |
| negative control | the same probe with main's `uniso.spl` (built from a worktree of main into `%TEMP%\tc366negbuild`, copied into a copy of the Debug tree) | `probe/result_negative_main.txt` PASS 11, FAIL 9: every row with a Form 2 video file fails with the 2048-byte cut (608,256 / 292,864 bytes, SHA-256 of the 2048-byte read); C-COOKED passes on both; the control files of C-MIXED / C-NOXA / C-F1SUB and every image's fate are the same as on the feature build |

Probe rows (feature build): R-VCD-CCD, R-VCD-NRG - AVSEQ01/02.DAT 690,228 bytes = the 2324-byte user data of
their 297 sectors, `v.mpg` whole in AVSEQ01, the image deleted; R-SVCD-CCD - AVSEQ01.MPG 332,332 bytes = `s.mpg`,
deleted; R-VCD-BIN (the plain detection, the ISO 9660 reader's path) - the same content (the image kept, as on
main: the plain detection's rest rules); C-MIXED (0x3D55), C-NOXA (signature destroyed), C-F1SUB (Form 1 first
sector) - that file 608,256 bytes = main's, the other video file whole; C-COOKED - every file as on main;
C-CUT - AVSEQ02 read error at sector 0x122 (290 of 297 - the image ends there), Skip, the file not left, the
image kept; C-SHORT240 - AVSEQ01's record shortened to 240 sectors: 557,760 bytes, the image kept (the 12
video sectors after it are not read - US3).

- First probe run: C-CUT FAIL only because the probe closed the read-error box (Cancel - its Skip button, id 173,
  was not among the answers), which cancelled the whole unpack before VCD/*; the row now answers Skip
  (`-Answer @(1, 6, 173)`); the product behaved the same in both runs.
| regressions | `%TEMP%\tc366work\regress.ps1`: 337's, 365's, 334's probes on the feature build | `probe/regress_337.txt` 74 / 0 (with 336's and 335's rows; real-VCD-like stream rows unchanged), `regress_365.txt` 22 / 0, `regress_334.txt` 23 / 1 (S-RAW - 335's intended change, as recorded since 335); registries restored + identical |
| after the test-comment alignment | `.\build.cmd`, `saltests.exe` | BUILD SUCCEEDED; 29,942 / 0 |

The mutant script is kept as `probe/mutants366.ps1`.

## Review

Review 1 (independent agent, refute-first): **no MUST**. It re-ran saltests (29,942 / 0), the encoding guard
and the probe (20 / 0 on the feature build, its own image folder), checked the negative control's
`uniso.spl` (main's SHA differs), built a mutant where `NoteListedFileStarts` always counts 2048 (C-SHORT240
then deletes the image - the probe tests US3's call site), and enumerated the users of the listed size
(`AddFileDir`, both `UnpackFile`, `NoteListedFileStarts`, the progress totals in `uniso.cpp` / `isoimage.cpp`,
`SalIsoFileStartTrack`).
- SHOULD-1: a file in Form 2 sectors the rule does not recognise (no XA record, mixed 0x3D55, Form 1 first
  sector) still extracts cut and the image is deleted (rows C-NOXA / C-MIXED / C-F1SUB), as on main - the
  item's alternative "subheaders" criterion, not implemented (spec *Assumptions*), and the interim
  keep-or-delete question is the maintainer's open decision `keep-video-cd-images-after-a-whole-unpack-until-their-video`
  -> Inbox `iso-plug-in-a-video-file-in-form-2-sectors-without-an-xa` (review:366), related to the decision.
- NOTE 1: the real VCD's AVSEQ01 and AVSEQ02 are byte-identical - a wrong-track read of the second would pass.
  Taken: rows D-DIFF2-CCD / D-DIFF2-NRG (AVSEQ02's user data altered in every sector, also past byte 2048) in
  `img366.py` / `iso366_probe.ps1`; probe `probe/result_after_review1.txt` **24 PASS / 0 FAIL**.
- NOTE 2: F3 / single-file extract, the 2448/24 `.mdf` layout and NRG 2352 not driven - the same code by
  reading (recorded; the person step covers real dumps).
- NOTE 3: a Form 2 record whose length is the real byte count (not sectors x 2048) would read ~13 % past the
  file - CD-XA and vcdimager use sectors x 2048; accepted.
- NOTE 4: a Form 2 file with a Form 2 first sector but later Form 1 sectors gets their ECC bytes - crafted
  images only; accepted (the per-sector decision is the Inbox item's).
- NOTE 5: CHANGELOG / FEATURE-HISTORY owed at closing - done in the closing commit (no `## [Unreleased]`
  section: the entry is in `closing-report.md`).
No fresh review: no MUST; the change after it is two probe rows.
