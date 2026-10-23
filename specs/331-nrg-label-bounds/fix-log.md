# Fix log - 331-nrg-label-bounds

Backlog item `iso-plug-in-an-nrg-audio-track-label-of-257-bytes-overruns-a`.

## Measurement at d87666d5 (before)

- `.\build.cmd` (Debug x64) -> BUILD SUCCEEDED (HEAD built).
- By reading (the item's own note: no run reproduced it; this run does not build images that drive the
  overrun on the old code - spec Assumptions):
  - `src/plugins/uniso/audio.cpp` `CAudio::ListDirectory`: `char audioTrack[MAX_PATH]`,
    `sprintf(audioTrack, "%02d %s", Track + 1, label)` - present.
  - `src/plugins/uniso/nrg.cpp` `readCDTX`: `new char[header->Size + (1 + trackCount)]` in 32-bit
    unsigned arithmetic; block loop `for (i = Size; i > 0; i -= 18) memmove(dst, src, min(12, i))`
    with `src = data + 4 + 18k` (reads up to 4 bytes past the chunk when its size is not a whole number of 18-byte packs; review 1:
    real chunks are whole packs);
    `memset(dst, 0, 1 + n)` at `data + 12 * ceil(Size / 18)` (past the buffer for Size < 36); the read
    count unchecked - present.
  - `readDAOX`: `iso->GetTrack(i - 1)` for `i` = first..last from the image, no NULL / range check;
    entry reads not checked for a full read - present.
  - `CISOImage::GetTrack`: `track >= 0 && track <= Tracks.Count` - off by one, present.
- Reachable: opening a `.nrg` file (`CISOImage::Open` -> `ReadSessionInfo` -> `ReadSessionNRG` ->
  `ReadNRGRoot`); listing `ListImage` -> `OpenTrack` -> `CAudio::ListDirectory` (uniso is on).
- `BL verify` recorded.

## Analyze

- No CRITICAL / HIGH. Accepted MEDIUM: SC-003's `GetTrack` part has no automated check (plug-in code,
  a one-line change read in review); US1 scenario 1 (a 300-byte label) is not driven by a probe
  (spec Assumptions) - covered by the name rule's checks and 329's listing rule.

## Implementation

- `src/common/salnrgcdtext.h` (new, header-only): `SalNrgChunkFits`, `SalNrgCdTextLen`,
  `SalNrgCdTextGather`, `SalNrgCdTextNext`, `SalNrgDaoTrackInRange`, `SalNrgAudioTrackNameAlloc`.
