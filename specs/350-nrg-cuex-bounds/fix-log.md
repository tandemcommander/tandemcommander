# Fix log - 350-nrg-cuex-bounds

Backlog item `iso-plug-in-an-nrg-cuex-chunk-under-16-bytes-makes-a-huge` - "ISO plug-in: an NRG CUEX
chunk under 16 bytes makes a huge track count". Autonomous run (`/tandem-backlog-implement`), started
2026-10-31 on `main` at cadc65bb.

## Measure first (main, cadc65bb)

- Site: `src/plugins/uniso/nrg.cpp` `readCUEX` - unchanged since the item was written:
  `int trackCount = (header->Size - 0x10) / 0x10;` (DWORD from the image), the 16-byte header read
  without a length check, each entry read without a length check, `new CAudioTrack` + `AddTrack` per
  entry. No seek to the chunk's end.
- Reachable: opening any `*.nrg` in a panel - `CISOImage::Open` -> `ReadSessionInfo` (extension `nrg`)
  -> `ReadSessionNRG` -> `ReadNRGRoot` -> `readCUEX`. `uniso=on` in `plugins.cfg`.
- `CBufferedFile::Read` returns FALSE once a read reaches past the end of the file, so the loop ends
  there - after building one track from every 16 bytes up to it. `ReadNRGRoot` ignores the reader's
  result and reads the next header from where the reader stopped.
- Probe `probe/nrg350_probe.ps1` (images by `probe/img350.py`), Debug x64 build of cadc65bb, hidden
  desktop:

  ```text
  powershell -File tools\run_on_hidden_desktop.ps1 -Log <scratch>\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File <scratch>\nrg350_probe.ps1 -Exe E:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -Lib <repo>\specs\098-long-path-overruns\probe\fix_probe_lib.ps1 -OutFile <scratch>\rows_before.txt"
  ```

  Result `probe/result_before.txt`: PASS 5, FAIL 3 (rows RUN + END per case):
  - N-OK (control) PASS: opened, two tracks ("Copy 2 files", "Audio tracks cannot be extracted"),
    peak working set 84 MB, answering after 0.7 s;
  - N-SHORT FAIL: CUEX of 8 bytes + 96 MiB chunk + the good chunks - peak 1036 MB, 49.9 s, "Unknown
    file format or not a valid ISO image", not opened;
  - N-PAST FAIL: CUEX claiming 0xFFFFFFF0 bytes + 96 MiB chunk - peak 1037 MB, 49.9 s, same box;
  - N-ODD FAIL: CUEX 4 bytes longer than its two entries - not opened (the next header read 4 bytes
    early, "DAOX" taken as a size).
  Registry restored, identical (SHA-256 4576C7DA...).

`BL verify` recorded the reproduction.

## Decisions

- Entry count: `Size < 16 ? 0 : (Size - 16) / 16`, as a pure rule in `src/common/salnrgcdtext.h`
  next to 331's rules (FR-006).
- A chunk that does not lie within the image (`SalNrgChunkFits`) is skipped like an unknown chunk,
  as 331's CDTX reader does: no track. The image then does not open as NRG (as before) - but without
  building tracks first.
- After a chunk that fits, the reader seeks to the chunk's end (FR-004): a whole-entries chunk is
  consumed exactly as before; a short or odd-sized chunk no longer shifts the next header.
- A short read of the header or an entry: no track from it, the reader stops (returns FALSE as
  before).
- No 99-track cap at first (the item names only the chunk / image bounds) - revised by review 1: a chunk of more than 99 entries is skipped (see *Review*).

## Implementation

- `src/common/salnrgcdtext.h`: `SalNrgCuexEntryCount(size)` (+ `SAL_NRG_CUEX_HEADER` /
  `SAL_NRG_CUEX_ENTRY`), the header comment extended.
