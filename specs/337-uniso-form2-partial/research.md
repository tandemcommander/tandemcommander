# Research - 337-uniso-form2-partial

## R1 What does a real Video CD leave uncovered?

- Decision: the coverage rule looks at the content of the uncovered sectors, not only their count.
- Measured (vcdimager 2.0.1 images of feature 335's reviewer 3, `%TEMP%\rev335c\imgs`; ISO 9660 records
  dumped with a Python script, raw sectors summarised): real_vcd track 2 = sectors 450..896, AVSEQ01.DAT
  450..746 (297 sectors, 608,256 bytes); track 3 = 897..1343, AVSEQ02.DAT 897..1193; real_svcd track 2 =
  450..742, AVSEQ01.MPG 450..592. Each file starts at its track's first sector; 150 sectors after it are
  uncovered (the next track's pregap 747..896 by vcd.cue's INDEX 00 at 00:09:72; the post-gap before the
  lead-out). Every uncovered sector: Mode 2, subheader `00 00 20 00` twice, 2324 zero user bytes. The
  files' margins (30 front / 45 rear sectors) are zero as well.
- Rationale: 336's probe rows hold 64-sector streams with data in every sector; S-VCDPART leaves 63 of
  them uncovered, a real VCD 150 empty ones - no count separates them, the content does.
- Alternatives: a fixed count tolerance (150 or 300) - would still delete S-VCDPART and S-VCDCOV
  (rejected); a fraction of the track - arbitrary, fails for short streams (rejected); requiring zero
  uncovered sectors - keeps every real VCD (breaks *Expected*, rejected).

## R2 Bound on the read

- Decision: at most 300 uncovered sectors (`SAL_ISO_STREAM_GAP_SECTORS`); more mark the listing without
  reading. 300 = a 150-sector pregap and a 150-sector post-gap (2 s each, the CD standard gaps).
- Rationale: bounds the listing's extra I/O to < 1 MB per stream track; a crafted directory with a tiny
  file in a huge stream is decided without reading it.

## R3 Which sectors a file covers

- Decision: the unpack's rule: `CISOImage::UnpackFile` picks the track by `GetTrackFromExtent`
  (`SalIsoTrackOfExtent`), `CRawFS::UnpackFile` reads `ceil(size / 2048)` blocks from `fp->Extent -
  ExtentOffset`; block *i* is stored at `Start + i * SectorSize`. A file covers track-relative sectors
  `[extent - ExtentOffset, + ceil(size / 2048))` clipped to `[0, trackSectors)`; nothing when its extent
  lies before the track's first sector (the unpack's block number would wrap) or at/after its end. 336's
  guards stay (size > 0, ISO 9660 disc address, track <= 255) - one function decides the start track for
  both rules.

## R4 The track's extent

- Decision: `trackSectors = (e - Start) / SectorSize` with `e = End` when `End > Start`, else the image
  file's size; then `e = nextStart` when the next track starts later in the file; `e` never past the
  image file. Whole sectors only (a partial stored sector cannot be read whole).
- Rationale: a wrong end that is too large only adds sectors to check (and the read past the file is cut
  at the file); too small is extended by the next track's start (in DAO NRG the bytes between `End` and
  the next `Start` are the next track's pregap - empty on real discs, within the bound); unknown (`End <=
  Start`) is the image's end. The last track with a too-small end is not detectable - a limit, the
  track-table readers are Inbox `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables`.

## R5 Empty sector

- Decision: the 2324 bytes after the 8-byte subheader (offset 24 in a raw >= 2352-byte sector, 8 in a
  2336-byte one) are all zero, read whole. Subheader, EDC/ECC and subchannel bytes are not looked at.
- Rationale: they hold no user content; a Form 1 sector with zero data has non-zero ECC inside those
  2324 bytes and counts as data (fails closed).

## R6 Memory

- Decision: spans in a `TDirectArray`; out of memory -> the listing is marked (as 336's walk).
