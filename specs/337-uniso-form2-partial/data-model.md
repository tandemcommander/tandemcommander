# Data model - 337-uniso-form2-partial

- **Stream track** (`CISOImage::Track` with `Form2Stream`): `Start` (byte offset of sector 0 in the image),
  `End` (track-table end), `SectorSize` (2336 or >= 2352 for a stream), `ExtentOffset` (disc address of
  sector 0). Derived: `trackSectors` (R4).
- **SalIsoStreamSpan** `{ Track, First, End }`: track-relative sectors `[First, End)` a listed file reads.
  Built only for files whose start track is a stream track; sorted by (Track, First) and merged
  (overlapping or adjacent ranges of one track become one).
- **Gap**: a run of `[0, trackSectors)` that no merged span of the track includes.
- **Decision** per stream track: no file starts in it -> marked (336); uncovered sectors > 300 ->
  marked; any gap sector not empty (R5) or not readable -> marked; else not marked.
