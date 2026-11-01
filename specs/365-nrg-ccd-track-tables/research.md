# Research - 365

## R1 Nero's mode bytes

- Decision: 0x00 / 0x02 -> 2048, 0x03 -> 2336, 0x05 / 0x06 / 0x07 -> 2352 stored bytes a sector; any other
  mode keeps the size 41f18c08 gave (ETNF: bit 0 -> 2336 else 2048; ETN2: 2048).
- Rationale: libmirage's `mirage_parser_nrg_decode_mode` (fix-log *Research*). 0x0F / 0x10 / 0x11 carry
  96 subchannel bytes, but libmirage's track-at-once loader divides the entry's size by 2352 and sets no
  subchannel offset, so the file layout of such a TAO track is not known; the item marks them "not
  verified". `SetTrackTypeMode` (mode / type) is unchanged - 0x10 / 0x11 stay unknown (334 marks them).
- Alternatives: 2448 for the subchannel modes (a guess); the libmirage default 2352 for every unknown
  mode (changes cases the item does not name).

## R2 ETN2 entries

- Decision: every whole 32-byte entry is a track (start u64 @0, length u64 @8, mode @19, first sector
  u32 @20); end = start + length (saturated); a chunk outside the image or with more than 99 entries is
  skipped (no track), the next chunk header read right after it.
- Rationale: libmirage's `NRG_ETN_Block`; the ETNF reader already reads all entries and takes the
  first-sector field as the extent offset. Without the extent, both tracks of a two-session image had
  extent 0 and a session-1 file was read from session 2's bytes (R-ETN200: wrong content). The bound
  keeps the track count from growing with a damaged chunk (41f18c08 made one track a chunk); 99 is a
  disc's track limit (as 350's per-chunk thinking; ETNF's own unbounded count is Inbox item
  `iso-plug-in-an-nrg-etnf-chunk-claiming-a-huge-size`).
- Alternatives: keep one track per chunk and fix only `End` (the item's literal wording - leaves the
  wrong content of R-ETN200 and the Mode 2 / raw tracks of R-ETN203 / R-ETN206).

## R3 CloneCD layout

- Decision: follow the table of contents (`SalIsoCcdTocLayout`): the k-th `[TRACK n]` = track number
  first + k (first = the smallest ADR-1 point 1..99); its entry (ADR 1, that point) gives its session and
  PLBA; within a session a track ends at the next track's PLBA, the last at the session's 0xA2 PLBA;
  sessions follow each other in the `.img`. Not followed (NONE -> the 41f18c08 split) when a track has no
  entry, two entries of one track disagree, a PLBA is negative, sessions go backwards, a session
  holding tracks has no lead-out, or more than 99 tracks.
- Rationale: libmirage builds exactly this layout from PLBA; psx-spx says INDEX values are counted from
  the session start, PLBA from the disc start; DiscImageCreator issue 121: the 11400 sectors between
  sessions are not in the `.img`. For CloneCD's own form (INDEX from the session) the layout equals
  41f18c08's (extent = INDEX + session's first PLBA = PLBA; counts from INDEX differences = PLBA
  differences); for INDEX counted from the disc it is the only reading that splits correctly.
- Alternatives: detect "absolute" INDEX values and subtract (still relies on INDEX, two conventions);
  choose packed or linear by the file size (no evidence any producer keeps the gap - a wrong guess
  fails closed anyway: the data track shows no file system, 335 marks it).

## R4 Negative sector counts

- Decision: `SalIsoCcdSectorCount` - a count below 0 becomes 0 and marks the listing incomplete, in
  both paths.
- Rationale: the item ("the last track's sector count (a DWORD) can underflow, so End wraps"); fails
  closed.

## R5 Pregap of a session's first track

- Decision: not added (Clarification 1).
- Rationale: INDEX 0 is not read today; CloneCD omits it for a later session (DiscImageCreator 121).
