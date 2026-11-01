# Fix log - 365-nrg-ccd-track-tables

Backlog item `iso-plug-in-nrg-etnf-etn2-and-multi-session-ccd-track-tables` - ISO plug-in: NRG ETNF / ETN2
and multi-session CCD track tables get wrong sector sizes or ends. Autonomous run (tandem-backlog-implement),
2026-11-01, `main` at 41f18c08.

## Research (before measuring)

- Read: FEATURE-HISTORY 334, 335, 336, 350, 351, 352, 353; `nrg.cpp` (`readETNF`, `readETN2`,
  `SetTrackTypeMode`, `ReadNRGRoot`), `img.cpp` (`ReadSessionCCD`, `processTrackSection`,
  `processEntrySection`), `isoimage.cpp` (`GetHeaderSizeFromMode`, `GetSectorOffset`, `Open`'s track loop).
- libmirage sources (web, `libmirage/images/image-nrg/parser.c`, `image-nrg.h`, `image-ccd/parser.c`):
  - ETN entry (`NRG_ETN_Block`): ETNF (v1, 20 bytes) offset u32 @0, size u32 @4, mode @11, sector u32 @12;
    ETN2 (v2, 32 bytes) offset u64 @0, size u64 @8, mode @19, sector u32 @20. Track-at-once: sector count =
    size / main sector size; data from `offset`.
  - `mirage_parser_nrg_decode_mode`: 0x00 Mode 1 2048; 0x02 Mode 2 Form 1 2048; 0x03 Mode 2 Form 2 2336;
    0x05 Mode 1 2352; 0x06 Mode 2 mixed 2352; 0x07 audio 2352; 0x0F Mode 1 2352 + 96 sub; 0x10 audio
    2352 + 96; 0x11 Mode 2 2352 + 96; default audio 2352. (The item's note had 0x10 / 0x11 swapped.)
  - libmirage ties ETNF to "NERO" (v1) files and ETN2 to "NER5"; this plug-in reads only "NER5" footers,
    so ETNF is reached through an NER5 image holding an ETNF chunk (as 334 / 335 build their images).
  - CloneCD: libmirage builds the layout from the TOC entries' PLBA only: track_start = PLBA - pregap,
    track_end = the next entry's PLBA (the session's 0xA2 for its last track); fragments appended back to
    back (`offset += fragment_length`) - the `.img` packs the sessions. Its comment: "Index addresses seem
    to be relative to session start".
- psx-spx (nocash) CloneCD page: "The INDEX values in the [TRACK N] entries are originated at the begin of
  the corresponding session, whilst PLBA values in [Entry N] entries are always originated at the begin
  of the disk."
- DiscImageCreator issue 121: "The session overhead, lead-out, lead-in and pregap of the first track in the
  second session are completely omitted from the image" (11400 sectors for the first transition);
  "CloneCD's *.CCD relies on the 11400 sectors being omitted".
- **So the item's CCD premise ("a real multi-session image (absolute INDEX 1 values) is not split") is
  doubtful**: CloneCD's own form counts INDEX from the session, which HEAD splits on `INDEX 1 = 0`. The
  table-of-contents layout (PLBA) reads both forms - the item's note ("once the split follows the table
  of contents") asks for exactly that.

## Measurement before (41f18c08, Debug x64)

`build.cmd` (incremental, up to date), then on the hidden desktop:

```text
powershell -File tools\run_on_hidden_desktop.ps1 -Log ...\result_before.txt -CommandLine "powershell -NoProfile -ExecutionPolicy Bypass -File ...\iso365_probe.ps1 -Exe build\tandemcommander\Debug_x64\tandemcommander.exe -Label before -OutFile ..."
```

Seeds `mkimg365.sh` (genisoimage in WSL: s1.iso a.txt "A1"; s2.iso b.txt "B2" addressed from 176 + 11400 =
11576), images `img365.py`. Result `probe/result_before.txt`: **12 PASS / 6 FAIL**:

| Row | Result |
|---|---|
| C-ETNF00 | PASS - both sessions, image deleted |
| R-ETNF05 | FAIL - Session 01/a.txt only, image kept |
| R-ETNF06 | FAIL - Session 01/a.txt only, image kept |
| C-ETN2ONE | PASS - a.txt, image deleted |
| R-ETN200 | FAIL - Session 01/a.txt with WRONG content, b.txt missing, box "Error reading directory structure at sector #00002D4F", image kept |
| R-ETN203 | FAIL - a.txt wrong content, b.txt missing, image kept |
| R-ETN206 | FAIL - a.txt wrong content, b.txt missing, image kept |
| C-CCDREL | PASS - both sessions, image deleted (CloneCD's INDEX-from-session form) |
| R-CCDABS | FAIL - a.txt only (no session folders), image kept (352's mark) |

Wrong content in the ETN2 rows: both ETN2 tracks get extent offset 0, so a.txt's extent maps to track 2
(the last track whose extent offset is not above it) and is read from session 2's bytes - a file written
with wrong data (the image is kept, so nothing is deleted, but the extracted file is wrong).

`BL verify` recorded "still present".

## Decisions

(see spec Clarifications / Assumptions)

## Analyze

Run 1: CRITICAL 0, HIGH 0. LOW C1 (FR-008 proved only implicitly) - fixed in T004 (saltests compare the
relative table with 41f18c08's formula); LOW U1 (an ETN2 audio entry becomes a plain track record of audio
type, as ETNF always made it) - accepted, recorded as a limit; LOW I1 (352's R-ABS reports FAIL against its
old "kept" expectation by design) - stated in spec SC-003 and quickstart. No second run needed (no
CRITICAL / HIGH).

## Implementation

- `src/common/salnrgcdtext.h`: `SalNrgModeVerified`, `SalNrgEtnSectorSize(mode, v2)` (verified modes by
  libmirage's table; others keep the earlier size - ETNF bit 0, ETN2 2048), `SalNrgEtnEntry` /
  `SalNrgBigEndian` / `SalNrgEtnDecode`, `SalNrgEtnEnd` (saturated), `SalNrgEtnEntryCount`,
  `SalNrgEtn2ChunkPlausible` (at most 99 entries).
- `src/common/salisotrack.h`: `SalIsoCcdSectorCount` (negative -> 0 + inconsistent), `SalIsoCcdTocFind`,
  `SalIsoCcdTocLayout` (NONE / OK / INCONSISTENT). While writing the tests a gap showed: with fewer
  `[TRACK n]` sections than track points the last section would have run to the session's lead-out - the
  rule now also requires as many distinct ADR-1 track points (1..99) as sections (else NONE; spec edge
  case and research R3 updated).
- `nrg.cpp`: `readETNF` sector size by `SalNrgEtnSectorSize(mode, false)`; `readETN2` rewritten - chunk read
  only when `SalNrgChunkFits` and `SalNrgEtn2ChunkPlausible`, a track per whole 32-byte entry (start, end =
  start + length, verified mode -> `SetTrackTypeMode`, else Mode 1 / ISO 9660 as before, sector size,
  header size, extent = first-sector field), the next chunk header right after the chunk. This also ends
  41f18c08's 16-byte over-read of an ETN2 chunk under 16 bytes (the ETN2 half of Inbox item
  `iso-plug-in-nrg-sinf-and-etn2-chunks-are-read-without-regard`; its SINF half stays open).
- `img.cpp` `ReadSessionCCD`: `SalIsoCcdTocLayout` after the tracks are built; followed -> sessions = its
  runs, `ExtentOffset` = PLBA, `Start` / `End` from first sector and count (0x930 a sector), INCONSISTENT
  marks the listing; NONE -> the 41f18c08 INDEX-1 path, its counts now signed through
  `SalIsoCcdSectorCount` (negative -> 0 + mark). 352's sections / splits mark after both.
- clang-format only on the changed line ranges (`--lines` from `git diff -U0`), BOM kept.

## Checks

- `python tools/check_encoding.py --strict` -> `TOTAL: 0 finding(s)`.
- `.\build.cmd` -> `BUILD SUCCEEDED`, no warning in the changed files.
- saltests 29,791 -> **29,887 / 0** (`TestNrgEtn365`, `TestIsoCcdToc365`, +96 checks). (A first build piped
  through `Select-Object -First 20` was cut short and left the old saltests.exe - re-run after a full build.)
- Mutants (`mutants.ps1`: one header edit, MSBuild of saltests only with `OPENSAL_BUILD_DIR` set, run,
  restore; a first run without `OPENSAL_BUILD_DIR` built into a stray `src/vcxproj/saltests/tandemcommander`
  folder and ran the old exe - removed, re-run): ETNF bit 0 for all modes 3 failed; ETN2 end = length 2;
  no 99-entry bound 2; CCD count unclamped (DWORD wrap) 5; no points-count check 1; no session-order check
  1; lead-out of any session 9. Restored: 0 failed.

## Measurement after (Debug x64, branch)

`iso365_probe` -> `probe/result_after.txt`: **18 PASS / 0 FAIL** (before 12 / 6). Every R row: Session 01/a.txt
and Session 02/b.txt with their content, no window, image deleted; controls unchanged. Registry restored,
identical (SHA-256 07F63FE1...).

## Regressions (Debug x64, branch, hidden desktop, `probe/regress_<NNN>.txt`)

| Probe | Result | Recorded before | Note |
|---|---|---|---|
| 352 | 21 / 1 | 22 / 0 | **R-ABS** (INDEX 1 counted from the disc, no gap): now Session 01/a.txt + Session 02/b.txt extracted with their content, image deleted - the item's note ("that mark should go only where the sessions are then read correctly"); the row's old "kept" expectation fails by design. R-TWOSEC still KEPT (sections 2, sessions holding tracks 1). R-SPLIT now extracts b.txt (one section, two tracks of one session - its last data track), still kept (334's other-data-track mark) |
| 351 | 10 / 0 | 10 / 0 | as recorded |
| 334 | 23 / 1 | 23 / 1 | S-RAW kept - 335's intended change, as recorded |
| 335 | 28 / 4 | 28 / 4 | M-FORM2, S-VCD, C-VCD, C-VCDREAL - 336 / 337's intended changes, as recorded (351's `regress_335.txt` same rows) |
| 353 | 16 / 0 | 16 / 0 | as recorded |

## Inbox items added (INBOX = 3)

- `iso-plug-in-an-nrg-image-of-nero-v1-nero-footer-is-opened` (measure:365) - v1 "NERO" images are never read
  through their track table (only "NER5" footers), so ETNF is reached only inside NER5 images.
- `iso-plug-in-nrg-tracks-of-the-subchannel-modes-0x0f-0x10` (leftover:365) - modes 0x0F / 0x10 / 0x11 keep the
  old type / size (layout not known).
- `check-feature-365-with-real-nero-tao-and-clonecd-multi` (person step, leftover:365) - real dumps.
