# Data model - 336-uniso-form2-uncovered

- **Track** (`CISOImage::Track`): `ExtentOffset` (the track's first sector address, as the track table
  gives it), `FSType`, `RawLost` (335), new `Form2Stream` - a track-table data track with no file system
  whose sectors 16..31 are Form 2 (`!outside && form2` in `Open`); FALSE everywhere else.
- **Listed file**: a `CFileData` of the listing with `PluginData` = `CFilePos` (`Extent` - the file's
  first sector address) and `Size`. NULL `PluginData`: an audio track's virtual file (ignored).
- **Covered** (per track, built after the listing): TRUE when a listed file of more than zero bytes maps
  to the track by `SalIsoTrackOfExtent`.
- **Decision**: `SalIsoStreamTrackMarksListing(Form2Stream, Covered)` = `Form2Stream && !Covered` ->
  `ListingLeftOut.SetIncomplete()`.
