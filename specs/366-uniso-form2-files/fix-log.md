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
