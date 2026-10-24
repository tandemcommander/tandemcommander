# Research - 340-nrg-session-count

## R1 - Where to bound the counts

- Decision: in the listing (`CISOImage::ListTracks`), the only place that indexes the track table by the
  session counts.
- Rationale: in an NRG image a session's SINF chunk may come before or after the chunks that add its
  tracks (CUEX / DAOX per session, ETNF for the whole image), so `readSINF` does not know the final track
  table; the listing does. The counts stay stored as the image gives them.
- Alternatives: clamp in `readSINF` (order-dependent, would hide the mismatch from the listing's mark);
  change `Session` to `unsigned` (touches CCD code and the viewer for no gain - the cast at the one use
  is enough).

## R2 - How a count of 2^31 or more is read

- Decision: as `unsigned int` (the DWORD the image stores), in the rule's parameter; the caller casts
  `Session[session]`.
- Rationale: `TDirectArray<int>` turned 0xFFFFFFFF into -1 - the next session then started at track -1
  (S-NEG) or a session's track was skipped (S-NEGEND). Read unsigned, every such count is simply far
  above the tracks left and does not fit.

## R3 - What a session that does not fit gets

- Decision: the tracks left from its start, listed as today; the listing marked incomplete via
  `ListingLeftOut.SetIncomplete()` (328, used by `MarkTrack`); no box.
- Rationale: the item's *Expected* ("the session's missing tracks are not listed, and the listing is
  marked incomplete"); the existing tracks are real content - leaving them out would lose them from a
  whole unpack (and the mark keeps the image anyway).

## R4 - Arithmetic

- The rule computes the tracks left as `long long` (`trackCount - first`, 0 when `first` is outside
  `[0, trackCount)`), compares the unsigned count widened to `long long`: no overflow for any 32-bit count
  (S-OVER1000 and 0xFFFFFFFF). The caller's running start only grows by the returned number, so it stays
  within `[0, Tracks.Count]`.

## R5 - Other readers of the counts (enumerated)

- `img.cpp` (CCD/IMG): counts derived from its own track list - always fit; unchanged.
- `isoimage.cpp` `Session.Add(1)` (images without a track table): unchanged.
- `ListTracks` leftover loop (334: tracks no count covers are left out): starts at the running start,
  which is now never past the table or negative.
- `viewer.cpp` `CISOImage::DumpInfo` (F3 information): walks the track table only; reads
  `Session[session]` past the session table when the counts add up to fewer tracks than the image holds
  (e.g. 334's `multi_extra.nrg`) - another defect, outside this item: Inbox item (measure:340).
