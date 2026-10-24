# Research - 336-uniso-form2-uncovered

## R1 - Where the listed files' extents are known

- Decision: walk the listed tree (`CSalamanderDirectoryAbstract`: `GetFilesCount` / `GetFile`,
  `GetDirsCount` / `GetSalDir` - as `CISOImage::ExtractAllItems` does) once after `ListImage` has built
  it; each file's `PluginData` is its `CFilePos` (`Extent`), NULL for an audio track's virtual file.
- Rationale: one place covers every reader (ISO 9660, UDF, HFS, Xbox, raw) and every listing mode
  (session folders or not); it sees exactly the files the whole unpack extracts (entries the listing
  refused are already marked by feature 328).
- Alternatives: noting the extent in every reader's add-entry code (five sites, easy to miss one; would
  count entries the panel refused afterwards).

## R2 - What "starts in the track" means

- Decision: `GetTrackFromExtent`'s rule - the track before the first track (from the second on) whose
  `ExtentOffset` is above the extent, else the last track. Moved into `salisotrack.h`
  (`SalIsoTrackOfExtent`, a template over the offset accessor) and called by `GetTrackFromExtent`, so the
  check and the unpack can never disagree on which track a file is read from.
- Rationale: the unpack opens that track to extract the file (`UnpackFile` -> `OpenTrack`), so a file
  that maps to the stream track is what extracts the stream's sectors.
- Alternatives: comparing byte ranges of the tracks (`Start` / `End`) - a different rule than the
  unpack's; a file whose extent maps elsewhere would be counted.

## R3 - Which files count

- Decision: files (not folders) of more than zero bytes with position data.
- Rationale: a folder or an empty file extracts none of the track's sectors; fails closed.

## R4 - Which tracks are checked

- Decision: only tracks feature 335 decided to be Form 2 streams: a new `Track::Form2Stream`, set in the
  track-table branch of `Open` to `!outside && form2`.
- Rationale: `fsData && !RawLost` would also hold for the single track of an image without a track table
  (never checked by 335); an explicit flag keeps every other case unchanged (spec FR-006).

## R5 - Deletion controls

- Real Video CD / SVCD images by vcdimager 2.0.1 (reviewer 3 of 335, `probe/review3/gen335c.py`; the
  images are in `%TEMP%\rev335c\imgs`): their `AVSEQ01.DAT` / `AVSEQ01.MPG` start at the stream tracks'
  INDEX 01 (the CloneCD reader takes `INDEX 1` as `ExtentOffset`; NRG ETNF the track's first sector).
- Synthetic: a seed `s1c.iso` (genisoimage, `a.txt` and `avseq01.dat`) whose `avseq01.dat` records are
  patched to start at the stream track (`img336.py`).
