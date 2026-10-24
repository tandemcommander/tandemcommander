# Fix log - 337-uniso-form2-partial

Backlog item `iso-plug-in-a-file-covering-part-of-a-form-2-stream-lets-the` - ISO plug-in: a file covering
part of a Form 2 stream lets the image be deleted.

## Measurement before (main 1c43d7d8)

- `.\build.cmd` -> BUILD SUCCEEDED (up to date). No `tandemcommander.exe` running.
- Hidden desktop: `specs\336-uniso-form2-uncovered\probe\iso336_probe.ps1 -Label head-1c43d7d8 -Only
  S-VCDPART,S-VCDCOV,C-VCDCOV` -> PASS 6 / FAIL 0 under 336's expectations, i.e. the defect reproduces:
  S-VCDPART (`avseq01.dat` 2048 bytes = 1 of the 64-sector stream) extracts one sector, the image
  **deleted**; S-VCDCOV (NRG) and C-VCDCOV (CloneCD) - 336's "covered" controls - hold a file of 8 of the
  64 data-filled stream sectors (`COVER_SECTORS = 8` in `img336.py`), the image **deleted** too (56 sectors
  lost each). Registry restored + identical (SHA-256 315452A9...).
- Code trace: `CISOImage::ListImage` -> `MarkUncoveredStreams` -> `NoteListedFileStarts` ->
  `SalIsoNoteFileStart` sets `covered[t]` for any file of > 0 bytes that starts in track t ->
  `SalIsoStreamTrackMarksListing(true, true)` = false -> `ListingLeftOut` stays complete ->
  `UnpackWholeArchive` succeeds -> the core deletes the image. Default configuration (uniso on; Alt+F9,
  "Delete archive after unpacking").