- `audio.cpp` `CAudio::ListDirectory`: the name from `SalNrgAudioTrackNameAlloc` (heap, whole), freed
  after `AddFileDir` (which DupStr's it); NULL -> `ListingLeftOut.SetIncomplete()` +
  `IDS_INSUFFICIENT_MEMORY`, FALSE (as `AddFileDir`'s own out-of-memory path).
- `nrg.cpp` `readCDTX`: the chunk is used only when it lies within the image after its header
  (`GetFileSize` + `Seek(0, FILE_CURRENT)`, `SalNrgChunkFits`), size 0 and a failed `malloc` skip it
  (`Seek(Size, FILE_CURRENT)`, as an unknown chunk); the read must be complete; the text is gathered in
  place, the labels split by length and copied to 0-terminated heap strings for `SetLabel`.
- `nrg.cpp` `readDAOX`: header and entry reads must be complete; an entry is applied only to track
  numbers 1..count (`SalNrgDaoTrackInRange`), a NULL track skipped.
- `isoimage.cpp` `CISOImage::GetTrack`: `track < Tracks.Count`.
- The first build failed: `#include "salnrgcdtext.h"` is not on uniso's include path - the other
  common headers are included as `../../common/...` (isoimage.h, iso9660.h); fixed the same way.

## Checks (after)

- `.\build.cmd` -> BUILD SUCCEEDED (one C4267 warning in `CAudio::AddFileDir` `fd.NameLen = strlen(...)`,
  an untouched line).
- `saltests.exe` -> `saltests: 28302 checks, 0 failed` (28,266 at 330 -> +36, `TestNrgCdText331`).
- Negative controls (scratch script `mutant331.py`, header restored and hash-compared after):
  - gather bound counted without the 4 flag bytes (the old loop's overread): 2 failed (`lenOk`,
    `contentOk`);
  - DAOX range up to count + 1 (GetTrack's old `<=`): 2 failed;
  - the name cut at 259 bytes (a bounded buffer): 2 failed (`namesOk`, the 303-byte name).
- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- clang-format: the new header, `nrg.cpp`, `audio.cpp` clean; the new test lines aligned.
- Probe: feature 329's `iso329_probe.ps1 -Only A-OPEN` on the hidden desktop
  (`probe/result_329_A_after.txt`): **PASS 2, FAIL 0** - labels `01 SHORT` listed, `02 <253 L>` named in
  the "(206)" box, copy answers "Audio tracks cannot be extracted"; registry restored, identical
  SHA-256.
- Not driven by this run (spec Assumptions): an image with a 300-byte label or damaged CDTX / DAOX
  sizes; the rules' checks cover those inputs - review 1 drove them (below).

## Inbox (measure:331)

- `iso-plug-in-an-nrg-session-count-above-the-image-s-tracks` - SINF session counts index past the
  track table in `ListImage`.
- `iso-plug-in-an-nrg-cuex-chunk-under-16-bytes-makes-a-huge` - `readCUEX`'s size underflow.
- `iso-plug-in-nrg-audio-track-names-are-listed-without` (source `review:331`) - audio track names
  neither made UTF-8 nor cleaned (review 1's SHOULD 3; older than this feature).

## Review

### Review 1 (refute-first, general-purpose agent) - no MUST

The reviewer built the uniso plug-in of d86b4e7b (before) and of 0f19a673 (after) in scratch worktrees,
put each into a copy of the Debug tree and drove 8 crafted NRG images on the hidden desktop with a
probe based on 329's `Audio-Row` (registry restored with identical SHA-256 each time; worktrees
removed). Old -> fixed:

| Image | Old plug-in | Fixed plug-in |
|---|---|---|
| base (253-byte label, as 329) | survives | survives, "(206)" names `02 <253 L>` |
| l300 (300-byte label) | "Run-Time Check Failure #2 - Stack around the variable 'audioTrack' was corrupted" | survives; "(206)" names the 300 L, `01 SHORT` listed |
| l300utf8 (200 bytes of e-acute + 100 L) | the same stack corruption | survives; the name listed whole |
| cdtx22 (CDTX of 22 bytes) | HEAP CORRUPTION DETECTED (buffer of nrg.cpp) | survives |
| cdtx5 (CDTX of 5 bytes) | survives (the small overrun not detected) | survives |
| daox3 (DAOX tracks 1..3 of 2) | TRACE_C "Index is out of range (index = 2, Count = 2)" | survives |
| daox0 (DAOX track 0) | access violation writing 0x8, bug report | survives |
| cdtxhuge (CDTX size 0xFFFFFFFF) | TRACE_C "_sal_safe_memcpy: source and destination of memcpy overlap" (the wrapped buffer) | survives; the image does not open as NRG (SHOULD 2) |

saltests from HEAD 0 failed; callers enumerated (`GetTrack`: audio.cpp, nrg.cpp x2, udf.cpp via
`GetTrackFromExtent` - never above count - 1, 255 with no tracks: NULL before and after;
`CBufferedFile::Seek(0, FILE_CURRENT)` returns the logical position; `ListingLeftOut.Add` copies the
name) - no regression; no data-loss path (audio is never extracted; out of memory marks the listing).

- SHOULD 1 (the evidence understates what can be driven): taken as a record - the table above is the
  driven before / after measurement. The reviewer's scratch generator and probe (images built to crash
  the old build) are not copied into the repository; the kept regression is `TestNrgCdText331` (its
  mutants fail) and 329's A-OPEN row.
- SHOULD 2 (US2 scenario 2 described "no labels" while a CDTX past the image's end makes the image not
  open as NRG): the spec's scenario now says so. Before this feature the same image ended the chunk list
  at the end of the file too (after a read into a wrapped buffer), so a consistent outcome, not a new
  refusal.
- SHOULD 3 (audio names not made UTF-8 / safe, older): Inbox `iso-plug-in-nrg-audio-track-names-are-listed-without`.
- NOTE (the CD-Text format is 18-byte packs of 4 header + 12 text + 2 CRC bytes, so real chunks are a
  whole number of packs and the old loop did not overread them): the header comment, the research R2
  text, the fix-log measurement and the saltests comment corrected; checks for sizes 18 and 36 added.
- NOTE (cdtx5 is no detector; large chunks within the image are still read whole; a file whose low size
  DWORD is 0xFFFFFFFF is refused as ReadSessionNRG already does): accepted, as the clarifications say.

After review 1 (comments, two saltests checks): `.\build.cmd` BUILD SUCCEEDED; `saltests: 28304 checks,
0 failed`; encoding guard `TOTAL: 0 finding(s)`. No code of the plug-in changed in this round (the
header's comment only), so 329's A-OPEN result stands.
