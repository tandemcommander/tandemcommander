# Closing report - 350-nrg-cuex-bounds
Backlog item: iso-plug-in-an-nrg-cuex-chunk-under-16-bytes-makes-a-huge - ISO plug-in: an NRG CUEX chunk under 16 bytes makes a huge track count
Outcome: closed

## What changed

- `src/plugins/uniso/nrg.cpp` `readCUEX`: a CUEX chunk is read only when it lies within the image
  (`SalNrgChunkFits`, as 331's CD-Text reader), is no larger than any disc's CUEX can be
  (`SalNrgCuexSizePlausible`: 2 + 99 x 100 records of 8 bytes = 79,216 bytes) and its tracks keep
  the image within what all CUEX chunks of a disc can give (`SalNrgCuexTotalPlausible`: 4,950 + 99);
  otherwise it is skipped like an unknown chunk and makes no track. A chunk that is read gives only
  the whole 16-byte units its size holds (`SalNrgCuexEntryCount`; under 16 bytes none - the old
  32-bit `(Size - 16) / 16` underflowed to 268 million), every read is checked for its full length
  (no track from a short read), and the next chunk header is read right after the chunk.
- `src/common/salnrgcdtext.h`: the three rules above, with the CUEX layout written down (Nero's 8-byte
  index records, paired by the reader).
- `src/saltests/saltests.cpp`: `TestNrgCuex350` (32 checks).
- Probe `specs/350-nrg-cuex-bounds/probe/nrg350_probe.ps1`, images by `img350.py` (10 rows).

## Measurements (before / after, commands)

Hidden desktop, Debug x64:
`powershell -File tools\run_on_hidden_desktop.ps1 -Log <log> -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File specs\350-nrg-cuex-bounds\probe\nrg350_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label <label> -OutFile <rows>"`

| Row | main cadc65bb (`probe/result_before.txt`) | closing build (`probe/result_final.txt`) |
|---|---|---|
| N-OK (control) | opened, 2 tracks, 84 MB, 0.7 s | the same |
| N-SHORT (8-byte CUEX + 96 MiB chunk) | 1036 MB, 49.9 s, "Unknown file format" | opened, 2 tracks, 74 MB, 0.6 s |
| N-PAST (CUEX claiming 0xFFFFFFF0 bytes) | 1037 MB, 49.9 s | 74 MB, 0.6 s (not NRG, as before) |
| N-ODD (CUEX 4 bytes past its entries) | not opened | opened, 2 tracks |
| N-ZERO, N-SHORTNZ (review 1) | not opened (review 1's run of the old code) | opened, 2 tracks |
| N-INSIDE (96 MiB CUEX inside the image) | (first fix: 1565 MB, 179 s - review 1) | 74 MB, 0.6 s |
| N-IDX2, N-IDX20 (real layout, index points) | opened, 2 / 20 tracks (review 2's run) | the same |
| N-MANY (1,270 chunks of the largest size) | 1563 MB, 178 s (review 3, also 3b697c6d) | 74 MB, 0.7 s |

## Checks (encoding guard, build, saltests, probes - with numbers)

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED`. No UI strings, menus or dialogs changed - no `.slt` refresh,
  no `full` build needed.
- saltests: `29214 checks, 0 failed` (main 29,182). Mutants: underflow back 5 failed, remainder as an
  entry 5, a 99-unit bound 3, a loose image total 3; without the seek to the chunk's end the probe's
  N-ODD fails (`probe/result_mutant_no_seek.txt`).
- Probe: before 5 / 3 (4 rows), final 20 / 0 (10 rows); registry restored and identical every run.
- Regression: feature 329's probe `-Only A-OPEN` 2 / 0 (`probe/regress_329.txt`).

## Reviews (findings and what was done)

- Review 1: no MUST. SHOULD 1 (a CUEX chunk inside the image still built millions of tracks) - bounded;
  NOTE 1 (probe rows) taken; NOTE 2 (a short read leaves the position inside the chunk, as before)
  recorded; NOTE 3 closing records.
- Review 2: MUST 1 - review 1's 99-unit bound refused real discs with index points (Nero's CUEX is
  8-byte records) - replaced by the largest CUEX a disc can have; SHOULD 1 (document the layout) taken;
  NOTE 1 (the pairing) -> Inbox.
- Review 3: no MUST. SHOULD 1 (many chunks of the largest size) - image-wide bound; NOTE 1 (ETNF) ->
  Inbox; NOTE 2 (odd-record chunks now open through the pairing) added to that Inbox item.
- Review 4: no MUST, no SHOULD; the image-wide bound checked against libmirage's layout and the
  arithmetic; NOTEs 1-2 (probe wording) taken, NOTE 3 in *Limits*.
- Details: `fix-log.md`, section *Review*.

## Owed to a person (with the new person-step items)

- The CHANGELOG entry below: `CHANGELOG.md` has no `## [Unreleased]` section (versions are the
  maintainer's), so it is not added there.
- No real Nero image was tried: the probe's images are crafted, two of them in Nero's real CUEX
  layout as libmirage reads it (reviews 2-4); no person-step item was added.

CHANGELOG entry (for the next release's section):

- **A damaged Nero (NRG) disc image could take a gigabyte of memory and freeze the window for a minute** (feature 350).
  - **Before:** opening an NRG image whose CUEX chunk (its track list) was damaged - shorter than its header, longer than the image, or claiming millions of entries - made the ISO plug-in build one audio track from every 16 bytes up to the end of the file: a 100 MB image took about 1 GB of memory and 50 seconds to 3 minutes before "Unknown file format" or a listing of millions of tracks; a track list a few bytes longer than its entries made the image not open at all.
  - **Now:** the plug-in reads such a track list only when it lies within the image and is no larger than any disc's can be, takes only the whole entries it holds and continues after it, so a damaged image opens at once with the tracks its intact parts describe, or is reported as not valid.
  - **Limitation:** checked with crafted images only (two of them in Nero's real layout); an image whose tracks have extra index points still gets extra hidden tracks, as before.

## New Inbox items (slug - title)

- `iso-plug-in-nrg-cuex-index-records-are-paired-into-wrong` - ISO plug-in: NRG CUEX index records are paired into wrong tracks
- `iso-plug-in-an-nrg-etnf-chunk-claiming-a-huge-size` - ISO plug-in: an NRG ETNF chunk claiming a huge size allocates it whole