- `src/plugins/uniso/nrg.cpp` `readCUEX`: the chunk's position and the file size taken as in
  `readCDTX`; a chunk that does not fit is skipped (seek past, FALSE); the 16-byte header read only
  when the chunk holds it, every read checked for its full length (a short read: no track, FALSE);
  entries from the rule; after them a seek to `pos + Size`.
- `src/saltests/saltests.cpp`: `TestNrgCuex350` (15 checks: sizes 0..300 against an entry-by-entry
  reference, the named sizes, the old 32-bit formula, two `SalNrgChunkFits` cases).
- Analysis findings C1 / C2 (MEDIUM) taken into the probe: a bound row also needs the window
  answering within 5 s; an opened row needs "Copy 2 files" (both tracks listed). `result_before.txt`
  was taken with the earlier, looser conditions - its three FAIL rows fail the stricter ones too.

## Checks

- Encoding guard: `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- Build: `.\build.cmd` -> `BUILD SUCCEEDED` (uniso.spl and saltests.exe rebuilt after the edits,
  timestamps checked). No UI strings, menus or dialogs changed - no `.slt` refresh, no `full` build
  needed.
- saltests: `saltests: 29197 checks, 0 failed` (main: 29,182; +15).
- Probe after (`probe/result_after.txt`): PASS 8, FAIL 0 - N-OK 84 MB / 0.7 s; N-SHORT opened with
  its two tracks, 74 MB, 0.6 s (before 1036 MB, 49.9 s, not opened); N-PAST not opened (as wanted),
  74 MB, 0.6 s (before 1037 MB, 49.9 s); N-ODD opened with its two tracks (before not opened).
  Registry restored, identical.
- Regression: 329's probe `-Only A-OPEN` (`probe/regress_329.txt`): PASS 2, FAIL 0.

## Negative controls

- Mutant 1 (the rule back to `(unsigned int)(size - 16) / 16`, no guard): saltests 5 failed
  (smallOk, sizes 0, 8, 15, the old-formula check).
- Mutant 2 (the remainder counted as an entry, `(size - 16 + 15) / 16`): saltests 5 failed
  (smallOk, sizes 31, 52, 63, 0xFFFFFFFF).
- Mutant 3 (no seek to the chunk's end in `readCUEX`): probe `probe/result_mutant_no_seek.txt` PASS 7,
  FAIL 1 - N-ODD fails (not opened), the others pass. N-SHORT does not catch it: its 8 chunk bytes are
  zeros, which the chunk list reads as an empty unknown chunk - a limit of that row, N-ODD covers the
  seek.
- Each mutant restored from a copy; `grep MUTANT` -> 0; rebuilt; saltests 29,197 / 0.

## Review

### Review 1 (independent agent, refute-first) - no MUST

- Re-ran the build (OK), saltests (29,197 / 0), the encoding guard (0), the probe on the fix (4 rows
  PASS as recorded, plus its own rows N-ZERO, N-HDR20 = a 20-byte chunk, N-SHORTNZ PASS) and on the
  old `nrg.cpp` in a copy (N-SHORT 1037 MB / 50.2 s, N-PAST 1039 MB / 50.1 s, N-ODD / N-ZERO /
  N-SHORTNZ not opened) - the probe separates old from new. Callers: `ReadNRGRoot` only (ignores
  the result, as before); a well-formed chunk consumes the same bytes; `CBufferedFile::Seek(0,
  FILE_CURRENT)` is the logical position. No data-loss path (read-only open).
- **SHOULD 1**: a CUEX chunk of 16 + 96 MiB lying within the image (kind `inside`) still built every
  entry on the first fix: 1565 MB, 179 s, 6.3 million tracks (probe killed the program) - worse than
  the item's case. **Taken** (inside the item's *Problem*): `SalNrgCuexEntriesPlausible` - a chunk of
  more than 99 entries (a CD's tracks) is skipped like one that does not fit. The spec's
  clarification "no 99-track cap" revised, FR-002 extended.
- **NOTE 1**: N-SHORT cannot catch a missing seek (zero bytes) - **taken**: rows N-ZERO and N-SHORTNZ
  ("ABCDEFGH") added (and N-INSIDE for SHOULD 1). N-HDR20 not added (N-ZERO / N-SHORTNZ cover it).
- **NOTE 2**: a short read inside a fitting chunk leaves the position inside the chunk - unchanged
  from before, needs an I/O error; the spec's edge case says so. Not changed.
- **NOTE 3**: closing records not yet written - done at closing.

After the fix: `build.cmd` BUILD SUCCEEDED; saltests `29202 checks, 0 failed` (+5);
probe `probe/result_after_review1.txt` PASS 14, FAIL 0 (N-INSIDE opened with its two tracks, 74 MB,
0.6 s); registry restored, identical. Mutant (the cap removed, `entries <= 0xFFFFFFFF`): saltests 3
failed (101 entries, the 96 MiB chunk, 0xFFFFFFFF); restored, rebuilt, 29,202 / 0; encoding guard 0.

### Review 2 (independent agent, refute-first) - one MUST

- **MUST 1**: review 1's bound counted the reader's 16-byte units as tracks, but Nero's CUEX is 8-byte
  index records (lead-in, per track index 0 and each index 1..99, lead-out; libmirage reads it so, one
  chunk a session). A real disc with index points has more than 99 units: 2 tracks of index 1..99 =
  100, 20 tracks of index 1..10 = 110. The reviewer's real-layout images (its `imgrev.py`): main
  opened them ("Copy 2 files", "Copy 20 files"), the branch at 0d1af51d did not ("Unknown file
  format"). **Fixed**: the bound is now the largest CUEX a disc can have -
  `SAL_NRG_CUEX_MAX_RECORDS` = 2 + 99 x 100 records of 8 bytes (79,216 bytes, 4,950 units),
  `SalNrgCuexSizePlausible(size)`; a larger chunk is skipped like one that does not fit. Review 2's
  option 2; option 1 (read at most 99 units, ignore the rest) rejected - it changes real images'
  track tables against main.
- **SHOULD 1**: the code and the spec stated "one 16-byte entry a track" as fact - **taken**: the
  header comment, spec (Background, Clarifications, Edge Cases, FR-002, Key Entities, Assumptions),
  research R5 and the data model now state the 8-byte record layout and the reader's pairing as a
  known limit.
- **NOTE 1**: with index points the pairing gives misaligned extent offsets and extra tracks; on a
  multi-session image session 2's track numbers drift from its DAOX - upstream since ever, not this
  feature: Inbox item `iso-plug-in-nrg-cuex-index-records-are-paired-into-wrong` (measure:350).

After the fix: build BUILD SUCCEEDED; saltests `29206 checks, 0 failed` (TestNrgCuex350 now 24 checks);
probe `probe/result_after_review2.txt` PASS 18, FAIL 0 (rows N-IDX2 "Copy 2 files", N-IDX20 "Copy 20
files" added - real-layout discs with index points; N-INSIDE still 73 MB, 0.6 s); registry restored,
identical. Mutant (the bound back to 99 units, `SAL_NRG_CUEX_MAX_RECORDS (2 + 2 * 99)`): saltests 3
failed (2 tracks of index 0..99, 20 tracks of index 0..10, the disc maximum); restored, rebuilt,
29,206 / 0; encoding guard 0. Review 2's own run of these images on main and on 0d1af51d is the
probe's negative control for N-IDX2 / N-IDX20.

### Review 3 (independent agent, refute-first) - no MUST

- Re-ran build, saltests 29,206 / 0, encoding 0; checked the bound against libmirage's NRG parser
  (fetched): CUEX / CUES are 8-byte records, one CUEX chunk a session, BCD track and index - one
  session holds at most 9,902 records = 79,216 bytes = `SAL_NRG_CUEX_MAX_RECORDS`; DVD / multi-session
  images have one chunk a session, ISRC / UPC live in DAOX, CD-TEXT in CDTX - the bound refuses no
  real disc. Its row R-MAX (99 tracks of index 0..99, exactly 79,216 bytes) opened, "Copy 99 files",
  74 MB, 0.7 s.
- **SHOULD 1**: the bound was per chunk - 1,270 back-to-back CUEX chunks of 79,216 bytes (96 MiB,
  its kind `many`) built a track per 16 bytes again: 1563 MB, 178.2 s, probe killed the program (not
  a regression - main reads them alike). **Taken**: `SalNrgCuexTotalPlausible(tracks, entries)` - a
  chunk is skipped when the image's tracks would pass `SAL_NRG_CUEX_MAX_IMAGE_ENTRIES` = 4,950 + 99
  (all sessions' CUEX of a disc give at most 4,950 of the reader's tracks; 99 as a margin). Row
  N-MANY added.
- **NOTE 1**: `readETNF` allocates and zeroes the claimed size unchecked (1 GiB claim in a 47 KB
  image: 1095 MB) - outside this item: Inbox `iso-plug-in-an-nrg-etnf-chunk-claiming-a-huge-size`
  (review:350).
- **NOTE 2**: real CUEX chunks of an odd number of records (8 mod 16 bytes) did not open on main and
  open now, through the pairing - added to Inbox `iso-plug-in-nrg-cuex-index-records-are-paired-into-wrong`.

After the fix: build BUILD SUCCEEDED; saltests `29214 checks, 0 failed` (+8); probe
`probe/result_after_review3.txt` PASS 20, FAIL 0 (N-MANY 74 MB, 0.7 s; it opens - the good chunks'
CUEX still fits the bound after the first zero chunk's 4,950 tracks, "Copy 2 files"); registry
restored, identical. Mutant (`tracks + entries <= SAL_NRG_CUEX_MAX_IMAGE_ENTRIES * 1000`): saltests 3
failed; restored, rebuilt, 29,214 / 0; encoding guard 0.

### Review 4 (independent agent, refute-first) - no MUST, no SHOULD

- Re-ran build, saltests 29,214 / 0, encoding 0 (BOM and clang-format of the changed sources
  checked), the probe on the branch PASS 20 / 0. Negative control: `uniso.spl` of 3b697c6d (before
  review 3's change) in a copied build tree - N-MANY FAIL (1563 MB, 178.7 s), N-OK / N-INSIDE
  PASS (the swapped plug-in was loaded).
- The image-wide bound refuses no real image: a session's CUEX of (2 + t) records gives floor(t / 2)
  entries, a disc's t together at most 9,900 -> 4,950; one CUEX chunk a session (libmirage); TAO
  (ETNF / ETN2) tracks counted first leave the total at most 4,950; DVD track counts far below.
  Boundary checks in saltests right, no wrap.
- **NOTE 1**: N-MANY printed "want False" while not checking the open - **taken**: rows that do not
  check the open print "want any".
- **NOTE 2**: `img350.py`'s `many` text said "4,950 tracks and no more" - 4,952 (the good chunks' 2
  fit) - **taken**.
- **NOTE 3**: a damaged image that used up the budget skips its later genuine CUEX chunks - no worse
  than main; in *Limits*.

## Limits

- A short read inside a chunk that fits leaves the next header read from inside the chunk (review 1
  NOTE 2; needs an I/O error; unchanged from before).
- Damaged CUEX chunks within the image still build up to 5,049 tracks for the image (no measurable
  cost: N-MANY 74 MB).
- The reader's pairing of Nero's 8-byte records is unchanged (review 2 NOTE 1, Inbox).
- A damaged image whose CUEX chunks use up the 5,049-track budget has its later genuine CUEX chunks
  skipped (review 4 NOTE 3; main read them after building the junk tracks).
