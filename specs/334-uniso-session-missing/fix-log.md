# Fix log - 334-uniso-session-missing

Backlog item `iso-plug-in-unpack-with-delete-archive-deletes-a-multi` - ISO plug-in: Unpack with
Delete archive deletes a multi-session image whose session track cannot be opened.

## Measurement at 21c3ce91 (main, before any change)

Build: `.\build.cmd` (Debug x64, up to date). Probe `probe/iso334_probe.ps1` (new; seeds
`probe/mkimg334.sh` - genisoimage in WSL Ubuntu, two sessions s1 `a.txt` "A1" and s2 `b.txt` "B2" with
`-C 0,176`; NRG images by `probe/img334.py`, ETNF + SINF chunks), run through
`tools\run_on_hidden_desktop.ps1`. Result `probe/result_before.txt`: PASS 7, FAIL 3.

| Row | Image | Result at 21c3ce91 |
|---|---|---|
| M-OK | two sessions | PASS - Session 01/a.txt + Session 02/b.txt, no window, image deleted |
| M-TERM | session 2's terminator "CD001" -> "XXXXX" | FAIL - multi-session box, Session 01/a.txt, **image deleted** |
| M-PAST | session 2's track starts past the image end | FAIL - no window (track became fsData / CRawFS, lists nothing), Session 01/a.txt, **image deleted** |
| S-OK | one session of both tracks | PASS - b.txt (last track only), image deleted |
| S-TERM | as S-OK, track 2's terminator destroyed | FAIL - no window, fallback lists track 1, a.txt, **image deleted** |

Traced (read at HEAD):
- `CISOImage::ListImage` (`src/plugins/uniso/isoimage.cpp`) - the only caller is
  `CPluginInterfaceForArchiver::ListArchive` (`uniso.cpp`), used by the panel and by
  `UnpackWholeArchive`; `UnpackWholeArchive` fails only on `pd->ListingLeftOut` (328).
- The multi-session branch ignores `ListDirectory`'s result and sets only `ret = FALSE` (the box) for a
  default-type track that does not open; `fsAudio` that does not open is skipped silently (it cannot
  fail: `OpenTrack` creates `CAudio` without an `Open`); `fsUnknown` skipped.
- The else branch: `OpenTrack(LastTrack)` failing -> every other track tried, TRUE when any lists.
  `LastTrack` = the last track whose sector 16 is ISO/UDF or HFS (`CheckForISO` / `CheckForHFS`);
  -1 for an audio CD (then the fallback is the normal path).
- `CISOImage::Open`: `DetectTrackFS` ERR_CONTINUE -> `fsData` (CRawFS: `Open` and `ListDirectory`
  return TRUE, list nothing) - also for a track none of whose sectors are in the file (M-PAST).
- Readers' `ListDirectory` FALSE returns: every one marks `ListingLeftOut` already (ISO 9660 / UDF /
  Xbox walk result 330, HFS 329/332, audio 329/331) except the trailing `return FALSE` of
  `CHFS::ListDirectory` (a record type after the class check - unreachable).

## speckit-analyze

One run: 0 CRITICAL, 0 HIGH. LOW I1 (FR-002 names "does not open", T007 also marks a fallback track
whose listing fails - harmless, the readers mark their own failed listings) and LOW C1 (FR-004 "no UI
string" has no own task - shown by the diff: no resource file changes) accepted.

## Implementation

- `src/common/salisotrack.h` (new): `SalIsoTrackMarksListing(kind, outsideImage, outcome)` - unknown
  never marks; a data track outside the image always marks; else marks when the listing tried the
  track and it did not open or its listing failed; an unknown outcome value marks (fail closed).
- `src/plugins/uniso/isoimage.h/.cpp`: `Track::OutsideImage` (set in `CISOImage::Open` when
  `DetectTrackFS` found no file system - the track becomes fsData - and the track's sector 16 + one
  sector is past the image file's size, the bound `DetectTrackFS` uses); `CISOImage::MarkTrack`;
  `ListImage`: multi-session branch marks every tried track by its outcome (the box and `ret = FALSE`
  unchanged); single-session branch: when the last data track lists, every other track `NOT_TRIED`
  (only an outside-the-image data track marks); when it does not open, `LastTrack` (>= 0) marks as
  not opened and each track the fallback tries marks by its outcome. No message, no UI string.
- clang-format: the x64 clang-format of VS 2022 (the ARM64 one on PATH search does not start) reflowed
  three unrelated comment alignments of `isoimage.cpp` and the whole of `saltests.cpp` - reverted;
  `saltests.cpp` formatted only on the new lines (`--lines`), as feature 333 did.

## Checks

| Check | Command | Result |
|---|---|---|
| encoding guard | `python tools/check_encoding.py --strict` | TOTAL: 0 finding(s) |
| build | `.\build.cmd` | BUILD SUCCEEDED (C4267 warnings: existing lines of audio / hfs / xdvdfs / udf / iso9660.cpp, recompiled because isoimage.h changed) |
| saltests | `build\tandemcommander\Debug_x64\saltests\saltests.exe` | 28,372 -> 28,407 checks, 0 failed (`TestIsoTrackMarks334`, 35 checks) |
| mutant | the rule without `if (kind == DATA && outsideImage) return true;` | saltests 4 failed; probe `result_mutant_no_outside.txt` 9 / 1 (M-PAST FAIL: image deleted) |
| probe after | `iso334_probe.ps1 -Label after` (hidden desktop) | `result_after.txt` PASS 10, FAIL 0; registry restored + identical |

Before / after (rows RUN): M-OK PASS / PASS, M-TERM FAIL / PASS, M-PAST FAIL / PASS, S-OK PASS /
PASS, S-TERM FAIL / PASS. M-TERM still shows the multi-session box (unchanged), M-PAST and S-TERM no
window (unchanged).
| regressions | `iso322/329/330/333_probe.ps1` on the fixed build | `probe/regress_322.txt` 18 / 0, `regress_329.txt` 14 / 0, `regress_330.txt` 30 / 0, `regress_333.txt` 20 / 0 (as their features recorded); registry restored + identical each |

## Inbox

- `iso-plug-in-a-data-track-in-which-no-file-system-is-found` (measure:334) - a data track inside the
  image with no file system found (destroyed descriptors) still opens as raw data, lists nothing and
  is not marked; told apart from Video CD raw tracks it is not (a trade-off, see the item).