- Real vcdimager images (`%TEMP%\rev335c\imgs`; a Python dump of the ISO 9660 records and of the raw
  sectors, scripts in the session's `%TEMP%\tcmeasure`):

  | image | stream track (sectors) | file | covers | uncovered |
  |---|---|---|---|---|
  | real_vcd | 2: 450..896 | AVSEQ01.DAT 608,256 B | 450..746 | 747..896 (150) |
  | real_vcd | 3: 897..1343 | AVSEQ02.DAT 608,256 B | 897..1193 | 1194..1343 (150) |
  | real_svcd | 2: 450..742 | AVSEQ01.MPG 292,864 B | 450..592 | 593..742 (150) |

  Every uncovered sector: Mode 2, subheader `00 00 20 00` (twice), 2324 zero user bytes (vcd.cue: track
  3's INDEX 00 at 00:09:72 = 747 - the next track's pregap; the last 150 = the post-gap before the
  lead-out). The files' own margins are zero too; the stream sectors carry data (submode 0x62 / 0x64).
- Unpack rule: `CISOImage::UnpackFile` -> `GetTrackFromExtent` -> `CRawFS::UnpackFile` reads
  `ceil(size / 2048)` blocks from `fp->Extent - ExtentOffset`; block i at `Start + i * SectorSize`.

## Decision

A count tolerance cannot separate S-VCDPART (63 data sectors uncovered) from a real VCD (150 empty ones);
the content can. A stream track that a file starts in counts as covered only when every sector no such
file reads is an empty Form 2 sector (2324 zero user bytes, read whole) and there are at most 300 of them
(`SAL_ISO_STREAM_GAP_SECTORS`; more mark without reading). Track extent fails closed (spec Q2). See spec
*Clarifications*, research R1-R6.

## speckit-analyze

Two runs: 0 CRITICAL, 0 HIGH. MEDIUM C1 (SC-004's saltests mutant missing in T008) and LOW I1 (C-VCDFULL
missing in US2's test line) fixed. MEDIUM C2 accepted: the edge cases middle gap, more than 300 empty
sectors and a file from another track have no probe row - they are pure rules, checked in saltests.

## Implementation

- `src/common/salisotrack.h`: `SalIsoFileStartTrack` (336's guards - size > 0, ISO 9660 disc address,
  track <= 255 - returning the track; `SalIsoNoteFileStart` now calls it), `SalIsoStreamTrackSectors`
  (whole stored sectors; end <= start -> the image's end; extended to a later next track's start; cut at
  the image's end), `SalIsoFileSectorSpan` (the unpack's `ceil(size / 2048)` sectors from the extent,
  clipped to the track; nothing for an extent before the track), `SalIsoStreamSpan` +
  `SalIsoMergeStreamSpans` (sort by track / first sector, merge overlapping or adjacent), 
  `SalIsoStreamUncovered`, `SalIsoStreamNextGap`, `SalIsoForm2PayloadOffset` (24 raw, 8 for 2336, -1),
  `SalIsoPayloadEmpty` (2324 bytes read whole, all zero), `SalIsoStreamGapsMark`
  (`SAL_ISO_STREAM_GAP_SECTORS` = 300).
- `src/plugins/uniso/isoimage.h/.cpp`: `MarkUncoveredStreams` computes each stream track's sectors,
  `NoteListedFileStarts` also collects the spans of files starting in stream tracks (out of memory ->
  nothing covered), the spans are merged; per stream track a file starts in: the uncovered count, and
  when it is at most 300 `StreamGapsEmpty` reads each uncovered stored sector's Form 2 payload
  (`ReadDataByPos`); any data / short read / too many -> `ListingLeftOut.SetIncomplete()`. 336's rule
  (no file starts in the stream -> marked) unchanged.
- `src/saltests/saltests.cpp`: `TestIsoStreamPartial_337` (81 checks).
- clang-format on the changed lines only (a script that builds `--lines` from `git diff -U0 main`, never an
  empty list); a second dry run: no change.

## Checks

| Check | Command | Result |
|---|---|---|
| build | `.\build.cmd` | BUILD SUCCEEDED |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | 28,602 -> 28,683 checks, 0 failed |
| mutant (saltests) | `SalIsoStreamGapsMark` ignores `gapsEmpty` (returns false) | 5 failed (S-VCDPART decision + 4 image cases) |
| probe after | `iso337_probe.ps1 -Label after` | `probe/result_after.txt` PASS 56, FAIL 0 (28 rows); registry restored + identical |
| probe folders off | `iso337_probe.ps1 -Label after -FoldersOff` | `probe/result_after_foldersoff.txt` PASS 8, FAIL 0 (MF-FORM2 kept, MF-FORM2COV kept, MF-FORM2FULL deleted, MF-NOFS kept) |
| real Video CDs | `rev335c_probe.ps1 -ImgDir %TEMP%\rev335c\imgs -Lib ...\fix_probe_lib.ps1 -Label after-337` | `probe/result_realvcd.txt` PASS 10, FAIL 0: R-VCD-CCD, R-SVCD-CCD, R-VCD-NRG every file extracted, the image deleted; R-VCD-HOLE, X-SHORT kept |
| negative control (probe) | the `SalIsoStreamGapsMark` branch disabled (`false &&`), built, `iso337_probe.ps1 -Label before-negative-control -Only ...` | `probe/result_before_negative.txt` PASS 15, FAIL 5: S-VCDPART, S-VCDCOV, C-VCDCOV, M-FORM2COV, S-VCDTAIL deleted; S-VCDFULL, C-VCDFULL, S-VCDGAP, C-VCDGAP deleted (PASS), S-VCDCOV2 kept (PASS); code restored, rebuilt |
| regression | `iso334_probe.ps1 -Label regress-337` | `probe/regress_334.txt` 23 / 1 - the FAIL is S-RAW, changed on purpose by 335 (the same verdict in 335's and 336's `regress_334.txt`) |
| 335 / 336 rows | inside `iso337_probe.ps1` | all 335 rows and 336's S-VCDCOV2 / S-VCDZERO PASS with 336's expectations |
| encoding guard | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |

Verdict changes against 336's probe (on purpose): S-VCDPART, S-VCDCOV, C-VCDCOV, M-FORM2COV and
MF-FORM2COV keep the image now (they cover 1 or 8 of 64 data sectors).

## Probes - notes

- A first run of 335's `rev335c_probe.ps1` was started without its mandatory `-Lib`; PowerShell waited for
  the parameter on the hidden desktop (nothing of the script body ran: no `tc335_backup.reg`, no program
  started). That prompt process was ended and the probe re-run with `-Lib` and `-NonInteractive` (the
  probes since run with `-NonInteractive`).
- The product's registry key changed between two probe runs (09:21 -> 09:31: `Last Focused Page`,
  `Configuration Height`, `Plugins.ver Version`) - a Tandem Commander session outside the probes (none
  ran at the checks); every probe restored the state it found (hash BFC2D583... before = after since).
