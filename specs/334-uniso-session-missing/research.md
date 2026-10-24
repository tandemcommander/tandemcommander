# Research - 334-uniso-session-missing

## R1 Where the listing loses a track

- Decision: `CISOImage::ListImage` is the one place - both its paths (multi-session "Session NN" and
  the single-session last-track listing with its fallback).
- Rationale: measured (fix-log, rows M-TERM, S-TERM); the only caller is `ListArchive`, used by the
  panel and by `UnpackWholeArchive`, which fails on 328's `ListingLeftOut` mark.
- Alternatives: marking inside `OpenTrack` - rejected: `OpenTrack` is also used by unpack, the viewer
  and single-file extraction, where a failure is reported by them; the listing alone knows whether a
  track was left out.

## R2 A track past the end of the image (row M-PAST)

- Decision: `CISOImage::Open` records `Track::OutsideImage` when `DetectTrackFS` finds no file system
  (the track becomes `fsData`) **and** the track's sector 16 does not lie within the image file (the
  same bound `DetectTrackFS` uses for its descriptor loop). The rule marks such a data track in both
  listing paths.
- Rationale: such a track opens as a raw data track (`CRawFS` opens and lists nothing), so no open
  fails - the loss is silent (measured: no box, image deleted). Readable raw data tracks (Video CD
  MPEG tracks) must stay unmarked (spec Clarifications), and they are within the image.
- Alternatives: every `fsData` track marks - rejected (every Video CD's whole unpack would fail);
  checking only the track's first sector - rejected: a track cut before sector 16 shows no file system
  either and loses its content just the same; tracks with a detected file system - not needed: their
  reader opens or not (R1), and their read errors mark (330).

## R3 Audio and unknown tracks (revised after review 1)

- Decision: every audio track and every unknown track marks the listing; so does a track that no
  session count covers (`SAL_ISO_TRACK_LEFT_OUT`).
- Rationale: the plug-in never extracts audio - `ExtractAllItems` ignores `UNPACK_AUDIO_UNSUP` - and a
  single-session listing of a data + audio disc does not show the audio tracks at all; an unknown track
  is shown by no listing. Review 1 measured the loss (rows S-MIXED, M-UNK, M-EXTRA: image deleted).
  The first decision ("audio counts only when it does not open; unknown never") kept those images'
  deletion and was wrong about audio CDs and mixed-mode discs being safe.
- Cost: an audio CD or a mixed-mode disc is never deleted by "Delete archive after unpacking" (its audio
  was never extracted - nothing to keep it for except the audio itself).

## R4 The single-session path

- Decision: when the last data track opens, the listing is as before plus a mark for any track outside
  the image; when it does not, it is marked (the fallback lists other tracks), and each track the
  fallback tries that does not open or fails to list marks it as well.
- Rationale: the item's *Problem* ("the single-session path has the same gap"); `LastTrack` is -1 for
  an audio CD (the fallback is then the normal path, and nothing failed to open).

## R5 A rule header

- Decision: `src/common/salisotrack.h`, header-only (uniso includes `../../common/...`; it cannot
  compile a `.cpp` of `src/common`), tested in `saltests` for every combination.
- Rationale: stop-rules §2.5, the area's pattern (328-333).
