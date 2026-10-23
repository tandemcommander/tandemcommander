# Closing report - 331-nrg-label-bounds
Backlog item: iso-plug-in-an-nrg-audio-track-label-of-257-bytes-overruns-a - ISO plug-in: an NRG audio track label of 257+ bytes overruns a stack buffer
Outcome: closed

## What changed

- New header-only rule `src/common/salnrgcdtext.h`: `SalNrgChunkFits`, `SalNrgCdTextLen`,
  `SalNrgCdTextGather`, `SalNrgCdTextNext`, `SalNrgDaoTrackInRange`, `SalNrgAudioTrackNameAlloc`.
- `src/plugins/uniso/audio.cpp` `CAudio::ListDirectory`: the track's name is built whole on the heap
  (it was `sprintf` into `char[MAX_PATH]`) and handed to 329's listing rule (listed, or left out and
  named in the "(206)" report); out of memory marks the listing incomplete.
- `src/plugins/uniso/nrg.cpp` `readCDTX`: the chunk is used only when it lies within the image; one
  buffer of its size (no 32-bit wrap); the text gathered in place within the chunk; labels split by
  length; complete read required. `readDAOX`: complete reads; entries only for tracks 1..count.
- `src/plugins/uniso/isoimage.cpp` `CISOImage::GetTrack`: `track < Tracks.Count` (was `<=`).
- No UI string, no plug-in interface change.

## Measurements (before / after, commands)

- Before (d87666d5): the sites confirmed by reading (fix-log *Measurement*); the run itself drove no
  image against the old code.
- Review 1 drove 8 crafted NRG images on the plug-in of d86b4e7b vs 0f19a673 on the hidden desktop: old
  6 / 8 fail (stack corruption for 300-byte labels, heap corruption for a 22-byte CDTX, the wrapped
  buffer for a 0xFFFFFFFF CDTX, out-of-range and NULL track for DAOX 3-of-2 and 0), fixed 0 / 8 (fix-log
  *Review*).
- After: feature 329's `iso329_probe.ps1 -Only A-OPEN` -> PASS 2 / FAIL 0
  (`probe/result_329_A_after.txt`; registry restored, identical SHA-256).

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> BUILD SUCCEEDED (Debug x64).
- `saltests` -> 28,304 checks, 0 failed (28,266 before; `TestNrgCdText331` +38). Negative controls: the
  gather bound without the flag bytes, the DAOX range up to count + 1, a name cut at 259 bytes - 2 failed
  checks each.
- Probe: 329 A-OPEN 2 / 0.

## Reviews (findings and what was done)

- Review 1 (refute-first): no MUST. SHOULD 1 (record what can be driven) - its before / after table is
  in the fix-log; its scratch generator is not kept in the repository. SHOULD 2 (a CDTX past the
  image's end makes the image not open as NRG) - the spec's US2 scenario says so; same outcome as
  before. SHOULD 3 (audio names not UTF-8 / not cleaned, older) - Inbox item. NOTE (CD-Text is 18-byte
  packs; real chunks were not overread) - comments, research and fix-log corrected, two checks added.

## Owed to a person (with the new person-step items)

- Nothing.

## New Inbox items (slug - title)

- iso-plug-in-an-nrg-session-count-above-the-image-s-tracks - ISO plug-in: an NRG session count above the image's tracks lists past the track table
- iso-plug-in-an-nrg-cuex-chunk-under-16-bytes-makes-a-huge - ISO plug-in: an NRG CUEX chunk under 16 bytes makes a huge track count
- iso-plug-in-nrg-audio-track-names-are-listed-without - ISO plug-in: NRG audio track names are listed without cleaning or UTF-8 conversion
